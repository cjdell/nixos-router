# Shared networking constants for the Grafton router.
#
# Single source of truth for the network layout: interface names, addresses,
# subnets, ports and DNS/DHCP settings. Import this anywhere the same value
# would otherwise be typed out twice (firewall, dnsmasq, AdGuard, networkd).
rec {
  # ---------------------------------------------------------------------------
  # Interfaces
  # ---------------------------------------------------------------------------
  WAN_INTERFACE = "pppoe-zen";       # PPPoE uplink to Zen (created by pppd)
  LAN_INTERFACE = "lan";             # bridge for the LAN + VMs
  VLAN10_INTERFACE = "vlan10";       # experimental VLAN
  PODMAN_INTERFACE = "podman0";      # podman default-network bridge
  TAILSCALE_INTERFACE = "tailscale0";

  # ---------------------------------------------------------------------------
  # Router addresses
  # ---------------------------------------------------------------------------
  LAN_IPV4 = "192.168.49.1";                 # router on lan (192.168.49.1/24)
  VLAN10_IPV4 = "192.168.10.1";              # router on vlan10 (192.168.10.1/24)

  # LAN's /64 slice of the delegated prefix (subnet-id 0x49)
  LAN_IPV6_PREFIX = "2a02:8010:6680:49::";
  LAN_IPV6_ADDRESS = "${LAN_IPV6_PREFIX}1";  # router on lan (…:49::1/64)

  # ---------------------------------------------------------------------------
  # Subnets
  # ---------------------------------------------------------------------------
  LAN_SUBNET = "192.168.49.0/24";
  VLAN10_SUBNET = "192.168.10.0/24";
  PODMAN_SUBNET = "192.168.100.0/24";        # podman containers
  WIREGUARD_SUBNET = "10.47.0.0/16";         # wg0 tunnel
  TAILSCALE_SUBNET = "100.64.0.0/10";        # headscale ip_prefixes (CGNAT)
  HACKSPACE_SUBNET = "10.3.0.0/16";          # via grafton-hackspace-client VM
  DELEGATED_PREFIX = "2a02:8010:6680::/48";  # IPv6 delegated by Zen (PPPoE)
  DBTHR33_SUBNET = "2a0a:ef40:241::/48";     # dbthr33-server's network — trusted
                                             # so its direct WireGuard/NAS traffic
                                             # is accepted (see tailscale-slow.md)

  # ---------------------------------------------------------------------------
  # Service ports
  # ---------------------------------------------------------------------------
  SSH_PORT = 22;
  HTTP_PORT = 80;
  HTTPS_PORT = 443;
  STUN_PORT = 3479;                          # headscale DERP STUN
  TAILSCALE_PORT = 41641;                    # tailscale wireguard (all nodes)
  MDNS_PORT = 5353;
  HOME_ASSISTANT_PORT = 8123;                # Home Assistant (host-network container)

  # ---------------------------------------------------------------------------
  # DNS
  # ---------------------------------------------------------------------------
  # AdGuard answers LAN clients on :53; dnsmasq owns the grafton.lan zone (and
  # DHCP) on :8053 and is an upstream of AdGuard.
  DNS_PORT = 53;
  DNSMASQ_PORT = 8053;

  # ---------------------------------------------------------------------------
  # DHCP (dnsmasq)
  # ---------------------------------------------------------------------------
  DHCPV4_CLIENT_PORT = 68;                   # bootpc
  DHCPV4_SERVER_PORT = 67;                   # bootps
  DHCPV6_CLIENT_PORT = 546;                  # router as DHCPv6 client (PD)
  DHCPV6_SERVER_PORT = 547;                  # ISP's DHCPv6 server / dnsmasq

  LAN_DHCP_V4_RANGE = "192.168.49.101,192.168.49.200";
  VLAN10_DHCP_V4_RANGE = "192.168.10.101,192.168.10.200";
  DHCP_LEASE_TIME = "1h";
}
