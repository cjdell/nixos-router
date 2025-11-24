{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

let
  update-containers = (
    pkgs.writeShellScriptBin "update-containers" ''
      images=$(${pkgs.podman}/bin/podman ps -a --format="{{.Image}}" | sort -u)

      for image in $images; do
        ${pkgs.podman}/bin/podman pull $image
      done

      ${pkgs.systemd}/bin/systemctl restart podman-*
    ''
  );

  list-container-ips = (
    pkgs.writeShellScriptBin "list-container-ips" ''
      for container_id in $(${pkgs.podman}/bin/podman ps -q); do
        json=$(${pkgs.podman}/bin/podman inspect $container_id)
        container_ip=$(echo "$json" | ${pkgs.jq}/bin/jq -r '.[].NetworkSettings.Networks | to_entries[] | .value.IPAddress')
        container_name=$(echo "$json" | ${pkgs.jq}/bin/jq -r '.[].Name')
        echo "Container Name: $container_name, Container ID: $container_id, IP Address: $container_ip"
      done
    ''
  );
in
{
  virtualisation.podman = {
    enable = true;
    autoPrune.enable = true;
    dockerCompat = true;
    dockerSocket.enable = true;
    # I will use static container IPs instead. Need to AdGuard to bind port 53 on 0.0.0.0
    defaultNetwork.settings.dns_enabled = false;
  };

  virtualisation.containers.containersConf.settings.containers.umask = "0002";

  virtualisation.oci-containers.backend = "podman";

  systemd.timers = {
    update-containers = {
      timerConfig = {
        Unit = "update-containers.service";
        OnCalendar = "Mon 02:00";
      };
      wantedBy = [ "timers.target" ];
    };
  };
  systemd.services = {
    update-containers = {
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${update-containers}/bin/update-containers";
      };
    };
  };

  environment.systemPackages = [
    update-containers
    list-container-ips
  ];
}
