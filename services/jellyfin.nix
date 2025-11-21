{ config, lib, pkgs, modulesPath, ... }:

{
  services.nginx.virtualHosts = {
    "jellyfin.home.chrisdell.info" = {
      useACMEHost = "chrisdell.info";
      forceSSL = true;

      locations."/" = {
        proxyPass = "http://192.168.49.22:8096";
        recommendedProxySettings = true;
        proxyWebsockets = true;
      };
    };
  };
}
