{
  config,
  lib,
  ...
}:

let
  mkSSOVirtualHost = import ../../../utils/nginx-sso-helper.nix;
  inherit (import ../../../utils/convert.nix { inherit lib; }) convertToEnvFile;
in
{
  # ============================================================================
  # Beszel — lightweight server monitoring (hub + agent)
  # Web UI: https://beszel.home.chrisdell.info (SSO protected)
  #
  # The agent on this host reports:
  #   - system stats (CPU / RAM / disk / network / temperature)
  #   - podman containers (via the docker-compat socket, podman group)
  #   - systemd services (via D-Bus, see the beszel-agent module)
  # SMART disk health and GPU metrics can be enabled later if wanted.
  # ============================================================================

  # --- Hub (web UI + API) ------------------------------------------------------
  services.beszel.hub = {
    enable = true;
    # Bound to localhost only; nginx proxies (and SSO-protects) the UI
    host = "127.0.0.1";
    port = 8090;

    environment = {
      APP_URL = "https://beszel.home.chrisdell.info";

      # SSO via nginx-sso: trust the X-WEBAUTH-USER header (set by nginx after
      # Kanidm login) so once a user account exists with the same email, every
      # visit auto-authenticates via the header. Password auth is left enabled:
      # DISABLE_PASSWORD_AUTH=true would hide the create-admin form during
      # first-run (a beszel UI quirk), and the header already supersedes it.
      TRUSTED_AUTH_HEADER = "X-WEBAUTH-USER";
    };
  };

  # Run the hub under a fixed user so we can provision its SSH key up-front.
  # (The module default is a DynamicUser, whose uid we can't know in advance.)
  users.users.beszel-hub = {
    uid = 9011;
    isSystemUser = true;
    group = "beszel-hub";
  };
  users.groups.beszel-hub = { };

  systemd.services.beszel-hub = {
    wants = [ "beszel-hub-key.service" ];
    after = [ "beszel-hub-key.service" ];
    serviceConfig = {
      DynamicUser = lib.mkForce false;
      # history-sync was removed from beszel 0.18; the nixpkgs module still
      # references it (harmless but noisy in the journal)
      ExecStartPre = lib.mkForce [
        "${config.services.beszel.hub.package}/bin/beszel-hub migrate up"
      ];
    };
  };

  # The hub generates its own ed25519 keypair on first start. We generate it
  # up-front instead, so the agent can be configured with the matching public
  # key in the same deploy (beszel-agent >= 0.18 refuses to start without one).
  # The private key is kept in sops: losing /var/lib/beszel-hub would otherwise
  # force re-keying every agent.
  systemd.services.beszel-hub-key = {
    description = "Provision Beszel hub SSH key";
    wantedBy = [ "multi-user.target" ];
    before = [ "beszel-hub.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      mkdir -p /var/lib/beszel-hub/beszel_data
      chown beszel-hub:beszel-hub /var/lib/beszel-hub /var/lib/beszel-hub/beszel_data
      install -m 0600 -o beszel-hub -g beszel-hub \
        ${config.sops.secrets.beszel_hub_key.path} \
        /var/lib/beszel-hub/beszel_data/id_ed25519
    '';
  };

  # --- Agent (collects metrics on this host) -----------------------------------
  services.beszel.agent = {
    enable = true;
    # Hub is on this machine, so don't expose the agent's SSH port to the network
    environment.LISTEN = "127.0.0.1:45876";
    # Hub's public key (from sops so it doesn't end up in the Nix store)
    environmentFile = config.sops.templates."beszel-agent.env".path;
  };

  # Stable location for the agent's data (e.g. its fingerprint)
  systemd.services.beszel-agent.serviceConfig.StateDirectory = "beszel-agent";

  # --- Secrets ----------------------------------------------------------------
  sops.secrets = {
    beszel_agent_key = { }; # hub's public key, added to the agent's KEY
    beszel_hub_key = { }; # hub's ed25519 private key, provisioned above
  };

  sops.templates."beszel-agent.env".content = convertToEnvFile {
    KEY = "${config.sops.placeholder.beszel_agent_key}";
  };

  # --- nginx / SSO -------------------------------------------------------------
  services.nginx.virtualHosts = {
    "beszel.home.chrisdell.info" = mkSSOVirtualHost {
      proxyPass = "http://127.0.0.1:8090";
    };
  };
}
