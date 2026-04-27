{
  pkgs,
  ...
}:

let
  PG_AUTH = ''
    #type   database  DBuser  auth-method
    local   all       all     trust
    host    sameuser  all     127.0.0.1/32          scram-sha-256
    host    sameuser  all     ::1/128               scram-sha-256
    host    sameuser  all     192.168.0.0/16        scram-sha-256
    host    sameuser  all     10.47.0.0/16          scram-sha-256
    host    sameuser  all     2001:8b0:1d14::0/48   scram-sha-256
    host    sameuser  all     2a02:8010:6680::0/48  scram-sha-256
    host    sameuser  all     2a00:23c8:b0ac::0/48  scram-sha-256
  '';
in
{
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_17;
    enableTCPIP = true;

    settings = {
      ssl = true;
    };

    authentication = pkgs.lib.mkOverride 10 PG_AUTH;
  };

  # journalctl -u postgres-cert -b
  systemd.services.postgres-cert = {
    script = ''
      mkdir -p ~postgres
      chown -R postgres:postgres ~postgres
      cd ~postgres
      if [ -f PG_VERSION ]; then
        if [ ! -f server.crt ]; then
          ${pkgs.sudo}/bin/sudo -u postgres ${pkgs.openssl}/bin/openssl req -new -x509 -days 3650 -nodes -text -out server.crt -keyout server.key -subj "/CN=N100-NAS.grafton.lan"
          chmod og-rwx server.key
        else
          echo "Postgres Cert already exists"
        fi
      else
        echo "Postgres directory not available yet"
      fi
    '';

    requiredBy = [ "postgresql.service" ];
    before = [ "postgresql.service" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };

  services.postgresqlBackup = {
    enable = true;
    startAt = "*-*-* 01:30:00";
    pgdumpOptions = "--no-owner";
    location = "/srv/postgres";
  };

  system.activationScripts.postgresBackup = ''
    mkdir -p /srv/postgres
    chown -R postgres:postgres /srv/postgres
  '';
}

## Open a PSQL shell to the database
# sudo -u postgres psql my_db

## Restore a backup
# sudo -u postgres psql my_db < backup.sql

## Dump schema for the "my_table" table
# sudo -u postgres pg_dump -st my_table my_db
