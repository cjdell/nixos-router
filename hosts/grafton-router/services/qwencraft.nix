{
  pkgs,
  lib,
  ...
}:

let
  # The deployed binary (shipped by the qwencraft repo's deploy.sh into
  # /srv/qwencraft-server) was linked against the build box's glibc, so its
  # ELF interpreter points at store paths that don't exist on this host.
  # Run it through this host's dynamic loader explicitly, with this host's
  # glibc + libgcc as the library search path — no patchelf, no store copy,
  # so redeploying a new binary is just "rsync + systemctl restart".
  # (Router glibc 2.42 >= build-box glibc 2.40, so all needed symbols exist.)
  qwencraftNetExec = [
    "${pkgs.glibc}/lib/ld-linux-x86-64.so.2"
  ]
  ++ (lib.flatten (
    lib.map
      (d: [
        "--library-path"
        d
      ])
      [
        "${pkgs.glibc}/lib64"
        "${pkgs.glibc}/lib"
        "${pkgs.libgcc}/lib"
      ]
  ))
  ++ [
    "/srv/qwencraft-server/qwencraft-net"
    "--bind"
    "127.0.0.1"
    "--port"
    "9000"
  ];
in
{
  # Headless Qwencraft server: one port (127.0.0.1:9000) hosts the game
  # WebSocket (/ws), the operator dashboard (/dashboard/) and its API
  # (/api/*). Bound to loopback, only reachable through the nginx vhost
  # below.
  systemd.services.qwencraft-net = {
    description = "Qwencraft headless game server (WebSocket + dashboard)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = lib.concatStringsSep " " qwencraftNetExec;
      Restart = "always";
      RestartSec = 5;
    };
  };

  # Static-file host for the Qwencraft voxel-engine web build.
  # The live assets live in /srv/qwencraft (populated from the qwencraft
  # `web/dist` wasm build). All *.home.chrisdell.info vhosts share the
  # wildcard Let's Encrypt cert issued for chrisdell.info (dns-01 / route53),
  # so no new ACME/DNS work is needed beyond adding this vhost.
  #
  # /ws, /dashboard, /api and /healthz are proxied to the local headless
  # server (systemd unit `qwencraft-net`, 127.0.0.1:9000): the game page can
  # join the shared world over WebSocket, the dashboard (served by the server
  # under /dashboard/) polls /api/* same-origin, and /healthz is the liveness
  # probe — those requests would 404 (or hit the SPA fallback) against the
  # static root if not proxied.
  services.nginx.virtualHosts."qwencraft.home.chrisdell.info" = {
    useACMEHost = "chrisdell.info";
    forceSSL = true;

    locations."/ws" = {
      proxyPass = "http://127.0.0.1:9000";
      recommendedProxySettings = true;
      proxyWebsockets = true;
    };

    locations."/dashboard" = {
      proxyPass = "http://127.0.0.1:9000";
      recommendedProxySettings = true;
    };

    locations."/api/" = {
      proxyPass = "http://127.0.0.1:9000";
      recommendedProxySettings = true;
    };

    locations."/healthz" = {
      proxyPass = "http://127.0.0.1:9000";
      recommendedProxySettings = true;
    };

    locations."/" = {
      root = "/srv/qwencraft";

      extraConfig = ''
        # SPA-style fallback: extensionless paths (e.g. "/") resolve to the
        # app shell so navigating to a sub-path still loads the page.
        try_files $uri $uri/ /index.html;
      '';
    };
  };

  # The project was renamed rustcraft -> qwencraft; keep the old domain
  # alive as a permanent redirect so bookmarks and old links still work.
  # (Remove this vhost once the old URL has stopped seeing traffic.)
  services.nginx.virtualHosts."rustcraft.home.chrisdell.info" = {
    useACMEHost = "chrisdell.info";
    forceSSL = true;
    locations."/" = {
      return301 = "https://qwencraft.home.chrisdell.info$request_uri";
    };
  };
}
