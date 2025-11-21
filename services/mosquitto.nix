{ config, lib, pkgs, modulesPath, ... }:

let
  MQTT_UID = 1883;
in
{
  users.users.mosquitto = {
    uid = MQTT_UID;
    group = "users";
    isNormalUser = true;
  };

  virtualisation.oci-containers.containers = {
    mqtt = {
      hostname = "mqtt";
      image = "docker.io/eclipse-mosquitto";
      autoStart = true;
      ports = [
        "1883:1883"
      ];
      volumes = [
        "/srv/mosquitto:/mosquitto"
      ];
      environment = {
        TZ = "Europe/London";
      };
      extraOptions = [
        "--ip=10.88.1.1"
        "--user=${toString MQTT_UID}:100"
      ];
    };
  };

  system.activationScripts.mqtt = ''
    # Create config directory
    mkdir -p /srv/mosquitto

    # Ensure correct permissions
    chown -R ${toString MQTT_UID}:users /srv/mosquitto
    chmod -R g+rw /srv/mosquitto
  '';
}
