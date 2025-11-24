{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

let
  CONFIG = import ./config.nix;

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

  # NGINX is configured to use pre-existing certicates acquired by the ACME client
  services.nginx = {
    enable = true;

    virtualHosts = {
      "files.home.chrisdell.info" = {
        useACMEHost = "chrisdell.info";
        forceSSL = true;

        locations."/" = {
          root = "/files";
        };
      };
    };
  };
}
