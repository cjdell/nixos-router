{ lib }:
let
  CONFIG = import ../config.nix;

  readSecret = file: lib.strings.trim (builtins.readFile file);
in
lib.generators.toYAML { } {
  login = {
    title = "Kanidm - Login";
    default_method = "oidc";
    hide_mfa_field = true;
    names.oidc = "Kanidm Account";
  };

  cookie = {
    domain = ".home.chrisdell.info";
    authentication_key = "12345678901234567890";
    expire = 86400;
  };

  listen = {
    addr = "0.0.0.0";
    port = 8082;
  };

  audit_log = {
    targets = [
      "fd://stdout"
      "file:///var/log/nginx-sso/audit.jsonl"
    ];
    events = [
      "access_denied"
      "login_success"
      "login_failure"
      "logout"
      "validate"
    ];
    headers = [ "x-origin-uri" ];
    trusted_ip_headers = [
      "X-Forwarded-For"
      "RemoteAddr"
      "X-Real-IP"
    ];
  };

  acl.rule_sets = [
    # Grant Authenticated Access
    {
      rules = [
        {
          field = "x-host";
          regexp = ".*";
        }
      ];
      allow = [ "@_authenticated" ];
    }
  ];

  providers.oidc = {
    client_id = "nginx-sso";
    client_secret = "cjct0uTCbsG1pMQpzYeYVgjWMRCtj9yNaSfHCr41xRxwAZFt";
    redirect_url = "https://nginx-sso.home.chrisdell.info/login";
    issuer_name = "chrisdell.info";
    issuer_url = "https://kanidm.home.chrisdell.info/oauth2/openid/nginx-sso";
    user_id_method = "full-email"; # upstream_http_x_username
  };
}
