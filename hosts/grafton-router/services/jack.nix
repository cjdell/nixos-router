{
  pkgs,
  ...
}:

let
  # Static site served by nginx; kept up to date by update-jsb.service
  siteDir = "/home/cjdell/Projects/Portfolio-Website";

  doGitPull = pkgs.writeShellApplication {
    name = "do-git-pull";
    runtimeInputs = with pkgs; [
      git
      openssh
    ];
    text = "git pull";
  };
in
{
  services.nginx = {
    enable = true;

    virtualHosts = {
      # Home page
      "jacksballard.com" = {
        useACMEHost = "jacksballard.com";
        forceSSL = true;

        locations."/" = {
          root = siteDir;
        };
      };

      "www.jacksballard.com" = {
        useACMEHost = "jacksballard.com";
        forceSSL = true;

        locations."/" = {
          return = "301 https://jacksballard.com";
        };
      };
    };
  };

  systemd.timers = {
    update-jsb = {
      timerConfig = {
        Unit = "update-jsb.service";
        # OnBootSec is required: OnUnitActiveSec alone never fires if the
        # service has never been active, leaving the timer permanently idle.
        OnBootSec = "2min";
        OnUnitActiveSec = "1h";
      };
      wantedBy = [ "timers.target" ];
    };
  };
  systemd.services = {
    update-jsb = {
      serviceConfig = {
        Type = "oneshot";
        User = "cjdell";
        WorkingDirectory = siteDir;
        ExecStart = "${doGitPull}/bin/do-git-pull";
      };
    };
  };
}
