{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

let
  CONFIG = import ../config.nix;
in
{
  networking.wireguard.interfaces = {
    # "wg0" is the network interface name. You can name the interface arbitrarily.
    wg0 = {
      # Determines the IP address and subnet of the client's end of the tunnel interface.
      ips = [ "10.47.49.1/16" ];
      listenPort = 51820; # to match firewall allowedUDPPorts (without this wg uses random port numbers)

      # Path to the private key file.
      #
      # Note: The private key can also be included inline via the privateKey option,
      # but this makes the private key world-readable; thus, using privateKeyFile is
      # recommended.
      privateKeyFile = CONFIG.WIREGUARD_KEY_FILE;

      peers = [
        # For a client configuration, one peer entry for the server will suffice.

        {
          # Public key of the server (not a file path).
          publicKey = "gNxnNaKmHNOtA7n38aGdCl1KfD7X+c1CXZg/D89CYiY=";

          # Forward all the traffic via VPN.
          # allowedIPs = [ "0.0.0.0/0" ];
          # Or forward only particular subnets
          allowedIPs = [
            # "10.47.0.0/16"
            "192.168.35.0/24"
            "192.168.98.0/24"
#            "10.3.0.0/16"
          ];

          # Set this to the server IP and port.
          endpoint = "ovh-nix.chrisdell.info:51820"; # ToDo: route to endpoint not automatically configured https://wiki.archlinux.org/index.php/WireGuard#Loop_routing https://discourse.nixos.org/t/solved-minimal-firewall-setup-for-wireguard-client/7577

          # Send keepalives every 25 seconds. Important to keep NAT tables alive.
          persistentKeepalive = 25;
        }
      ];
    };
  };

  services.cron = {
    enable = true;
    systemCronJobs = [
      # WireGuard keeps going offline so restart every 5 minutes (doesn't interrupt connections)
      "*/5 * * * * root ${pkgs.systemd}/bin/systemctl restart wireguard-wg0"
    ];
  };
}
