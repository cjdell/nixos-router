{
  pkgs,
  ...
}:

let
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
  system.updateContainers = {
    enable = true;
    webhookUrl = "http://localhost:8888";
  };

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

  environment.systemPackages = [
    list-container-ips
  ];
}
