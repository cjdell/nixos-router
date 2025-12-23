{ pkgs, ... }:

let
  mkSSOVirtualHost = import ../utils/nginx-sso-helper.nix;
in
{
  # sudo journalctl -u http-dump -f
  # sudo systemctl restart http-dump
  systemd.services.http-dump = {
    description = "HTTP Dump";

    # Ensure the service is started at boot
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      ExecStart = "${pkgs.deno}/bin/deno task start";
      Restart = "always";
      RestartSec = 5;
      WorkingDirectory = "/home/cjdell/Projects/http-dump";
      User = "cjdell";
      Group = "users";
      Environment = [
        "PORT=10000"
      ];
    };
  };

  services.nginx.virtualHosts = {
    "http-dump.home.chrisdell.info" = mkSSOVirtualHost {
      proxyPass = "http://127.0.0.1:10000";
    };
  };
}
