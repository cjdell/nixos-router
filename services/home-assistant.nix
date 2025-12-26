{
  pkgs,
  ...
}:

let
  HOME_ASSISTANT_UID = 8123;
in
{
  users.users.homeassistant = {
    uid = HOME_ASSISTANT_UID;
    group = "users";
    isNormalUser = true;
  };

  # sudo systemctl restart podman-homeassistant
  virtualisation.oci-containers.containers = {
    homeassistant = {
      hostname = "homeassistant";
      image = "linuxserver/homeassistant";
      autoStart = true;
      volumes = [
        "/srv/homeassistant/config:/config"
        # "/run/dbus:/run/dbus:ro"
      ];
      environment = {
        TZ = "Europe/London";
        PUID = "${toString HOME_ASSISTANT_UID}";
        PGID = "100";
      };
      extraOptions = [
        "--network=host"
      ];
    };
  };

  system.activationScripts.homeassistant = ''
    # Create config directory
    mkdir -p /srv/homeassistant/config

    # Ensure correct permissions
    chown -R ${toString HOME_ASSISTANT_UID}:users /srv/homeassistant
    chmod -R g+rw /srv/homeassistant
  '';

  # journalctl -u homeassistant-hacs-install -f
  systemd.services.homeassistant-hacs-install =
    let
      homeassistant-hacs = (
        pkgs.writeShellScriptBin "homeassistant-hacs" ''
          ${pkgs.coreutils-full}/bin/sleep 5

          ${pkgs.wget}/bin/wget -O /srv/homeassistant/hacs.zip https://github.com/hacs/integration/releases/latest/download/hacs.zip
          rm -rf /srv/homeassistant/config/custom_components/hacs
          mkdir -d /srv/homeassistant/config/custom_components/hacs
          ${pkgs.unzip}/bin/unzip /srv/homeassistant/hacs.zip -d /srv/homeassistant/config/custom_components/hacs
          rm /srv/homeassistant/hacs.zip
        ''
      );
    in
    {
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      before = [ "podman-homeassistant.service" ];
      wantedBy = [ "podman-homeassistant.service" ];
      requiredBy = [ "podman-homeassistant.service" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${homeassistant-hacs}/bin/homeassistant-hacs";

        User = "homeassistant";
        Group = "users";
      };
    };

  services.nginx.virtualHosts = {
    "home.chrisdell.info" = {
      useACMEHost = "chrisdell.info";
      forceSSL = true;

      locations."/" = {
        proxyPass = "http://127.0.0.1:8123";
        recommendedProxySettings = true;
        proxyWebsockets = true;
      };

      # Authentik support
      locations."/auth/authorize" = {
        proxyPass = "http://127.0.0.1:8123";
        recommendedProxySettings = true;
        extraConfig = ''
          sub_filter_once off;
          sub_filter_types text/html;
          sub_filter '<head>' '<head><script>setTimeout(function(){window.location.href="/auth/oidc/redirect";},1000);</script>';
          proxy_set_header Accept-Encoding "";
        '';
      };
    };
  };
}
