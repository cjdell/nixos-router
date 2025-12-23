{
  config,
  pkgs,
  ...
}:

{
  # Grant kanidm access to nginx group for ACME certificates
  users.users.kanidm.extraGroups = [ config.services.nginx.group ];

  # sudo kanidmd recover-account admin
  # sudo kanidmd recover-account idm_admin
  services.kanidm = {
    enableServer = true;
    package = pkgs.kanidm_1_8;

    provision = {
      enable = true;
      persons = {
        cjdell = {
          present = true;
          displayName = "Chris Dell";
          legalName = "Chris Dell";
          mailAddresses = [ "me@chrisdell.info" ];
        };
        testuser = {
          present = true;
          displayName = "Test User";
          legalName = "Test User";
          mailAddresses = [ "testuser@example.com" ];
        };
      };
      groups = {
        "admins" = {
          present = true;
          members = [ "cjdell" ];
          overwriteMembers = true;
        };
      };
      systems = {
        # kanidm system oauth2 show-basic-secret home-assistant
        oauth2 = {
          "home-assistant" = {
            present = true;
            public = false;
            displayName = "Home Assistant";
            originUrl = "https://home.chrisdell.info/auth/oidc/callback";
            originLanding = "https://home.chrisdell.info";
            preferShortUsername = true;
            scopeMaps = {
              "admins" = [
                "email"
                "openid"
                "profile"
                "groups"
              ];
            };
          };
          # kanidm system oauth2 show-basic-secret grafana
          "grafana" = {
            present = true;
            public = false;
            displayName = "Grafana";
            originUrl = "https://grafana.home.chrisdell.info";
            originLanding = "https://grafana.home.chrisdell.info/login/generic_oauth";
            preferShortUsername = true;
            scopeMaps = {
              "admins" = [
                "email"
                "openid"
                "profile"
                "groups"
              ];
            };
            claimMaps = {
              grafana_role = {
                joinType = "array";
                valuesByGroup = {
                  admins = [ "GrafanaAdmin" ];
                };
              };
            };
          };
          # kanidm system oauth2 show-basic-secret filebrowser
          "filebrowser" = {
            present = true;
            public = false;
            displayName = "File Browser";
            originUrl = "https://filebrowser.home.chrisdell.info/api/auth/oidc/callback";
            originLanding = "https://filebrowser.home.chrisdell.info/api/auth/oidc/login";
            preferShortUsername = true;
            scopeMaps = {
              "admins" = [
                "email"
                "openid"
                "profile"
                "groups"
              ];
            };
            allowInsecureClientDisablePkce = true;
          };
          # kanidm system oauth2 show-basic-secret immich
          "immich" = {
            present = true;
            public = false;
            displayName = "Immich";
            originUrl = [
              "https://immich.home.chrisdell.info/auth/login"
              "app.immich:///oauth-callback"
            ];
            originLanding = "https://immich.home.chrisdell.info/auth/login?autoLaunch=1";
            preferShortUsername = true;
            scopeMaps = {
              "admins" = [
                "email"
                "openid"
                "profile"
                "groups"
              ];
            };
            claimMaps = {
              immich_role = {
                joinType = "array";
                valuesByGroup = {
                  admins = [ "admin" ];
                  # users = [ "user" ];
                };
              };
            };
          };
          # kanidm system oauth2 show-basic-secret nginx-sso
          "nginx-sso" = {
            present = true;
            public = false;
            displayName = "NGINX SSO";
            originUrl = "https://nginx-sso.home.chrisdell.info/login";
            originLanding = "https://nginx-sso.home.chrisdell.info";
            preferShortUsername = true;
            scopeMaps = {
              "admins" = [
                "email"
                "openid"
                "profile"
                "groups"
              ];
            };
            allowInsecureClientDisablePkce = true;
          };
        };
      };
      extraJsonFile = pkgs.writeText "kanidm_extra" (
        builtins.toJSON {
          persons.cjdell.enableUnix = true;
        }
      );
    };

    serverSettings = {
      bindaddress = "127.0.0.1:${toString 8999}";
      ldapbindaddress = "0.0.0.0:${toString 8998}";

      tls_chain = "/var/lib/acme/chrisdell.info/fullchain.pem";
      tls_key = "/var/lib/acme/chrisdell.info/key.pem";

      domain = "kanidm.home.chrisdell.info";
      origin = "https://kanidm.home.chrisdell.info";

      online_backup = {
        schedule = "00 00 * * 1";
        versions = 7;
      };
    };
  };

  # ldapsearch -H ldaps://kanidm.home.chrisdell.info:8998 -x '(name=cjdell@kanidm.home.chrisdell.info)' '*'
  # ldapsearch -H ldaps://kanidm.home.chrisdell.info:8998 -x -b "dc=kanidm,dc=home,dc=chrisdell,dc=info" "(objectClass=*)"
  # ldapsearch -H ldaps://kanidm.home.chrisdell.info:8998 -x -b "dc=kanidm,dc=home,dc=chrisdell,dc=info" -D "cjdell@kanidm.home.chrisdell.info" -W "(objectClass=*)"
  # ldapsearch -H ldaps://kanidm.home.chrisdell.info:8998 -x -b "dc=kanidm,dc=home,dc=chrisdell,dc=info" -D "cjdell@kanidm.home.chrisdell.info" -W "(uid=cjdell)" cn mail uid
  # ldapwhoami -H ldaps://kanidm.home.chrisdell.info:8998 -x -D "cjdell@kanidm.home.chrisdell.info" -W

  environment.systemPackages = with pkgs; [
    kanidm_1_8
    openldap
  ];

  environment.variables = {
    KANIDM_URL = "https://kanidm.home.chrisdell.info";
    KANIDM_NAME = "idm_admin";
  };

  # The kanidm module won't let us set the db_path directly.
  systemd.services.kanidm.serviceConfig.BindPaths = [
    "/srv/kanidm:/var/lib/kanidm"
  ];

  services.nginx.virtualHosts = {
    "kanidm.home.chrisdell.info" = {
      useACMEHost = "chrisdell.info";
      forceSSL = true;

      locations."/" = {
        proxyPass = "https://127.0.0.1:${toString 8999}";
        extraConfig = ''
          proxy_ssl_verify off;
          proxy_ssl_server_name on;
          proxy_ssl_name chrisdell.info;
        '';
      };
    };
  };

  system.activationScripts.kanidm = ''
    # Create config directory
    mkdir -p /srv/kanidm

    # Ensure correct permissions
    chown -R kanidm:kanidm /srv/kanidm
    chmod -R g+rwX /srv/kanidm
  '';
}
