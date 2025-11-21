{ config, lib, pkgs, modulesPath, ... }:

{
  services.influxdb2 = {
    enable = true;
  };
}
