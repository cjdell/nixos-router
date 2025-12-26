let
  ZIGBEE2MQTT_UID = 8124;
in
{
  users.users.zigbee2mqtt = {
    uid = ZIGBEE2MQTT_UID;
    group = "users";
    isNormalUser = true;
  };

  # journalctl -u podman-zigbee2mqtt -f
  # sudo systemctl restart podman-zigbee2mqtt
  virtualisation.oci-containers.containers = {
    zigbee2mqtt = {
      hostname = "zigbee2mqtt";
      image = "koenkk/zigbee2mqtt";
      autoStart = true;
      ports = [
        "8124:8080"
      ];
      volumes = [
        "/srv/zigbee2mqtt:/app/data"
        "/run/udev:/run/udev:ro"
      ];
      environment = {
        TZ = "Europe/London";
      };
      extraOptions = [
        "--user=${toString ZIGBEE2MQTT_UID}:100"
      ];
    };
  };

  system.activationScripts.zigbee2mqtt = ''
    # Create config directory
    mkdir -p /srv/zigbee2mqtt

    # Ensure correct permissions
    chown -R ${toString ZIGBEE2MQTT_UID}:users /srv/zigbee2mqtt
    chmod -R g+rw /srv/zigbee2mqtt
  '';
}
