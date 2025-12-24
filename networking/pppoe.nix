{
  config,
  lib,
  pkgs,
  ...
}:

{
  systemd.network.networks."21-pppoe-zen" = {
    matchConfig.Name = "pppoe-zen";
    linkConfig.RequiredForOnline = false;
    networkConfig = {
      KeepConfiguration = true;
      DHCP = "ipv6";
    };
    dhcpV6Config = {
      PrefixDelegationHint = "::/48";
      WithoutRA = "solicit";
    };
  };

  sops.templates."pppoe-credentials".content = ''
    name "zen383475@zen"
    password "${config.sops.placeholder.pppoe_password}"
  '';

  services.pppd = {
    enable = true;
    peers = {
      # the peer name here, and ifname below can be specific to your setup
      zen-pppoe = {
        autostart = true;
        enable = true;
        # wan-fttp is the named NIC from the networkd configuration
        # if your ISP doesn't offer baby-jumbo frames, set mtu to 1492
        config = ''
          plugin pppoe.so wan-fttp

          file ${config.sops.templates."pppoe-credentials".path}

          noauth
          noipdefault
          hide-password
          persist
          maxfail 0
          holdoff 5
          mtu 1492
          lcp-echo-interval 10
          lcp-echo-failure 6
          noaccomp
          default-asyncmap

          +ipv6 ipv6cp-use-ipaddr ipv6cp-accept-local

          ifname pppoe-zen
        '';
      };
    };
  };

  systemd.services."pppd-zen-pppoe".preStart = ''
    # bring up the interface so ppp can use it
    ${pkgs.iproute2}/bin/ip link set wan-fttp up
  '';

  # routing (pppoe)
  environment.etc.ppp-up = {
    # this script runs after PPP has established a connection
    # we'll use it to log, and add the default IPv4 and IPv6 routes
    enable = true;
    target = "ppp/ip-up";
    mode = "0755";
    text = ''
      #!${pkgs.bash}/bin/bash
      ${pkgs.logger}/bin/logger "$1 is up"
      if [ $IFNAME = "pppoe-zen" ]; then
        ${pkgs.logger}/bin/logger "zen - FTTP PPPoE online"

        ${pkgs.logger}/bin/logger "Add default routes via PPPoE"
        ${pkgs.iproute2}/bin/ip route add default dev pppoe-zen scope link metric 100
        ${pkgs.iproute2}/bin/ip -6 route add default dev pppoe-zen scope link metric 100

        ${pkgs.systemd}/bin/networkctl reconfigure pppoe-zen
      fi
    '';
  };

  environment.etc.ppp-down = {
    # this script runs after the PPP connection drops
    # we'll use it to log, and remove the default routes
    enable = true;
    target = "ppp/ip-down";
    mode = "0755";
    text = ''
      #!${pkgs.bash}/bin/bash
      ${pkgs.logger}/bin/logger "$1 is down"
      if [ $IFNAME = "pppoe-zen" ]; then
        ${pkgs.logger}/bin/logger "zen - FTTP PPPoE offline"

        ${pkgs.logger}/bin/logger "Remove default routes via PPPoE"
        ${pkgs.iproute2}/bin/ip route del default dev pppoe-zen scope link metric 100
        ${pkgs.iproute2}/bin/ip -6 route del default dev pppoe-zen scope link metric 100
      fi
    '';
  };

  # For networks that use the delegated prefix it is necessary to reconfigure them once the PPP interface is ready
  services.networkd-dispatcher = {
    enable = true;
    rules."reconfigure-vlan" = {
      onState = [ "configured" ];
      script = ''
        #!${pkgs.runtimeShell}

        # shellcheck disable=SC2154

        echo "$IFACE"="$AdministrativeState"
        if [[ "$IFACE" == "pppoe-zen" && "$AdministrativeState" == "configured" ]]; then
          echo "==== Reconfiguring VLAN10"
          ${pkgs.systemd}/bin/networkctl reconfigure vlan10
        fi
        exit 0
      '';
    };
  };
}
