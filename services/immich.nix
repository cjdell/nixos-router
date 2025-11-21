{ config, lib, pkgs, modulesPath, ... }:

{
  services.nginx.virtualHosts = {
    "immich.home.chrisdell.info" = {
      useACMEHost = "chrisdell.info";
      forceSSL = true;

      locations."/" = {
        proxyPass = "http://192.168.49.22:2283";
        recommendedProxySettings = true;
        proxyWebsockets = true;

        extraConfig = ''
          client_max_body_size 50000M;
          proxy_read_timeout   600s;
          proxy_send_timeout   600s;
          send_timeout         600s;
        '';
      };
    };
  };
}
