let
  mkSSOVirtualHost = import ../utils/nginx-sso-helper.nix;
in
{
  services.adguardhome = {
    enable = true;
    # any changes made through the web UI will be thrown away
    # on rebuild with this setting...
    mutableSettings = false;
    # Admin port
    port = 8153;
    settings = {
      # note this configuration logs queries by default
      # check the docs if you want to avoid this

      # this will allow unauthenticated access to the adguard UI
      # to any host on your LAN.
      # Change it to 127.0.0.1 if you do not want this
      host = "192.168.49.1";

      dns = {
        bind_hosts = [
          # trusted lan
          "192.168.49.1"
          "192.168.10.1"
          "2a02:8010:6680:49::1"
        ];
        port = 53;
        # some optimisations I found necessary
        ratelimit = 0;
        cache_size = 67108864;
        max_goroutines = 500;
        use_http3_upstreams = true;
        upstream_dns = [
          # you may prefer to use your own ISPs DNS
          "https://dns.quad9.net/dns-query"
          "https://dns.mullvad.net/dns-query"
          "https://cloudflare-dns.com/dns-query"
          # requests for the local domain go to dnsmasq
          "[/grafton.lan/]127.0.0.1:8053"
          "[/int.leighhack.org/]10.3.1.1:53"
        ];
        local_ptr_upstreams = [
          # reverse lookups for local IPs go to dnsmasq
          "127.0.0.1:8053"
        ];
        bootstrap_dns = [
          # you may prefer to use your own ISPs DNS
          "1.1.1.1"
          "8.8.8.8"
        ];
      };
    };
  };

  services.nginx.virtualHosts = {
    "adguard.home.chrisdell.info" = mkSSOVirtualHost {
      proxyPass = "http://127.0.0.1:8153";
    };
  };
}
