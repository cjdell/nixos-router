{
  config,
  lib,
  pkgs,
  ...
}:

{
  virtualisation.libvirtd = {
    enable = true;
    allowedBridges = [ "lan" ];
  };

  # journalctl -u grafton-hackspace-client-routes -f
  systemd.services.grafton-hackspace-client-routes = {
    description = "Grafton Hackspace Client Routes";

    wantedBy = [ "multi-user.target" ];

    after = [ "microvm-set-booted@grafton-hackspace-client.service" ];
    requires = [ "microvm-set-booted@grafton-hackspace-client.service" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${lib.getExe pkgs.bash} -c 'sleep 30; ${pkgs.iproute2}/bin/ip route add 10.3.0.0/16 via 192.168.49.15'";
    };
  };

  microvm.vms = {
    grafton-hackspace-client = {
      inherit pkgs;

      config = {
        services.openssh = {
          enable = true;
          settings.PermitRootLogin = "yes";
          hostKeys = [
            {
              bits = 256;
              path = "/var/secrets/ssh_host_ed25519_key";
              type = "ed25519";
            }
          ];
        };

        system.activationScripts.addHostKey = ''
          mkdir -p /var/secrets
          cat ${./vm-host.key} > /var/secrets/ssh_host_ed25519_key
          chmod 0400 /var/secrets/ssh_host_ed25519_key
        '';

        users.users.root.initialHashedPassword = "$y$j9T$8aqblMqV7q3.bcfzur3jd/$ldh1xzyCl4Dpq9QtPR76KTYSdhN3BmXB5kKFXiBKsU.";

        microvm = {
          shares = [
            {
              source = "/nix/store";
              mountPoint = "/nix/.ro-store";
              tag = "ro-store";
              proto = "virtiofs";
            }
            {
              source = "/run/secrets";
              mountPoint = "/run/secrets";
              tag = "secrets";
              proto = "virtiofs";
              readOnly = true;
            }
          ];

          interfaces = [
            {
              type = "tap";
              # Interface name on the host
              id = "vm-ts1-tap";
              # Ethernet address of the MicroVM's interface, not the host's
              mac = "02:00:00:00:00:15";
            }
          ];
        };

        networking = {
          useDHCP = false;
          useNetworkd = true;

          nftables.enable = true;
          firewall.enable = false;
        };

        boot.kernel.sysctl = {
          "net.ipv4.conf.all.forwarding" = true;
          "net.ipv6.conf.all.forwarding" = true;
        };

        systemd.network = {
          enable = true;

          links = {
            "10-lan" = {
              matchConfig.Type = "ether";
              linkConfig = {
                Name = "br-host";
              };
            };
          };

          networks = {
            "10-lan" = {
              matchConfig.Name = "br-host";
              networkConfig = {
                IPv6AcceptRA = true;
                DHCP = "yes";
              };
            };
          };
        };

        services.tailscale = {
          enable = true;
          authKeyFile = config.sops.secrets.leigh_hackspace_tailscale_pre_auth_key.path;
          useRoutingFeatures = "client";
          extraUpFlags = [
            "--login-server=https://tailscale.leighhack.org"
            "--advertise-routes=192.168.49.0/24"
            "--advertise-exit-node"
            "--accept-dns=true"
            "--accept-routes=true"
          ];
        };

        networking.nftables.tables = {
          firewall = {
            family = "inet";
            content = ''
              chain input {
                type filter hook input priority filter; policy accept;
              }

              chain forward {
                type filter hook forward priority 0; policy accept;
              }

              chain output {
                type filter hook output priority 0; policy accept;
              }
            '';
          };

          nat = {
            family = "ip";
            content = ''
              chain pre {
                type nat hook prerouting priority dstnat; policy accept;
              }

              chain post {
                type nat hook postrouting priority srcnat; policy accept;

                iifname "br-host" oifname "tailscale0" masquerade
              }

              chain out {
                type nat hook output priority mangle; policy accept;
              }
            '';
          };
        };

        system.stateVersion = "26.05";
      };
    };
  };
}
