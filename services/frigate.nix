{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

let
  FRIGATE_UID = 8971;
  CONFIG = import ../config.nix;
in
{
  users.users.frigate = {
    uid = FRIGATE_UID;
    group = "users";
    isNormalUser = true;
  };

  # journalctl -u podman-frigate -f
  virtualisation.oci-containers.containers = {
    frigate = {
      hostname = "frigate";
      image = "ghcr.io/blakeblackshear/frigate:stable";
      autoStart = true;
      volumes = [
        "/srv/frigate/storage:/media/frigate"
        "/srv/frigate/config:/config"
      ];
      ports = [
        "8971:5000" # Insecure
        # "8971:8971" # Secure
        "1984:1984" # go2rtc admin panel
        "8554:8554"
        "8555:8555/tcp"
        "8555:8555/udp"
      ];
      environment = {
        FRIGATE_RTSP_PASSWORD = "password";
      };
      extraOptions = [
        "--mount=type=tmpfs,destination=/tmp/cache,tmpfs-size=1000000000"
        "--device=/dev/dri/renderD128"
        "--shm-size=1024m"
        "--cap-add=CAP_PERFMON"
        "--privileged"
      ];
    };
  };

  system.activationScripts.frigate = ''
    # Create config and storage directories
    mkdir -p /srv/frigate/storage
    mkdir -p /srv/frigate/config

    # Ensure correct permissions
    chown -R ${toString FRIGATE_UID}:users /srv/frigate
    chmod -R g+rw /srv/frigate
  '';

  services.nginx.virtualHosts = {
    "frigate.home.chrisdell.info" = {
      useACMEHost = "chrisdell.info";
      forceSSL = true;

      basicAuth = {
        admin = builtins.readFile CONFIG.HTTP_PASSWORD_FILE;
      };

      locations."/" = {
        proxyPass = "http://127.0.0.1:8971";
        recommendedProxySettings = true;
        proxyWebsockets = true;
      };
    };
  };
}
