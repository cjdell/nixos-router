{
  networking.nftables.tables = {
    firewall = {
      family = "inet";
      content = ''
        # Anti-spoofing
        # This checks if a route exists back to the source address through any output interface. If yes, the packet is legitimate.
        # The DHCPv4 exception exists because DHCP clients broadcast from 0.0.0.0 before they have an IP - these would fail the FIB (Forwarding Information Base) check but are legitimate, so they're explicitly allowed.
        # This is a best practice for router security - it prevents your network from being used in spoofing attacks.
        chain rpfilter {
          type filter hook prerouting priority mangle + 10; policy drop;
          meta nfproto ipv4 udp sport . udp dport { 68 . 67, 67 . 68 } accept comment "DHCPv4 client/server"
          fib saddr . mark oif exists accept
        }

        chain input {
          type filter hook input priority filter; policy drop;

          # assuming we trust our LAN clients
          iifname { "lo", "lan", "vlan10", "podman0", "wg0" } accept comment "trusted interfaces"

          # handle packets according to connection state
          ct state vmap {
            invalid     : drop,
            established : accept,
            related     : accept,
            new         : jump input-allow,
            untracked   : jump input-allow
          }

          # if we make it here, block and log
          tcp flags syn / fin,syn,rst,ack log prefix "refused connection: " level info
        }

        chain input-allow {
          # make your own choice on whether to allow SSH from outside
          ip saddr 10.47.0.0/16    tcp dport 22 accept comment "ssh from VPN"
          ip saddr 192.168.49.0/24 tcp dport 22 accept comment "ssh from LAN"

          tcp dport 80 accept comment "http from anywhere"
          tcp dport 443 accept comment "https from anywhere"

          # Rate limit ping (replace your existing icmp rule)
          icmp type echo-request limit rate 10/second accept comment "allow ping (rate limited)"

          icmpv6 type != { nd-redirect, 139 } accept comment "Accept all ICMPv6 messages except redirects and node information queries (type 139). See RFC 4890, section 4.4."
          ip6 daddr fe80::/64 udp dport 546 accept comment "DHCPv6 client"

          # DHCPv6
          udp dport dhcpv6-client udp sport dhcpv6-server counter accept comment "IPv6 DHCP"
        }

        chain forward {
          type filter hook forward priority 0; policy drop;

          # Anti-spoofing rules
          tcp flags & (fin|syn|rst|psh|ack|urg) == 0 drop comment "drop null packets"
          tcp flags & (fin|syn) == fin|syn drop comment "drop fin+syn"
          tcp flags & (syn|rst) == syn|rst drop comment "drop syn+rst"

          iifname { "lan", "vlan10", "podman0" } udp dport 5353 accept comment "mdns from trusted networks"

          # MSS clamping rules
          tcp flags syn / fin,syn,rst,ack tcp option maxseg size set 1400 comment "Clamp TCP MSS to avoid MTU issues"
          tcp flags syn / fin,syn,rst,ack ip6 daddr != fe80::/10 tcp option maxseg size set 1400 comment "Clamp TCP MSS for IPv6"
          oifname "wg0" tcp flags syn / fin,syn,rst,ack tcp option maxseg size set 1360
          iifname "wg0" tcp flags syn / fin,syn,rst,ack tcp option maxseg size set 1360

          # No internet egress to RFC1918 IPs
          oifname "pppoe-zen" ip daddr { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 } reject with icmp type net-unreachable comment "outbound rfc1918 not permitted"

          # Add this rule temporarily at the TOP of your forward chain (before ct state vmap)
          iifname "vlan10" oifname "lan" log prefix "VLAN10->LAN debug: " level info

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

          # Log anything that was blocked
          tcp flags syn / fin,syn,rst,ack log prefix "refused forward: " level info
        }

        chain forward-allow {
          # Only NEW connections reach here - define initiation rules only!

          # LAN can initiate to VLAN10
          iifname "lan" oifname "vlan10" log prefix "LAN TO VLAN10: " accept

          # Internal networks outbound to internet
          iifname "lan"     oifname "pppoe-zen" accept comment "LAN out via ISP"
          iifname "vlan10"  oifname "pppoe-zen" accept comment "VLAN10 out via ISP"
          iifname "podman0" oifname "pppoe-zen" accept comment "podman to internet"

          # Internal to podman
          iifname "lan" oifname "podman0" accept comment "LAN to podman"
          iifname "vlan10" oifname "podman0" accept comment "VLAN10 to podman"

          # Podman to internal
          iifname "podman0" oifname "lan" accept comment "podman to LAN"
          iifname "podman0" oifname "vlan10" accept comment "podman to VLAN10"

          # IPv6 prefix routing
          ip6 saddr 2a02:8010:6680::/48 accept comment "Allow outbound from delegated IPv6 prefix"

          # ICMP
          icmp type echo-request accept comment "allow ping"
          icmpv6 type != { nd-redirect, 139 } accept comment "Accept ICMPv6 except redirects and queries"

          # VPN access
          iifname "wg0" oifname { "lan", "vlan10" } accept comment "VPN to LAN"
          iifname { "lan", "vlan10" } oifname "wg0" accept comment "LAN to VPN"

          # If nothing matched, drop (implicit with chain having no policy)
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

          iifname "lan"     oifname "pppoe-zen" masquerade comment "LAN NAT to FTTP"
          iifname "vlan10"  oifname "pppoe-zen" masquerade comment "LAN NAT to FTTP"
          iifname "podman0" oifname "pppoe-zen" masquerade comment "Podman to FTTP"

          iifname "wg0" oifname { "lan", "vlan10" } masquerade comment "NAT VPN clients to LAN"
        }

        chain out {
          type nat hook output priority mangle; policy accept;
          # we'll add rules for our 1:1 NAT here later
        }
      '';
    };
  };
}
