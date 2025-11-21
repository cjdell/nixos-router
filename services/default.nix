{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

{
  imports = [
    ./2fauth.nix
    ./adguard.nix
    ./frigate.nix
    ./home-assistant.nix
    ./immich.nix
    ./influxdb.nix
    ./jellyfin.nix
    ./meter-relay.nix
    ./mosquitto.nix
    ./wireguard.nix
    ./zigbee2mqtt.nix
  ];
}
