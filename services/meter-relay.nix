{ lib, pkgs, ... }:

let
  meter-relay = (
    pkgs.writeShellScriptBin "meter-relay" ''
      ${pkgs.nodejs}/bin/node node_modules/.bin/tsx src/index-control.ts
    ''
  );
in
{
  # sudo systemctl restart meter-relay
  # journalctl -u meter-relay -f
  systemd.services.meter-relay = {
    environment = {
      LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib";
    };

    serviceConfig = {
      Type = "simple";
      WorkingDirectory = "/home/cjdell/Projects/meter-relay";
      ExecStart = "${lib.getExe meter-relay}";
      Restart = "always";
      RestartSec = 5;
    };
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
  };
}
