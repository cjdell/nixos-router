{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  inherit (import ../../../utils/convert.nix { inherit lib; }) convertToEnvFile;
  # Per-system package set (nixos-utils' flake packages are nested by system).
  # Note: in a NixOS module `config.system` is the `system.*` options set, so
  # the architecture must come from `pkgs.hostPlatform.system`.
  containerUi = builtins.getAttr pkgs.hostPlatform.system inputs.nixos-utils.packages;
in
{
  # ============================================================================
  # Container UI — server-rendered web UI for managing podman containers
  # Web UI: https://containers.home.chrisdell.info (Kanidm OIDC login)
  #
  # Shows container state / ports / mounts / CPU / RAM, a live log tail
  # (server-sent events), and can update (pull + restart) one or many
  # containers. Runs as root because it restarts podman-systemd units and
  # uses the rootful podman setup. Binds to 127.0.0.1 only; nginx proxies.
  # ============================================================================

  systemd.services.container-ui = {
    description = "Container management web UI";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      ExecStart = "${containerUi.container-ui}/bin/container-ui";
      # nixpkgs 26.05 dropped the top-level `environmentFile` option
      EnvironmentFile = config.sops.templates."container-ui.env".path;
    };
  };

  # --- Secrets ----------------------------------------------------------------
  # kanidm-provision (runs as the kanidm user) reads this to set the OAuth2
  # client's basic secret; the app gets it via the env file below (rendered
  # as root at activation).
  sops.secrets.container_ui_oidc_client_secret = {
    owner = "kanidm";
  };

  sops.templates."container-ui.env".content = convertToEnvFile {
    LISTEN_ADDR = "127.0.0.1:8091";
    BASE_URL = "https://containers.home.chrisdell.info";
    # Absolute path: podman is not in the default service PATH (systemctl is)
    PODMAN_BIN = "${pkgs.podman}/bin/podman";
    WEBHOOK_URL = "http://127.0.0.1:8888";
    OIDC_ISSUER = "https://kanidm.home.chrisdell.info/oauth2/openid/container-ui";
    OIDC_CLIENT_ID = "container-ui";
    OIDC_CLIENT_SECRET = "${config.sops.placeholder.container_ui_oidc_client_secret}";
    OIDC_REDIRECT_URI = "https://containers.home.chrisdell.info/oidc/callback";
    RUST_LOG = "info";
  };

  # --- nginx ------------------------------------------------------------------
  # NOT mkSSOVirtualHost: the app does its own Kanidm OIDC login.
  services.nginx.virtualHosts."containers.home.chrisdell.info" = {
    useACMEHost = "chrisdell.info";
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:8091";
      recommendedProxySettings = true;
      # SSE (live log tail) must not be buffered
      extraConfig = "proxy_buffering off;";
    };
  };
}
