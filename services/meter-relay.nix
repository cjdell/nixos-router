{ config, lib, pkgs, modulesPath, ... }:

let
  meter-relay = (pkgs.writeShellScriptBin "meter-relay" ''
    ${pkgs.nodejs}/bin/node node_modules/.bin/tsx src/index-control.ts
  '');
in
{
  systemd.services = {
    # sudo systemctl restart meter-relay
    meter-relay = {
      serviceConfig = {
        Type = "simple";
        WorkingDirectory = "/home/cjdell/Projects/meter-relay";
        ExecStart = "${meter-relay}/bin/meter-relay";
        Restart = "always";
        RestartSec = 5;
      };
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
    };
  };
}
