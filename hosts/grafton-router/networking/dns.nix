{
  pkgs,
  ...
}:

let
  constants = import ../constants.nix;
  net = import ./constants.nix;
in
{
  environment.systemPackages = [ pkgs.dnsmasq ];

  # TFTP server: 192.168.49.50
  # /etc/tftp/ipxe.efi
  # /etc/tftp/undionly.kpxe
  # http://zen3-nixos.grafton.lan/boot/netboot.ipxe

  # cat /var/lib/dnsmasq/dnsmasq.leases
  services.dnsmasq = {
    enable = true;
    resolveLocalQueries = false;
    settings = {
      # bind to 8053, we want adguard to provide DNS
      # and we'll let resolved own the loopback port 53
      port = net.DNSMASQ_PORT;
      no-resolv = true;
      bind-dynamic = true;
      dhcp-authoritative = true;
      domain-needed = true;
      enable-ra = true;

      addn-hosts = "${pkgs.writeText "service-hosts" ''
        ${net.LAN_IPV4}    router.grafton.lan
        ${net.LAN_IPV4}    ${constants.HOME_ASSISTANT_HOSTNAME}
        ${net.LAN_IPV4}    mqtt.grafton.lan
      ''}";

      domain = "grafton.lan";
      local = "/grafton.lan/";

      dhcp-range = [
        "set:lan,${net.LAN_DHCP_V4_RANGE},255.255.255.0,${net.DHCP_LEASE_TIME}"
        "set:vlan10,${net.VLAN10_DHCP_V4_RANGE},255.255.255.0,${net.DHCP_LEASE_TIME}"

        "set:lan,${net.LAN_IPV6_PREFIX},slaac,static,64"
      ];

      dhcp-option = [
        "tag:lan,option:dns-server,${net.LAN_IPV4}"
        "tag:vlan10,option:dns-server,${net.VLAN10_IPV4}"
        # "tag:IsIPXE,option:bootfile-name,http://zen3-nixos.grafton.lan/boot/netboot.ipxe"
      ];

      dhcp-boot = [
        "tag:IsBIOS,/etc/tftp/undionly.kpxe,192.168.49.50,192.168.49.50"
        "tag:IsEFI,/etc/tftp/ipxe.efi,192.168.49.50,192.168.49.50"
        "tag:IsIPXE,http://zen3-nixos.grafton.lan/boot/netboot.ipxe,10.3.14.32,10.3.14.32"
        # RPi 5 eeprom bootloader (tagged by its dhcp-host entry below). It
        # also matches IsEFI (option 93=9) and would pick up ipxe.efi; this
        # line makes the Pi self-contained: the eeprom only uses the
        # next-server field (option 66) for TFTP and ignores the bootfile.
        "tag:pi5,pi5,192.168.49.50"
      ];

      dhcp-match = [
        "set:IsBIOS,93,0"
        "set:IsEFI,93,7"
        "set:IsEFI,93,8"
        "set:IsEFI,93,9"
        "set:IsIPXE,77,iPXE"
      ];

      dhcp-host = [
        "40:f2:01:55:d9:46,Lab-OpenWRT                ,192.168.49.2,1h"
        "e0:91:f5:48:5a:c9,Front-OpenWrt              ,192.168.49.3,1h"
        "d4:35:1d:7b:b3:9f,Back-Vodafone              ,192.168.49.4,1h"
        "60:b5:8d:89:1c:5d,spare-fritzbox             ,192.168.49.5,1h"

        "c0:7b:bc:13:01:46,cisco24poe                 ,192.168.49.10,1h"

        "grafton-hackspace-client                     ,${constants.GRAFTON_HACKSPACE_CLIENT_IP},1h"

        "e4:11:5b:12:c2:ab,N40L-NAS                   ,192.168.49.21,[2a02:8010:6680:49::21],1h"
        "00:e0:4d:02:cd:56,N100-NAS                   ,192.168.49.22,1h"
        "3c:a8:2a:a0:1e:4c,GEN8-NAS                   ,192.168.49.23,1h"
        "24:05:0f:6d:be:4e,experiments                ,192.168.49.25,1h"

        "b8:27:eb:0c:2e:3b,inverter-pi                ,192.168.49.30,1h"
        "30:83:98:16:51:c3,zigbee                     ,192.168.49.31,1h"
        "c0:49:ef:f0:0a:bc,jk-bms-can                 ,192.168.49.32,1h"
        "c0:49:ef:f0:0f:34,jk-bms-can-2               ,192.168.49.33,1h"
        "7c:2c:67:d1:66:a4,front-house-wled           ,192.168.49.34,1h"
        "84:28:59:e9:c4:ab,fire-tv                    ,192.168.49.35,1h"

        "2c:cf:67:c6:64:78,pi-pico                    ,192.168.49.39,1h"

        "c4:dd:57:3e:5a:b2,plug-01                    ,192.168.49.41,1h"
        "c4:dd:57:1f:a8:f9,plug-02                    ,192.168.49.42,1h"
        "70:03:9f:68:b5:bd,plug-03                    ,192.168.49.43,1h"
        "c4:dd:57:21:12:28,plug-04                    ,192.168.49.44,1h"

        "74:56:3c:6f:aa:17,zen3-nixos                 ,192.168.49.50,[2a02:8010:6680:49::50],1h"
        "e0:d5:5e:27:c9:65,zen1-nixos                 ,192.168.49.51,1h"
        "fc:aa:14:06:38:cc,haswellmatx-nixos          ,192.168.49.53,1h"
        "10:7b:44:1a:97:fc,haswellatx-nixos           ,192.168.49.54,1h"
        "1c:1b:0d:e6:ac:8a,kabylakeitx-nixos          ,192.168.49.55,1h"
        "6c:4b:90:af:0c:f9,coffeelakelenovo-nixos     ,192.168.49.56,1h"
        "hp-elitedesk-ryzen-2400-nixos                ,192.168.49.57,1h"
        "lenovo-thinkcentre-core-11400-nixos          ,192.168.49.58,1h"
        "3d-printer-server                            ,192.168.49.60,1h"
        "e4:54:e8:aa:d2:66,coffeelakedell-nixos       ,192.168.49.61,1h"
        "8c:ec:4b:53:8a:bf,dell-vostro-kabylake-nixos ,192.168.49.62,1h"
        "asus-xeon-1270v5-nixos,                      ,192.168.49.63,1h"
        "lenovo-thinkcentre-core-8400-c-nixos         ,192.168.49.64,1h"
        "hp-z240-xeon-1240v6-nixos                    ,192.168.49.65,1h"
        "AirM5                                        ,192.168.49.66,1h"
        "f0:77:c3:9f:4e:12,rocketlakelatitude-nixos   ,192.168.49.67,1h"
        "7c:76:35:f8:e1:bb,precision-nixos            ,192.168.49.68,1h"
        "18:3e:ef:c6:1c:2f,MacBookAir                 ,192.168.49.69,1h"

        "d4:f5:47:2f:76:93,Small-Bedroom-Speaker      ,192.168.49.71,1h"
        "e4:f0:42:08:e3:1e,Front-Bedroom-Speaker      ,192.168.49.72,1h"
        "a4:77:33:4f:17:5e,Kitchen-Speaker            ,192.168.49.73,1h"
        "54:2a:1b:92:3e:7e,Living-Room-Sonos          ,192.168.49.74,1h"

        "ec:71:db:d1:21:8a,HallwayCamera              ,192.168.49.81,1h"

        "nixos-phone                                  ,192.168.49.91,1h"

        # Raspberry Pi 5, network boots NixOS from zen3 (see pi5-progress.md).
        # tag:pi5 selects the tag:pi5 dhcp-boot line above.
        # Format: [hwaddr][,set:<tag>][,<ipaddr>][,<hostname>][,lease-time] —
        # set:pi5 tags this host so the tag:pi5 dhcp-boot line above applies.
        "set:pi5,98:fe:54:18:17:e9,192.168.49.92,pi5,1h"
      ];
    };
  };
}
