{
  pkgs,
  ...
}:

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
}
