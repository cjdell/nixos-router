{ config, ... }:

let
  GHOST_UID = 2368;

  CHRISDELL_BLOG_PORT = 2360;
  JACKSBALLARD_PORT = 2361;

  PLAUSIBLE_PORT = 9001;
  CLICKHOUSE_HTTP_PORT = 9002;
  CLICKHOUSE_TCP_PORT = 9003;
in
{
  users.users.ghost = {
    uid = GHOST_UID;
    group = "users";
    isNormalUser = true;
  };

  # journalctl -u podman-chrisdell -f
  virtualisation.oci-containers.containers = {
    chrisdell = {
      hostname = "chrisdell";
      image = "docker.io/ghost:alpine";
      autoStart = true;
      ports = [
        "${toString CHRISDELL_BLOG_PORT}:2368"
      ];
      volumes = [
        "/srv/chrisdell.info:/var/lib/ghost/content"
      ];
      environment = {
        TZ = "Europe/London";
        url = "https://chrisdell.info";
        database__client = "sqlite3";
        database__useNullAsDefault = "true";
        database__connection__filename = "/var/lib/ghost/content/data/ghost.db";
        mail__from = "noreply@chrisdell.info";
        security__staffDeviceVerification = "false";
      };
      extraOptions = [
        "--user=${toString GHOST_UID}:100"
      ];
    };
  };

  # journalctl -u podman-jacksballard -f
  virtualisation.oci-containers.containers = {
    jacksballard = {
      hostname = "jacksballard";
      image = "docker.io/ghost:alpine";
      autoStart = true;
      ports = [
        "${toString JACKSBALLARD_PORT}:2368"
      ];
      volumes = [
        "/srv/jacksballard.com:/var/lib/ghost/content"
      ];
      environment = {
        TZ = "Europe/London";
        url = "https://jacksballard.home.chrisdell.info";
        database__client = "sqlite3";
        database__useNullAsDefault = "true";
        database__connection__filename = "/var/lib/ghost/content/data/ghost.db";
        mail__from = "noreply@jacksballard.com";
        security__staffDeviceVerification = "false";
      };
      extraOptions = [
        "--user=${toString GHOST_UID}:100"
      ];
    };
  };

  # journalctl -u plausible -f
  services.plausible = {
    enable = true;
    server = {
      port = PLAUSIBLE_PORT;
      baseUrl = "https://analytics.home.chrisdell.info";
      # secretKeybaseFile is a path to the file which contains the secret generated
      # with openssl as described above.
      secretKeybaseFile = config.sops.secrets.plausible_secret_key.path;
    };
    database = {
      postgres = {
        setup = false;
        dbname = "plausible";
      };
      clickhouse = {
        setup = false;
        url = "http://localhost:${toString CLICKHOUSE_HTTP_PORT}/default";
      };
    };
  };

  services.clickhouse = {
    enable = true;
    serverConfig = {
      http_port = CLICKHOUSE_HTTP_PORT;
      tcp_port = CLICKHOUSE_TCP_PORT;
    };
  };

  services.postgresql = {
    ensureDatabases = [ "plausible" ];
    ensureUsers = [
      {
        name = "plausible";
        ensureDBOwnership = true;
      }
    ];
  };

  services.postgresqlBackup.databases = [ "plausible" ];

  system.activationScripts.ghost = ''
    # Create config and storage directories
    mkdir -p /srv/chrisdell.info
    mkdir -p /srv/jacksballard.com

    # Ensure correct permissions
    chown -R ${toString GHOST_UID}:users /srv/chrisdell.info
    chown -R ${toString GHOST_UID}:users /srv/jacksballard.com

    chmod -R g+rw /srv/chrisdell.info
    chmod -R g+rw /srv/jacksballard.com
  '';

  services.nginx.virtualHosts = {
    "chrisdell.info" = {
      useACMEHost = "chrisdell.info";
      forceSSL = true;

      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString CHRISDELL_BLOG_PORT}";
        recommendedProxySettings = true;
        proxyWebsockets = true;
      };
    };

    "jacksballard.home.chrisdell.info" = {
      useACMEHost = "chrisdell.info";
      forceSSL = true;

      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString JACKSBALLARD_PORT}";
        recommendedProxySettings = true;
        proxyWebsockets = true;
      };
    };

    "analytics.home.chrisdell.info" = {
      useACMEHost = "chrisdell.info";
      forceSSL = true;

      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString PLAUSIBLE_PORT}";
        recommendedProxySettings = true;
        proxyWebsockets = true;
      };
    };
  };
}
