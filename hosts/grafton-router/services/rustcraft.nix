# Static-file host for the RustCraft voxel-engine web build.
# The live assets live in /srv/rustcraft (populated from the rustcraft
# `web/dist` wasm build). All *.home.chrisdell.info vhosts share the wildcard
# Let's Encrypt cert issued for chrisdell.info (dns-01 / route53), so no new
# ACME/DNS work is needed beyond adding this vhost.
{
  services.nginx.virtualHosts = {
    "rustcraft.home.chrisdell.info" = {
      useACMEHost = "chrisdell.info";
      forceSSL = true;

      locations."/" = {
        root = "/srv/rustcraft";

        extraConfig = ''
          # SPA-style fallback: extensionless paths (e.g. "/") resolve to the
          # app shell so navigating to a sub-path still loads the page.
          try_files $uri $uri/ /index.html;
        '';
      };
    };
  };
}
