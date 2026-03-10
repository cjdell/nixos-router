let
  CORS = ''
    add_header 'Access-Control-Allow-Origin' * always;

    if ($request_method = 'OPTIONS') {
      add_header 'Access-Control-Allow-Origin' '*';
      add_header 'Access-Control-Allow-Credentials' 'true';
      add_header 'Access-Control-Allow-Methods' '*';
      add_header 'Access-Control-Allow-Headers' '*';
      add_header 'Access-Control-Max-Age' 86400;
      add_header 'Content-Type' 'text/plain charset=UTF-8';
      add_header 'Content-Length' 0;
      return 204; break;
    }
  '';
in
{
  services.nginx.virtualHosts = {
    "firmware.rustagon.chrisdell.info" = {
      useACMEHost = "chrisdell.info";
      addSSL = true;

      locations."/" = {
        root = "/srv/rustagon/firmware";
        extraConfig = CORS;
      };
    };

    "apps.rustagon.chrisdell.info" = {
      useACMEHost = "chrisdell.info";
      addSSL = true;

      locations."/" = {
        root = "/srv/rustagon/apps";
        extraConfig = CORS;
      };
    };

    "demo.rustagon.chrisdell.info" = {
      useACMEHost = "chrisdell.info";
      addSSL = true;

      locations."/" = {
        root = "/srv/rustagon/demo";
        extraConfig = ''
          # CORS headers
          ${CORS}

          # Handle extensionless paths by rewriting them to /index.html internally
          # This matches any path that doesn't contain a dot (i.e., no file extension)
          location ~ ^[^.]*$ {
            rewrite ^ /index.html break;
          }
          location ~ ^/emulator/(.*).wsm$ {
            rewrite ^ /index.html break;
          }

          # For everything else (with extensions), serve normally
          try_files $uri $uri/ =404;
        '';
      };
    };
  };
}
