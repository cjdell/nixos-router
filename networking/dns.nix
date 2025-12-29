{
  pkgs,
  ...
}:

{
  environment.systemPackages = [ pkgs.dnsmasq ];

  # cat /var/lib/dnsmasq/dnsmasq.leases
  services.dnsmasq = {
    enable = true;
    resolveLocalQueries = false;
    settings = {
      # bind to 8053, we want adguard to provide DNS
      # and we'll let resolved own the loopback port 53
      port = 8053;
      no-resolv = true;
      bind-dynamic = true;
      dhcp-authoritative = true;
      domain-needed = true;
      enable-ra = true;

      addn-hosts = "${pkgs.writeText "service-hosts" ''
        192.168.49.1    router.grafton.lan
        192.168.49.1    hass.grafton.lan
        192.168.49.1    mqtt.grafton.lan
      ''}";

      domain = "grafton.lan";
      local = "/grafton.lan/";

      dhcp-range = [
        "set:lan,192.168.49.101,192.168.49.200,255.255.255.0,1h"
        "set:vlan10,192.168.10.101,192.168.10.200,255.255.255.0,1h"

        "set:lan,2a02:8010:6680:49::,slaac,64"
      ];
      dhcp-option = [
        "tag:lan,option:dns-server,192.168.49.1"
        "tag:vlan10,option:dns-server,192.168.10.1"
      ];

      dhcp-host = [
        "40:f2:01:55:d9:46,Lab-OpenWRT                ,192.168.49.2,1h"
        "e0:91:f5:48:5a:c9,Front-OpenWrt              ,192.168.49.3,1h"
        "d4:35:1d:7b:b3:9f,Back-Vodafone              ,192.168.49.4,1h"
        "60:b5:8d:89:1c:5d,spare-fritzbox             ,192.168.49.5,1h"

        "00:e0:4d:02:cd:56,N100-NAS                   ,192.168.49.22,1h"
        "3c:a8:2a:a0:1e:4c,GEN8-NAS                   ,192.168.49.21,1h"
        "24:05:0f:6d:be:4e,experiments                ,192.168.49.25,1h"

        "b8:27:eb:0c:2e:3b,inverter-pi                ,192.168.49.30,1h"
        "30:83:98:16:51:c3,zigbee                     ,192.168.49.31,1h"
        "c0:49:ef:f0:0a:bc,jk-bms-can                 ,192.168.49.32,1h"
        "c0:49:ef:f0:0f:34,jk-bms-can-2               ,192.168.49.33,1h"
        "7c:2c:67:d1:66:a4,front-house-wled           ,192.168.49.34,1h"
        "84:28:59:e9:c4:ab,fire-tv                    ,192.168.49.35,1h"

        "c4:dd:57:3e:5a:b2,plug-01                    ,192.168.49.41,1h"
        "c4:dd:57:1f:a8:f9,plug-02                    ,192.168.49.42,1h"
        "70:03:9f:68:b5:bd,plug-03                    ,192.168.49.43,1h"
        "c4:dd:57:21:12:28,plug-04                    ,192.168.49.44,1h"

        "74:56:3c:6f:aa:16,zen3-nixos                 ,192.168.49.50,1h"
        "e0:d5:5e:27:c9:65,zen1-nixos                 ,192.168.49.51,1h"
        "fc:aa:14:06:38:cc,haswellmatx-nixos          ,192.168.49.53,1h"
        "10:7b:44:1a:97:fc,haswellatx-nixos           ,192.168.49.54,1h"
        "1c:1b:0d:e6:ac:8a,kabylakeitx-nixos          ,192.168.49.55,1h"
        "6c:4b:90:af:0c:f9,coffeelakelenovo-nixos     ,192.168.49.56,1h"
        "hp-elitedesk-ryzen-2400-nixos                ,192.168.49.57,1h"
        "lenovo-thinkcentre-core-11400-nixos          ,192.168.49.58,1h"
        "dell-optiplex-core-4770-nixos                ,192.168.49.60,1h"
        "e4:54:e8:aa:d2:66,coffeelakedell-nixos       ,192.168.49.61,1h"
        "8c:ec:4b:53:8a:bf,dell-vostro-kabylake-nixos ,192.168.49.62,1h"
        "asus-xeon-1270v5-nixos,                      ,192.168.49.63,1h"
        "lenovo-thinkcentre-core-8400-c-nixos         ,192.168.49.64,1h"
        "hp-z240-xeon-1240v6-nixos                    ,192.168.49.65,1h"

        "f0:77:c3:9f:4e:12,rocketlakelatitude-nixos   ,192.168.49.67,1h"
        "7c:76:35:f8:e1:bb,precision-nixos            ,192.168.49.68,1h"
        "18:3e:ef:c6:1c:2f,MacBookAir                 ,192.168.49.69,1h"

        "d4:f5:47:2f:76:93,Small-Bedroom-Speaker      ,192.168.49.71,1h"
        "e4:f0:42:08:e3:1e,Front-Bedroom-Speaker      ,192.168.49.72,1h"
        "a4:77:33:4f:17:5e,Kitchen-Speaker            ,192.168.49.73,1h"

        "ec:71:db:d1:21:8a,HallwayCamera              ,192.168.49.81,1h"
      ];
    };
  };
}
