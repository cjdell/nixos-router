let
  net = import ./constants.nix;
in
{
  systemd.network = {
    enable = true;
    wait-online.enable = false;

    links = {
      "100-lan" = {
        # Left side port
        matchConfig = {
          MACAddress = "68:1d:ef:36:e9:94";
        };
        linkConfig = {
          Name = "rawlan";
        };
      };

      "200-wan-fttp" = {
        # Right side port
        matchConfig = {
          MACAddress = "68:1d:ef:36:e9:95";
        };
        linkConfig = {
          Name = "wan-fttp";
        };
      };
    };

    netdevs = {
      # Bridge needed for QEMU quests
      "99-lan" = {
        netdevConfig = {
          Kind = "bridge";
          Name = net.LAN_INTERFACE;
          MACAddress = "68:1d:ef:36:e9:99";
        };
      };

      "110-vlan10" = {
        netdevConfig = {
          Kind = "vlan";
          Name = net.VLAN10_INTERFACE;
        };
        vlanConfig.Id = 10;
      };
    };

    networks = {
      "99-lan-bridge" = {
        matchConfig.Name = [
          "rawlan"
          "vm-*"
        ];
        linkConfig.RequiredForOnline = "yes";
        networkConfig = {
          DHCP = false;
        };
        bridge = [ net.LAN_INTERFACE ];
      };

      "100-lan" = {
        matchConfig.Name = net.LAN_INTERFACE;
        linkConfig.RequiredForOnline = "yes";
        networkConfig = {
          DHCP = false;
          # have networkd send IPv6 router advertisements
          IPv6SendRA = true;
        };
        ipv6SendRAConfig = {
          # RAs should include the router's IP for DNS
          EmitDNS = true;
          DNS = net.LAN_IPV6_ADDRESS;
        };
        vlan = [
          net.VLAN10_INTERFACE
        ];
        address = [
          "${net.LAN_IPV4}/24"
          "${net.LAN_IPV6_ADDRESS}/64"
        ];
        dns = [ net.LAN_IPV4 ];
        domains = [ "grafton.lan" ];
      };

      # Experimental VLAN
      "110-vlan10" = {
        matchConfig.Name = net.VLAN10_INTERFACE;
        linkConfig.RequiredForOnline = "carrier";
        networkConfig = {
          DHCP = false;
          # have networkd send IPv6 router advertisements
          IPv6SendRA = true;
          DHCPPrefixDelegation = "yes";
        };
        dhcpPrefixDelegationConfig = {
          SubnetId = "0x10";
        };
        address = [
          "${net.VLAN10_IPV4}/24"
        ];
      };

      "200-wan-fttp" = {
        # networkd should ignore the NIC connected to the fibre modem
        matchConfig.Name = "wan-fttp";
        linkConfig = {
          Unmanaged = "yes";
          RequiredForOnline = "no";
        };
      };
    };
  };
}
