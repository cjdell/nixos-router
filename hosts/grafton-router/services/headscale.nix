# Make sure hackspace LAN is advertised
# sudo tailscale set --advertise-routes=2001:8b0:1d14::0/48,10.3.0.0/16

{
  pkgs,
  lib,
  config,
  ...
}:

let
  CONFIG = import ../config.nix;
in
{
  # Necessary for secret access
  users.groups.secrets.members = [ "headscale" ];

  services.headscale = {
    enable = true;
    address = "0.0.0.0";
    port = 8801;

    settings = {
      server_url = "https://tailscale.home.chrisdell.info";

      dns = {
        override_local_dns = false; # Doesn't interfere with local DNS resolution
        base_domain = "grafton.tailscale";
        magic_dns = true;
        search_domains = [ "grafton.lan" ];
        nameservers = {
          global = [
            "9.9.9.9"
            "8.8.8.8"
            "1.1.1.1"
          ];
          split = {
            "grafton.lan" = [ "192.168.49.1" ];
          };
        };
      };

      ip_prefixes = [
        "100.64.0.0/10"
        "fd7a:115c:a1e0::/48"
      ];

      derp = {
        server = {
          enabled = true;
          stun_listen_addr = "0.0.0.0:3479"; # Unify uses default STUN port of 3478
          ipv4 = "51.148.168.145";
          ipv6 = "2a02:8011:d000:672:54a8:5046:eb20:7996";
        };
      };

      oidc = {
        enable = true;
        issuer = "https://kanidm.home.chrisdell.info/oauth2/openid/headscale";
        client_id = "headscale";
        client_secret_path = "${config.sops.secrets.headscale_secret.path}";
        # allowed_groups = [ "admins@kanidm.home.chrisdell.info" "admins" ]; # ???
      };
    };
  };

  services.headplane =
    let
      format = pkgs.formats.yaml { };

      # A workaround generate a valid Headscale config accepted by Headplane when `config_strict == true`.
      settings = lib.recursiveUpdate config.services.headscale.settings {
        tls_cert_path = "/dev/null";
        tls_key_path = "/dev/null";
        policy.path = "/dev/null";
      };

      headscaleConfig = format.generate "headscale.yml" settings;
    in
    {
      enable = true;
      settings = {
        server = {
          host = "127.0.0.1";
          port = 8802;
          cookie_secret_path = pkgs.writeText "cookie_secret_path" "12345678123456781234567812345678";
          base_url = "https://tailscale.home.chrisdell.info/admin";
        };
        headscale = {
          # url = "https://tailscale.home.chrisdell.info";
          url = "http://127.0.0.1:8801";
          config_path = "${headscaleConfig}";
        };
        integration.agent = {
          enabled = true;
          pre_authkey_path = "${config.sops.secrets.headscale_pre_auth_key.path}";
        };
        oidc = {
          issuer = "https://kanidm.home.chrisdell.info/oauth2/openid/headscale";
          client_id = "headscale";
          client_secret_path = "${config.sops.secrets.headscale_secret.path}";
          # Only support login through Authentik (go straight to login)
          disable_api_key_login = true;

          # Might needed when integrating with Authentik.
          # token_endpoint_auth_method = "client_secret_basic";
          token_endpoint_auth_method = "client_secret_post";

          headscale_api_key_path = "${config.sops.secrets.headscale_api_key.path}"; # sudo headscale apikeys create
        };
      };
    };

  services.nginx.virtualHosts = {
    "tailscale.home.chrisdell.info" = {
      useACMEHost = "chrisdell.info";
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:8801";
        recommendedProxySettings = true;
        proxyWebsockets = true;
        # Redirect to the admin (the root URL is just 404 normally)
        extraConfig = ''
          rewrite ^/$ https://tailscale.home.chrisdell.info/admin permanent;
        '';
      };
      locations."/admin" = {
        proxyPass = "http://127.0.0.1:8802";
        recommendedProxySettings = true;
        proxyWebsockets = true;
      };
    };
  };
}
