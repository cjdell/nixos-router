{
  services.nginx.virtualHosts = {
    "webblocks.chrisdell.info" = {
      useACMEHost = "chrisdell.info";
      forceSSL = true;

      locations."/" = {
        root = "/srv/web-blocks";
      };
    };
  };
}
