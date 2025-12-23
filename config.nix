let
  BASE_PATH = "/home/cjdell/nixos-config/secrets";
in
{
  AWS_ACCESS_KEY_SECRET_FILE  = "${BASE_PATH}/aws-access-key-secret.txt";
  HTTP_PASSWORD_FILE          = "${BASE_PATH}/http-password.txt";
  WIREGUARD_KEY_FILE          = "${BASE_PATH}/wireguard.key";
  ZEN_PASSWORD_FILE           = "${BASE_PATH}/zen-password.txt";
  HOME_ASSISTANT_TOKEN_FILE   = "${BASE_PATH}/home-assistant-token.txt";
}
