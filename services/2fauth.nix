{
  users.users.two2fauth = {
    uid = 8900;
    isNormalUser = true;
  };

  virtualisation.oci-containers.containers = {
    twofauth = {
      hostname = "twofauth";
      image = "2fauth/2fauth";
      autoStart = true;
      volumes = [
        "/srv/2fauth:/2fauth"
      ];
      ports = [
        "8900:8000/tcp"
      ];
      environment = {
        TZ = "Europe/London";
        TRUSTED_PROXIES = "*";
        APP_URL = "https://2fauth.home.chrisdell.info";
        APP_KEY = "SomeRandomStringOf32CharsExactly";
      };
      extraOptions = [
        # "--uidmap=1000:8900:1"
        # "--gidmap=1000:100:1"
      ];
    };
  };

  # sudo podman run -ti --rm -v /srv/2fauth:/2fauth --uidmap=1000:8900:1 --gidmap=1000:100:1 --entrypoint=/bin/sh 2fauth/2fauth
  # sudo podman run -ti --rm --uidmap=1000:8900:1 --gidmap=1000:100:1 --user=8900:100 --entrypoint=/bin/sh 2fauth/2fauth

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
        proxyPass = "http://127.0.0.1:8900";
        recommendedProxySettings = true;
        proxyWebsockets = true;
      };
    };
  };
}
