{
  config,
  lib,
  pkgs,
  ...
}: {
  ## List all backups
  # sudo list-backups-srv
  #
  ## Restore a backup to the current working directory
  # sudo restore-backup-srv router-backup-srv-2025-12-26T08:48:42
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "list-backups-srv" ''
      export BORG_RSH="ssh -i ${config.sops.secrets.borg_backup_key.path}"
      borg list ssh://backup@gen8-nas.grafton.lan/sas-16tb/ds-external-backups/borg/router.home.chrisdell.info/srv
    '')

    (pkgs.writeShellScriptBin "restore-backup-srv" ''
      export BORG_RSH="ssh -i ${config.sops.secrets.borg_backup_key.path}"
      borg extract --list ssh://backup@gen8-nas.grafton.lan/sas-16tb/ds-external-backups/borg/router.home.chrisdell.info/srv::$1 /srv
    '')
  ];

  # journalctl -u borgbackup-job-backup-srv -b
  services.borgbackup.jobs.backup-srv = let
    containers = config.virtualisation.oci-containers.containers;
    containerNames = lib.attrNames containers;
    stopCommand = lib.concatMapStringsSep "\n" (name: "systemctl stop podman-${name}") containerNames;
    startCommand = lib.concatMapStringsSep "\n" (name: "systemctl start podman-${name}") containerNames;
  in {
    paths = "/srv";
    exclude = [ "**/*.mp4" ];
    encryption.mode = "none";
    environment.BORG_RSH = "ssh -i ${config.sops.secrets.borg_backup_key.path}";
    repo = "ssh://backup@gen8-nas.grafton.lan/sas-16tb/ds-external-backups/borg/router.home.chrisdell.info/srv";
    compression = "auto,zstd";
    startAt = "*-*-* 04:00:00";
    preHook = stopCommand;
    postHook = ''
      ${startCommand}
      sleep 120
      if [ $exitStatus -eq 0 ]; then
        ${pkgs.curl}/bin/curl -X POST -H 'Content-type: application/json' --data '{"title":"Backup","message":"Container volumes backup complete"}' https://notify.home.chrisdell.info
      fi
    '';
  };
}
