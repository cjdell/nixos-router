{
  config,
  lib,
  ...
}:

let
  mkSSOVirtualHost = import ../../../utils/nginx-sso-helper.nix;
in
{
  # ============================================================================
  # Health — realtime system health dashboard
  # Web UI: https://health.home.chrisdell.info (SSO protected)
  #
  # A Rust backend samples /proc (CPU / memory / network / disk IO / disk
  # space / load / temperatures) every second and serves a dioxus SPA with
  # canvas charts and selectable time ranges (1m … 24h). History is
  # in-memory only — it resets on service restart.
  #
  # Provided by the `health` module in the nixos-utils repo
  # (`services.health` options). This file just enables it and adds the
  # SSO-protected nginx vhost, following the house pattern.
  # ============================================================================

  services.health.enable = true;
  # defaults: LISTEN_ADDR=127.0.0.1:8092, 1s samples, 1h @ 1s + 24h @ 10s

  services.nginx.virtualHosts."health.home.chrisdell.info" = mkSSOVirtualHost {
    proxyPass = "http://127.0.0.1:8092";
  };
}
