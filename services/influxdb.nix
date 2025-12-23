{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:


let
  INFLUXDB_DATA_UID = 125;
in
{
  users.users.influxdb_data = {
    uid = INFLUXDB_DATA_UID;
    group = "influxdb_data";
    isSystemUser = true;
  };

  users.groups.influxdb_data = {
    gid = INFLUXDB_DATA_UID;
  };

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
