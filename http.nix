{
  config,
  lib,
  pkgs,
  ...
}:

let
  CONFIG = import ./config.nix;

  nginxSsoConfig = import ./utils/nginx-sso-config.nix;

  ROUTE_53_CREDS = ''
    AWS_REGION=us-east-1
    AWS_ACCESS_KEY_ID=AKIAW5QXYEAMOAWTXW4P
    AWS_SECRET_ACCESS_KEY=${CONFIG.AWS_ACCESS_KEY_SECRET_FILE}
  '';

  route53DynamicDnsService = import ./utils/r53-ddns.nix { inherit pkgs route53Creds; };
  route53Creds = "${pkgs.writeText "route53-creds" ROUTE_53_CREDS}";
  route53ZoneConfig = {
    hostname = "home";
    domain = "chrisdell.info";
    zone = "Z02538421F5QYV4YUE5Q";
  };
in
{
  imports = [
    (route53DynamicDnsService route53ZoneConfig)
  ];

  # Use DNS based challenge to acquire SSL certificates. Works even if NGINX is down.
  security.acme = {
    acceptTerms = true;

    defaults = {
      dnsProvider = "route53";
      dnsPropagationCheck = true;
      email = "me@chrisdell.info"; # Your email for Let's Encrypt notifications
      # server = "https://acme-staging-v02.api.letsencrypt.org/directory";
    };

    # Certs stored in /var/lib/acme
    certs = {
      "chrisdell.info" = {
        environmentFile = route53Creds;
        group = config.services.nginx.group; # Ensure nginx can access the certificates
        extraDomainNames = [
          "*.chrisdell.info"
          "*.home.chrisdell.info"
        ];
      };
    };
  };

  # journalctl -u nginx-sso -f
  systemd.services.nginx-sso = {
    description = "NGINX SSO";

    # Ensure the service is started at boot
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      ExecStart = "${pkgs.nginx-sso}/bin/nginx-sso --frontend-dir=${pkgs.nginx-sso}/share/frontend -c ${
        pkgs.writeText "nginx-sso-config" (nginxSsoConfig {
          inherit lib;
        })
      }";
      Restart = "always";
      RestartSec = 5;
    };
  };

  # NGINX is configured to use pre-existing certicates acquired by the ACME client
  services.nginx = {
    enable = true;

    virtualHosts = {
      "nginx-sso.home.chrisdell.info" = {
        useACMEHost = "chrisdell.info";
        forceSSL = true;

        locations."/" = {
          proxyPass = "http://127.0.0.1:8082";
          recommendedProxySettings = true;
        };
      };

      "files.home.chrisdell.info" = {
        useACMEHost = "chrisdell.info";
        forceSSL = true;

        locations."/" = {
          root = "/files";
        };
      };

      # curl -X POST https://notify.home.chrisdell.info -H 'Content-Type: application/json' -d '{"message":"Hello World!","title":"Notification Test"}'
      "notify.home.chrisdell.info" = {
        useACMEHost = "chrisdell.info";
        forceSSL = true;

        locations."/" = {
          proxyPass = "http://127.0.0.1:8123/api/services/notify/mobile_app_hd1913";
          recommendedProxySettings = true;
          extraConfig = ''
            proxy_set_header Authorization "Bearer ${lib.strings.trim (builtins.readFile CONFIG.HOME_ASSISTANT_TOKEN_FILE)}";
          '';
        };
      };

      "grafana.home.chrisdell.info" = {
        useACMEHost = "chrisdell.info";
        forceSSL = true;

        locations."/" = {
          proxyPass = "http://192.168.49.22:3000";
          recommendedProxySettings = true;
          proxyWebsockets = true;
        };
      };

      "filebrowser.home.chrisdell.info" = {
        useACMEHost = "chrisdell.info";
        forceSSL = true;

        locations."/" = {
          proxyPass = "http://192.168.49.22:8002";
          recommendedProxySettings = true;
          proxyWebsockets = true;

          extraConfig = ''
            client_max_body_size 100M;
          '';
        };
      };
    };
  };
}
