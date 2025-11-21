{
  config,
  lib,
  pkgs,
  modulesPath,
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

  # journalctl -u homeassistant-frigate-install -f
  systemd.services =
    let
      homeassistant-frigate = (
        pkgs.writeShellScriptBin "homeassistant-frigate" ''
          ${pkgs.wget}/bin/wget -O frigate-ha.zip https://codeload.github.com/blakeblackshear/frigate-hass-integration/zip/refs/heads/master
          ${pkgs.unzip}/bin/unzip frigate-ha.zip
          rm frigate-ha.zip
          cp -rf frigate-hass-integration-master/custom_components/frigate /srv/homeassistant/config/custom_components/
          rm -rf frigate-hass-integration-master

          # Ensure correct permissions
          chown -R ${toString HOME_ASSISTANT_UID}:users /srv/homeassistant
          chmod -R g+rw /srv/homeassistant
        ''
      );
    in
    {
      homeassistant-frigate-install = {
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];

        wantedBy = [ "podman-homeassistant.service" ];
        before = [ "podman-homeassistant.service" ];

        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${homeassistant-frigate}/bin/homeassistant-frigate";
        };
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
    };
  };
}
