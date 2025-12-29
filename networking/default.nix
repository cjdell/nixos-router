{
  imports = [
    ./dns.nix
    ./firewall.nix
    ./interface.nix
    ./pppoe.nix
  ];

  boot.kernel.sysctl = {
    # be more swappy as we're using zramswap
    "vm.swappiness" = 100;

    # enable IPv4 and IPv6 forwarding on all interfaces
    "net.ipv4.conf.all.forwarding" = true;
    "net.ipv6.conf.all.forwarding" = true;

    "net.ipv4.conf.all.arp_filter" = 1;
    "net.ipv4.conf.default.arp_filter" = 1;
    "net.ipv6.conf.pppoe-zen.accept_ra" = 2;
    "net.ipv6.conf.pppoe-zen.autoconf" = 1;
  };

  networking = {
    hostName = "router"; # Define your hostname.

    useDHCP = false;
    useNetworkd = true;

    nftables.enable = true;
    firewall.enable = false;
  };
}
