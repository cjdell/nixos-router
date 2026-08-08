{
  lib,
  ...
}:

let
  c = import ./constants.nix;

  # `{ "lan", "vlan10" }` — quoted nftables set of interface names
  ifaceSet = names: "{ ${lib.concatMapStringsSep ", " (n: "\"${n}\"") names} }";

  # Everything we trust implicitly on input (no further rules needed)
  # Note: tailscale0 is deliberately NOT here — tailnet members get only the
  # explicit service rules in input-allow, not blanket trust.
  trustedIfaces = ifaceSet [
    "lo"
    c.LAN_INTERFACE
    c.VLAN10_INTERFACE
    c.PODMAN_INTERFACE
  ];

  # Internal bridges that may talk to each other (mDNS etc.)
  internalIfaces = ifaceSet [
    c.LAN_INTERFACE
    c.VLAN10_INTERFACE
    c.PODMAN_INTERFACE
  ];

  # LAN + VLAN10, i.e. everything except podman containers and the VPN
  homeIfaces = ifaceSet [
    c.LAN_INTERFACE
    c.VLAN10_INTERFACE
  ];
in
{
  networking.nftables.tables = {
    firewall = {
      family = "inet";
      content = ''
        # ============================================================================
        # FILTER TABLE (inet)
        # ============================================================================

        # ----------------------------------------------------------------------------
        # rpfilter — anti-spoofing
        # Checks a route exists back to the source through any output interface; if
        # not, the packet is dropped. The DHCPv4 exception exists because DHCP clients
        # broadcast from 0.0.0.0 before they have an IP — those fail the FIB check
        # but are legitimate.
        # ----------------------------------------------------------------------------
        chain rpfilter {
          type filter hook prerouting priority mangle + 10; policy drop;
          meta nfproto ipv4 udp sport . udp dport {
            ${toString c.DHCPV4_CLIENT_PORT} . ${toString c.DHCPV4_SERVER_PORT},
            ${toString c.DHCPV4_SERVER_PORT} . ${toString c.DHCPV4_CLIENT_PORT}
          } accept comment "DHCPv4 client/server"
          fib saddr . mark oif exists accept
        }

        # ----------------------------------------------------------------------------
        # input — traffic to the router itself
        # ----------------------------------------------------------------------------
        chain input {
          type filter hook input priority filter; policy drop;

          # Trust our own networks / interfaces entirely
          iifname ${trustedIfaces} accept comment "trusted interfaces"
          ip6 saddr ${c.DBTHR33_SUBNET} accept comment "DBTHR33 trusted network"
          ip saddr ${c.PODMAN_SUBNET} accept comment "NixOS containers"

          # Handle packets according to connection state
          ct state vmap {
            invalid     : drop,
            established : accept,
            related     : accept,
            new         : jump input-allow,
            untracked   : jump input-allow
          }

          # Reached here = blocked; log it (spots port scans / misconfigs)
          tcp flags syn / fin,syn,rst,ack log prefix "refused connection: " level info
        }

        chain input-allow {
          # --- SSH: private networks only -------------------------------------------
          ip saddr ${c.WIREGUARD_SUBNET} tcp dport ${toString c.SSH_PORT} accept comment "ssh from WireGuard VPN"
          ip saddr ${c.LAN_SUBNET}       tcp dport ${toString c.SSH_PORT} accept comment "ssh from LAN"
          ip saddr ${c.TAILSCALE_SUBNET} tcp dport ${toString c.SSH_PORT} accept comment "ssh from Tailscale"

          # --- Tailscale: explicit services only (no blanket trust) -----------------
          # headscale's MagicDNS split sends grafton.lan queries to the router
          ip saddr ${c.TAILSCALE_SUBNET} udp dport ${toString c.DNS_PORT} accept comment "DNS from Tailscale (MagicDNS split)"
          ip saddr ${c.TAILSCALE_SUBNET} tcp dport ${toString c.DNS_PORT} accept comment "DNS from Tailscale (MagicDNS split)"
          ip saddr ${c.TAILSCALE_SUBNET} tcp dport ${toString c.HOME_ASSISTANT_PORT} accept comment "Home Assistant from Tailscale"

          # --- Public services --------------------------------------------------------
          tcp dport ${toString c.HTTP_PORT}       accept comment "HTTP from anywhere"
          tcp dport ${toString c.HTTPS_PORT}      accept comment "HTTPS from anywhere"
          udp dport ${toString c.STUN_PORT}       accept comment "STUN (headscale DERP)"
          udp dport ${toString c.TAILSCALE_PORT}  accept comment "Tailscale from anywhere"

          # --- ICMP -------------------------------------------------------------------
          icmp type echo-request limit rate 10/second accept comment "allow ping (rate limited)"
          icmpv6 type != { nd-redirect, 139 } accept comment "Accept all ICMPv6 except redirects and node info queries (type 139). See RFC 4890, section 4.4."

          # --- DHCPv6 — router is a DHCPv6 *client* on the WAN ------------------------
          # Prefix delegation from the ISP (see pppoe.nix) arrives on UDP 546 (client
          # port), sourced from the server port 547.
          ip6 daddr fe80::/64 udp dport ${toString c.DHCPV6_CLIENT_PORT} accept comment "DHCPv6-PD from ISP (link-local)"
          udp dport ${toString c.DHCPV6_CLIENT_PORT} udp sport ${toString c.DHCPV6_SERVER_PORT} counter accept comment "DHCPv6-PD from ISP (any daddr)"
        }

        # ----------------------------------------------------------------------------
        # forward — traffic routed through the router
        # ----------------------------------------------------------------------------
        chain forward {
          type filter hook forward priority 0; policy drop;

          # Anti-spoofing / broken-packet hygiene
          tcp flags & (fin|syn|rst|psh|ack|urg) == 0 drop comment "drop null packets"
          tcp flags & (fin|syn) == fin|syn drop comment "drop fin+syn"
          tcp flags & (syn|rst) == syn|rst drop comment "drop syn+rst"

          # mDNS between internal networks
          iifname ${internalIfaces} udp dport ${toString c.MDNS_PORT} accept comment "mdns from trusted networks"

          # MSS clamping (avoids MTU issues over PPPoE)
          tcp flags syn / fin,syn,rst,ack tcp option maxseg size set 1400 comment "Clamp TCP MSS to avoid MTU issues"
          tcp flags syn / fin,syn,rst,ack ip6 daddr != fe80::/10 tcp option maxseg size set 1400 comment "Clamp TCP MSS for IPv6"

          # No internet egress to RFC1918 addresses
          oifname ${c.WAN_INTERFACE} ip daddr { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 } reject with icmp type net-unreachable comment "outbound rfc1918 not permitted"

          # Connection tracking dispatch
          ct state vmap {
            invalid     : drop,
            established : accept,
            related     : accept,
            new         : jump forward-allow,
            untracked   : jump forward-allow
          }

          # Connection rate limiting
          ct state new limit rate over 50/second burst 100 packets drop comment "rate limit new connections"

          # Reached here = blocked; log it
          tcp flags syn / fin,syn,rst,ack log prefix "refused forward: " level info
        }

        chain forward-allow {
          # Only NEW connections reach here — define initiation rules only.

          # Tailscale exit node — tailnet clients route to the internet via us.
          # Deliberately narrow: does NOT give tailnet access to podman containers.
          iifname ${c.TAILSCALE_INTERFACE} oifname ${c.WAN_INTERFACE} accept comment "Tailscale exit node (internet)"

          ip saddr ${c.PODMAN_SUBNET} accept comment "NixOS containers"

          # LAN can initiate to VLAN10
          iifname ${c.LAN_INTERFACE} oifname ${c.VLAN10_INTERFACE} accept comment "LAN to VLAN10"

          # Internal networks outbound to internet
          iifname ${c.LAN_INTERFACE}    oifname ${c.WAN_INTERFACE} accept comment "LAN out via ISP"
          iifname ${c.VLAN10_INTERFACE} oifname ${c.WAN_INTERFACE} accept comment "VLAN10 out via ISP"
          iifname ${c.PODMAN_INTERFACE} oifname ${c.WAN_INTERFACE} accept comment "podman to internet"

          # Internal <-> podman
          iifname ${c.LAN_INTERFACE}    oifname ${c.PODMAN_INTERFACE} accept comment "LAN to podman"
          iifname ${c.VLAN10_INTERFACE} oifname ${c.PODMAN_INTERFACE} accept comment "VLAN10 to podman"
          iifname ${c.PODMAN_INTERFACE} oifname ${c.LAN_INTERFACE}    accept comment "podman to LAN"
          iifname ${c.PODMAN_INTERFACE} oifname ${c.VLAN10_INTERFACE} accept comment "podman to VLAN10"

          # IPv6 — delegated prefix + trusted network
          ip6 saddr ${c.DELEGATED_PREFIX} accept comment "outbound from delegated IPv6 prefix"
          ip6 saddr ${c.DBTHR33_SUBNET}   accept comment "DBTHR33 trusted network"

          # ICMP
          icmp type echo-request accept comment "allow ping"
          icmpv6 type != { nd-redirect, 139 } accept comment "Accept ICMPv6 except redirects and queries"

          # VPN <-> home
          iifname ${c.TAILSCALE_INTERFACE} oifname ${homeIfaces} accept comment "VPN to LAN"
          iifname ${homeIfaces} oifname ${c.TAILSCALE_INTERFACE} accept comment "LAN to VPN"
        }

        chain output {
          type filter hook output priority 0; policy accept;
        }
      '';
    };

    nat = {
      family = "ip";
      content = ''
        chain pre {
          type nat hook prerouting priority dstnat; policy accept;
          # we'll add rules for our 1:1 NAT here later
          # tcp dport 65022 dnat to 192.168.49.1:22 comment "Forward SSH from ext port 65022 to 192.168.49.1:22"
        }

        chain post {
          type nat hook postrouting priority srcnat; policy accept;

          # Internal networks out via the ISP
          iifname ${c.LAN_INTERFACE}    oifname ${c.WAN_INTERFACE} masquerade comment "LAN NAT to FTTP"
          iifname ${c.VLAN10_INTERFACE} oifname ${c.WAN_INTERFACE} masquerade comment "VLAN10 NAT to FTTP"
          iifname ${c.PODMAN_INTERFACE} oifname ${c.WAN_INTERFACE} masquerade comment "Podman to FTTP"

          # Tailscale out
          iifname ${c.TAILSCALE_INTERFACE} oifname ${c.WAN_INTERFACE} masquerade comment "Tailscale to FTTP"
          iifname ${c.TAILSCALE_INTERFACE} oifname ${c.LAN_INTERFACE} masquerade comment "Tailscale to LAN"

          # LAN traffic to remote tailnets (Grafton + Hackspace) — masquerade so
          # replies come back via us instead of the remote network's routes
          iifname ${c.LAN_INTERFACE}          ip daddr ${c.TAILSCALE_SUBNET} masquerade comment "NAT for Grafton Tailnet traffic"
          iifname ${c.LAN_INTERFACE}          ip daddr ${c.HACKSPACE_SUBNET} masquerade comment "NAT for Hackspace Tailnet traffic"
          iifname ${c.TAILSCALE_INTERFACE}    ip daddr ${c.HACKSPACE_SUBNET} masquerade comment "NAT for Hackspace Tailnet traffic"
        }

        chain out {
          type nat hook output priority mangle; policy accept;
          # we'll add rules for our 1:1 NAT here later
        }
      '';
    };
  };
}
