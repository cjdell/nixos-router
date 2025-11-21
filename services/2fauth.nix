{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

{
  virtualisation.oci-containers.containers = {
    twofauth = {
      hostname = "twofauth";
      image = "2fauth/2fauth";
      autoStart = true;
      volumes = [
        "/srv/2fauth:/2fauth"
      ];
      ports = [
        "8888:8000/tcp"
      ];
      environment = {
        TZ = "Europe/London";
        TRUSTED_PROXIES = "*";
        APP_URL = "https://2fauth.home.chrisdell.info";
      };
    };
  };

  system.activationScripts.twofauth = ''
    # Create config directory
    mkdir -p /srv/2fauth

    # Ensure correct permissions
    chown -R 1000:users /srv/2fauth
    chmod -R g+rw /srv/2fauth
  '';

  services.nginx.virtualHosts = {
    "2fauth.home.chrisdell.info" = {
      useACMEHost = "chrisdell.info";
      forceSSL = true;

      locations."/" = {
        proxyPass = "http://127.0.0.1:8888";
        recommendedProxySettings = true;
        proxyWebsockets = true;
      };
    };
  };
}
