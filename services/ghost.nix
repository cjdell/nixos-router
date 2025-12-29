{ config, ... }:

let
  GHOST_UID = 2368;
in
{
  users.users.ghost = {
    uid = GHOST_UID;
    group = "users";
    isNormalUser = true;
  };

  # journalctl -u podman-ghost -f
  virtualisation.oci-containers.containers = {
    ghost = {
      hostname = "ghost";
      image = "docker.io/ghost:alpine";
      autoStart = true;
      ports = [
        "${toString GHOST_UID}:2368"
      ];
      volumes = [
        "/srv/ghost:/var/lib/ghost/content"
      ];
      environment = {
        TZ = "Europe/London";
        url = "https://chrisdell.info";
        database__client = "sqlite3";
        database__useNullAsDefault = "true";
        database__connection__filename = "/var/lib/ghost/content/data/ghost.db";
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
      port = GHOST_UID + 1;
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
        url = "http://localhost:2370/default";
      };
    };
  };

  services.clickhouse = {
    enable = true;
    serverConfig = {
      http_port = GHOST_UID + 1;
      tcp_port = GHOST_UID + 2;
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
    mkdir -p /srv/ghost

    # Ensure correct permissions
    chown -R ${toString GHOST_UID}:users /srv/ghost
    chmod -R g+rw /srv/ghost
  '';

  services.nginx.virtualHosts = {
    "chrisdell.info" = {
      useACMEHost = "chrisdell.info";
      forceSSL = true;

      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString GHOST_UID}";
        recommendedProxySettings = true;
        proxyWebsockets = true;
      };
    };

    "analytics.home.chrisdell.info" = {
      useACMEHost = "chrisdell.info";
      forceSSL = true;

      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString (GHOST_UID + 1)}";
        recommendedProxySettings = true;
        proxyWebsockets = true;
      };
    };
  };
}
