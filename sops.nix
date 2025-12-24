{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [ sops ];

  environment.variables = {
    SOPS_AGE_KEY_FILE = config.sops.age.keyFile;
  };

  environment.sessionVariables = {
    SOPS_AGE_KEY_FILE = config.sops.age.keyFile;
  };

  sops = {
    age.keyFile = "/var/lib/sops-nix/key.txt";
    defaultSopsFile = ./secrets/secrets.yaml;
    secrets = {
      aws_access_key_secret = { };
      pppoe_password = { };
      wireguard_key = { };
      home_assistant_header = { };
      nginx_sso_client_secret = { };
    };
  };
}
