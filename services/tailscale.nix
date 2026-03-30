{ config, ... }:

{
  services.tailscale = {
    enable = true;
    authKeyFile = config.sops.secrets.tailscale_pre_authkey.path;
    extraUpFlags = [
      "--login-server=https://tailscale.home.chrisdell.info"
      "--advertise-routes=192.168.49.0/24"
      "--accept-dns=false"
      "--accept-routes=false"
    ];
  };
}
