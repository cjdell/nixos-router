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
          Name = "lan";
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
      "110-vlan10" = {
        netdevConfig = {
          Kind = "vlan";
          Name = "vlan10";
        };
        vlanConfig.Id = 10;
      };
    };

    networks = {
      "100-lan" = {
        matchConfig.Name = "lan";
        linkConfig.RequiredForOnline = "yes";
        networkConfig = {
          DHCP = false;
          # have networkd send IPv6 router advertisements
          IPv6SendRA = true;
        };
        ipv6SendRAConfig = {
          # RAs should include the router's IP for DNS
          EmitDNS = true;
          DNS = "2a02:8010:6680:49::1";
        };
        vlan = [
          "vlan10"
        ];
        address = [
          "192.168.49.1/24"
          "2a02:8010:6680:49::1/64"
        ];
        dns = [ "192.168.49.1" ];
        domains = [ "grafton.lan" ];
      };

      # Experimental VLAN
      "110-vlan10" = {
        matchConfig.Name = "vlan10";
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
          "192.168.10.1/24"
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
