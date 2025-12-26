let
  mkSSOVirtualHost = import ../utils/nginx-sso-helper.nix;
in
{
  services.adguardhome = {
    enable = true;
    # Any changes made through the web UI will be thrown away
    mutableSettings = false;
    # Admin UI port
    port = 8153;
    settings = {
      # Admin UI listen address (NGINX proxies this)
      host = "127.0.0.1";

      # Split DNS for internal network services. Allows things to still work without internet access.
      user_rules = [
        "192.168.49.1 router.home.chrisdell.info"
        "192.168.49.1 notify.home.chrisdell.info"
      ];

      dns = {
        bind_hosts = [
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
          "https://dns.quad9.net/dns-query"
          "https://dns.mullvad.net/dns-query"
          "https://cloudflare-dns.com/dns-query"
          # Requests for the local domain go to dnsmasq
          "[/grafton.lan/]127.0.0.1:8053"
          "[/int.leighhack.org/]10.3.1.1:53"
        ];
        local_ptr_upstreams = [
          # Reverse lookups for local IPs go to dnsmasq
          "127.0.0.1:8053"
        ];
        bootstrap_dns = [
          "9.9.9.9"
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
