{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  mkSSOVirtualHost = import ../../../utils/nginx-sso-helper.nix;
  inherit (import ../../../utils/convert.nix { inherit lib; }) convertToEnvFile;
  # Per-system package set (frigate-whisper's flake packages are nested by system)
  fw = inputs.frigate-whisper.packages.${pkgs.hostPlatform.system}.default;
in
{
  # ============================================================================
  # frigate-whisper — VAD + whisper.cpp transcription of Frigate camera audio
  # Web UI: https://whisper.home.chrisdell.info (SSO protected)
  #
  # fw-transcribe: batch job (systemd timer, every 30 min) that extracts speech
  #   from Frigate recording segments (front_door) and stores snippets in
  #   PostgreSQL. CPU-only, nothing leaves the server.
  # fw-web: axum web UI + API (browse snippets, "Run transcription now"
  #   button via sudoers-gated systemctl), binds 127.0.0.1:8973.
  # ============================================================================

  users.users.frigate-whisper = {
    uid = 8972;
    group = "users";
    isNormalUser = true;
  };

  # --- PostgreSQL (snippets + processed-file tracking) ------------------------
  # Equivalent to: CREATE USER frigate_whisper; CREATE DATABASE frigate_whisper
  # OWNER frigate_whisper; — the SCRAM hash below matches the plaintext password
  # in sops (frigate_whisper_db_password).
  services.postgresql = {
    ensureDatabases = [ "frigate_whisper" ];
    ensureUsers = [
      {
        name = "frigate_whisper";
        ensureDBOwnership = true;
        ensureClauses.password = "SCRAM-SHA-256$4096:Qou/mEyfrJ9ziSiYFx5peA==$VqYEdyOsmDisuDmQ7MsLniTkWKMiT1ehlzHTqzsaFE4=:HEZ2PTBkFCb2ioiGmO/h4EK0fCE9p52vdshJulSqBu8=";
      }
    ];
  };
  services.postgresqlBackup.databases = [ "frigate_whisper" ];

  # --- Batch transcription job (timer-driven) ---------------------------------
  systemd.services.frigate-transcribe = {
    description = "VAD + whisper transcription of Frigate camera recordings";
    after = [ "network-online.target" "postgresql.service" ];
    wants = [ "network-online.target" "postgresql.service" ];
    serviceConfig = {
      Type = "oneshot";
      User = "frigate-whisper";
      Group = "users";
      ExecStart = "${fw}/bin/fw-transcribe";
      EnvironmentFile = config.sops.templates."frigate-whisper.env".path;
      # ffmpeg/ffprobe, whisper-cli + whisper-vad-speech-segments on PATH
      StateDirectory = "frigate-whisper";
      StateDirectoryMode = "0750";
      TimeoutStartSec = "0"; # long batch runs
      Restart = "on-failure";
      RestartSec = "2min";
    };
    environment = {
      FW_STATE_DIR = "/var/lib/frigate-whisper";
      FW_RECORDINGS_DIR = "/srv/frigate/storage/recordings";
      FW_CAMERAS = "front_door";
      FW_MODEL = "ggml-small.en.bin";
      FW_THREADS = "10";
      FW_MAX_FILES = "90";
      FW_MAX_RUN_SECONDS = "1500";
    };
    # ffmpeg/ffprobe + whisper.cpp binaries are not in the default service PATH
    path = [ pkgs.ffmpeg-headless pkgs.whisper-cpp ];
  };

  systemd.timers.frigate-transcribe = {
    description = "Run frigate-transcribe every 30 minutes";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      Unit = "frigate-transcribe.service";
      OnCalendar = "*:0/30";
      Persistent = true;
      RandomizedDelaySec = "3min";
    };
  };

  # --- Web UI ----------------------------------------------------------------
  systemd.services.frigate-whisper-web = {
    description = "frigate-whisper web UI";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" "postgresql.service" ];
    wants = [ "network-online.target" "postgresql.service" ];
    serviceConfig = {
      User = "frigate-whisper";
      Group = "users";
      ExecStart = "${fw}/bin/fw-web";
      EnvironmentFile = config.sops.templates."frigate-whisper.env".path;
      StateDirectory = "frigate-whisper";
      Restart = "always";
      RestartSec = "5s";
    };
    environment = {
      FW_STATE_DIR = "/var/lib/frigate-whisper";
      FW_LISTEN = "127.0.0.1:8973";
      FW_CAMERAS = "front_door";
    };
  };

  # The web UI's "Run transcription now" button spawns
  # `sudo -n systemctl start --no-block frigate-transcribe.service`
  # (exact-arg match required by sudoers).
  security.sudo.extraRules = [
    {
      users = [ "frigate-whisper" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/systemctl start --no-block frigate-transcribe.service";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/systemctl start frigate-transcribe.service";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/systemctl stop frigate-transcribe.service";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  # --- Secrets ---------------------------------------------------------------
  sops.secrets.frigate_whisper_db_password = { };

  sops.templates."frigate-whisper.env".content = convertToEnvFile {
    FW_DATABASE_URL = "postgres://frigate_whisper:${config.sops.placeholder.frigate_whisper_db_password}@127.0.0.1:5432/frigate_whisper?sslmode=disable";
  };

  # --- nginx / SSO ------------------------------------------------------------
  services.nginx.virtualHosts = {
    "whisper.home.chrisdell.info" = mkSSOVirtualHost {
      proxyPass = "http://127.0.0.1:8973";
    };
  };
}
