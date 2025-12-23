# Helper function to create SSO-protected virtual hosts
let
  mkSSOVirtualHost =
    { proxyPass }:
    {
      useACMEHost = "chrisdell.info";
      forceSSL = true;

      extraConfig = ''
        # Redirect the user to the login page when they are not logged in
        error_page 401 = @error401;

        # TODO: Make this configurable (Llama needs it)
        client_max_body_size        100M;
        proxy_connect_timeout       300;
        proxy_send_timeout          300;
        proxy_read_timeout          300;
        send_timeout                300;
      '';

      locations."/" = {
        inherit proxyPass;
        recommendedProxySettings = true;
        proxyWebsockets = true;

        extraConfig = ''
          auth_request /sso-auth;

          # Automatically renew SSO cookie on request
          auth_request_set $cookie $upstream_http_set_cookie;
          add_header Set-Cookie $cookie;

          # Provide "X-WEBAUTH-USER" header to the backend so we know who has logged in
          auth_request_set $username $upstream_http_x_username;
          proxy_set_header X-WEBAUTH-USER $username;

          # No cache
          add_header Cache-Control "no-cache, no-store, must-revalidate";
          add_header Pragma "no-cache";
          add_header Expires "0";
        '';
      };

      # Fake service worker (override the one provided by the app)
      locations."/sw.js" = {
        extraConfig = ''
          return 200 'self.addEventListener("install", function(e) { e.waitUntil(self.skipWaiting()); }); self.addEventListener("activate", function(e) { e.waitUntil(self.clients.claim()); });';
          add_header Content-Type application/javascript;
          add_header Cache-Control no-cache;
        '';
      };

      locations."/sso-auth" = {
        # Access /auth endpoint to query login state
        proxyPass = "http://127.0.0.1:8082/auth";

        extraConfig = ''
          # Do not allow requests from outside
          internal;
          # Do not forward the request body (nginx-sso does not care about it)
          proxy_pass_request_body off;
          proxy_set_header Content-Length "";
          # Set custom information for ACL matching: Each one is available as
          # a field for matching: X-Host = x-host, ...
          proxy_set_header X-Origin-URI $request_uri;
          proxy_set_header X-Host $http_host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        '';
      };

      # Define where to send the user to login and specify how to get back
      locations."@error401" = {
        extraConfig = ''
          # If the requested URI is an asset, redirect to root instead
          set $redirect_uri $scheme://$http_host$request_uri;
          if ($request_uri ~* "\.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$") {
            set $redirect_uri $scheme://$http_host/;
          }
          return 302 https://nginx-sso.home.chrisdell.info/login?go=$redirect_uri;
        '';
      };
    };
in
mkSSOVirtualHost
