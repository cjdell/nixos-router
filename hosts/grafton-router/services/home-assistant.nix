{
  config,
  lib,
  pkgs,
  ...
}:

let
  constants = import ../constants.nix;
  HOME_ASSISTANT_UID = 8123;
in
{
  users.users.homeassistant = {
    uid = HOME_ASSISTANT_UID;
    group = "users";
    isNormalUser = true;
  };

  hardware.bluetooth.enable = true;

  virtualisation.oci-containers.containers = {
    # sudo systemctl restart podman-homeassistant
    # journalctl -u podman-homeassistant -f
    homeassistant = {
      hostname = "homeassistant";
      image = "linuxserver/homeassistant";
      autoStart = true;
      volumes = [
        "/srv/homeassistant/config:/config"
        "/etc/localtime:/etc/localtime:ro"
        "/run/dbus:/run/dbus:ro"
      ];
      environment = {
        TZ = "Europe/London";
        PUID = "${toString HOME_ASSISTANT_UID}";
        PGID = "100";
      };
      extraOptions = [
        "--network"
        "host"
        "--privileged"
        "--cap-add"
        "NET_ADMIN"
        "--cap-add"
        "NET_RAW"
      ];
    };

    # journalctl -u podman-matter-server -f
    matter-server = {
      hostname = "matter-server";
      image = "ghcr.io/home-assistant-libs/python-matter-server:stable";
      autoStart = true;
      volumes = [
        "/srv/homeassistant/matter:/data"
        "/run/dbus:/run/dbus:ro"
      ];
      environment = {
        TZ = "Europe/London";
        PUID = "${toString HOME_ASSISTANT_UID}";
        PGID = "100";
      };
      extraOptions = [
        "--network"
        "host"
        "--privileged"
        "--cap-add"
        "NET_ADMIN"
        "--cap-add"
        "NET_RAW"
      ];
      cmd = [
        "--storage-path"
        "/data"
        "--paa-root-cert-dir"
        "/data/credentials"
        "--bluetooth-adapter"
        "0"
      ];
    };
  };

  # journalctl -u podman-wyoming-speech-to-phrase -f
  virtualisation.oci-containers-unescaped.containers = {
    wyoming-speech-to-phrase = {
      hostname = "wyoming-speech-to-phrase";
      image = "rhasspy/wyoming-speech-to-phrase";
      autoStart = true;
      volumes = [
        "/srv/wyoming-speech-to-phrase/models:/models"
        "/srv/wyoming-speech-to-phrase/train:/train"
      ];
      ports = [
        "10300:10300"
      ];
      extraOptions = [
        "--privileged"
        "--ip=10.88.0.101"
      ];
      cmd = [
        "--hass-websocket-uri"
        "http://${constants.HOME_ASSISTANT_HOSTNAME}:8123/api/websocket"
        "--retrain-on-sta"
        "--hass-token"
      ];
      cmdNoEscape = [
        "$(cat ${config.sops.secrets.home_assistant_token.path})"
      ];
    };
  };

  systemd.services.podman-wyoming-speech-to-phrase = {
    after = [ "wait-for-homeassistant.service" ];
    requires = [ "wait-for-homeassistant.service" ];
  };

  # journalctl -u wait-for-homeassistant -f
  systemd.services.wait-for-homeassistant = {
    description = "Wait for Network";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${lib.getExe pkgs.bash} -c 'until ${lib.getExe pkgs.curl} -sSf http://${constants.HOME_ASSISTANT_HOSTNAME}:8123 >/dev/null 2>&1; do sleep 2; done; sleep 1'";
      TimeoutStartSec = 300;
    };
  };

  systemd.tmpfiles.settings = {
    "10-homeassistant" = {
      "/srv/homeassistant/config" = {
        d = {
          user = "homeassistant";
          group = "users";
          mode = "0775";
        };
      };

      "/srv/homeassistant/matter" = {
        d = {
          user = "homeassistant";
          group = "users";
          mode = "0775";
        };
      };

      "/srv/wyoming-speech-to-phrase/models" = {
        d = {
          user = "homeassistant";
          group = "users";
          mode = "0775";
        };
      };

      "/srv/wyoming-speech-to-phrase/train" = {
        d = {
          user = "homeassistant";
          group = "users";
          mode = "0775";
        };
      };
    };
  };

  # journalctl -u homeassistant-hacs-install -b
  systemd.services.homeassistant-hacs-install =
    let
      homeassistant-hacs = (
        pkgs.writeShellScriptBin "homeassistant-hacs" ''
          ${pkgs.coreutils-full}/bin/sleep 5

          ${lib.getExe pkgs.wget} -O /srv/homeassistant/hacs.zip https://github.com/hacs/integration/releases/latest/download/hacs.zip
          rm -rf /srv/homeassistant/config/custom_components/hacs
          mkdir -p /srv/homeassistant/config/custom_components/hacs
          ${lib.getExe pkgs.unzip} /srv/homeassistant/hacs.zip -d /srv/homeassistant/config/custom_components/hacs
          rm /srv/homeassistant/hacs.zip
        ''
      );
    in
    {
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      before = [ "podman-homeassistant.service" ];
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

        extraConfig = ''
          add_header 'Access-Control-Allow-Origin' * always;

          if ($request_method = 'OPTIONS') {
            add_header 'Access-Control-Allow-Origin' '*';
            add_header 'Access-Control-Allow-Credentials' 'true';
            add_header 'Access-Control-Allow-Methods' '*';
            add_header 'Access-Control-Allow-Headers' '*';
            add_header 'Access-Control-Max-Age' 86400;
            add_header 'Content-Type' 'text/plain charset=UTF-8';
            add_header 'Content-Length' 0;
            return 204; break;
          }
        '';
      };

      # SSO support
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
