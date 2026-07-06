{ config, ... }:

{
  services.tailscale = {
    enable = true;
    authKeyFile = config.sops.secrets.tailscale_pre_auth_key.path;
    useRoutingFeatures = "server";
    extraUpFlags = [
      "--login-server=https://tailscale.home.chrisdell.info"
      "--advertise-routes=192.168.49.0/24"
      "--advertise-exit-node"
      "--accept-dns=false"
      "--accept-routes=false"
    ];
  };

  # networking.nat = {
  #   enable = true;
  #   # Use "ve-*" when using nftables instead of iptables
  #   internalInterfaces = [ "ve-*" ];
  #   externalInterface = "pppoe-zen";
  #   # Lazy IPv6 connectivity for the container
  #   enableIPv6 = true;
  # };

  # # sudo nixos-container root-login tailscale-client-hackspace
  # containers.tailscale-client-hackspace = {
  #   autoStart = true;
  #   bindMounts."${config.sops.secrets.leigh_hackspace_tailscale_pre_auth_key.path}".isReadOnly = true;
  #   enableTun = true;
  #   timeoutStartSec = "15min";

  #   privateNetwork = true;
  #   hostAddress = "192.168.100.1";
  #   localAddress = "192.168.100.11";
  #   hostAddress6 = "fc00::1";
  #   localAddress6 = "fc00::11";

  #   config =
  #     {
  #       containerConfig,
  #       pkgs,
  #       lib,
  #       ...
  #     }:
  #     {

  #       services.httpd = {
  #         enable = true;
  #         adminAddr = "admin@example.org";
  #       };

  #       networking = {
  #         # firewall.allowedTCPPorts = [ 80 ];
  #         firewall.enable = false;

  #         # Use systemd-resolved inside the container
  #         # Workaround for bug https://github.com/NixOS/nixpkgs/issues/162686
  #         useHostResolvConf = lib.mkForce false;

  #         resolvconf = {
  #           extraConfig = ''
  #             name_servers=192.168.49.1
  #           '';
  #         };

  #         nat = {
  #           enable = true;
  #           # Use "ve-*" when using nftables instead of iptables
  #           internalInterfaces = [ "eth0@+" ];
  #           externalInterface = "tailscale0";
  #         };
  #       };

  #       services.resolved.enable = true;

  #       services.tailscale = {
  #         enable = true;
  #         authKeyFile = config.sops.secrets.leigh_hackspace_tailscale_pre_auth_key.path;
  #         useRoutingFeatures = "client";
  #         # interfaceName = "userspace-networking";
  #         extraUpFlags = [
  #           "--login-server=https://tailscale.leighhack.org"
  #           "--advertise-routes=192.168.49.0/24"
  #           "--advertise-exit-node"
  #           "--accept-dns=true"
  #           "--accept-routes=true"
  #         ];
  #       };

  #       system.stateVersion = "26.05";
  #     };
  # };
}
