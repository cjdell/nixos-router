{
  pkgs,
  ...
}:

let
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
          root = "/srv/jacksballard.com-live";
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
        WorkingDirectory = "/srv/jacksballard.com-live";
        ExecStart = "${doGitPull}/bin/do-git-pull";
      };
    };
  };
}
