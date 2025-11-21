{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

{
  services.influxdb2 = {
    enable = true;
  };

  services.nginx.virtualHosts = {
    "influxdb.home.chrisdell.info" = {
      useACMEHost = "chrisdell.info";
      forceSSL = true;

      locations."/" = {
        proxyPass = "http://127.0.0.1:8086";
        recommendedProxySettings = true;
        proxyWebsockets = true;
      };
    };
  };
}
