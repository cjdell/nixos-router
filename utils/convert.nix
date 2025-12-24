{ lib }:

let
  escapeValue =
    value:
    if lib.isString value then
      # Escape double quotes and backslashes, wrap in double quotes
      "\"${lib.replaceStrings [ "\\" "\"" ] [ "\\\\" "\\\"" ] value}\""
    else
      # For numbers, booleans, etc., just convert to string
      toString value;

  convertToEnvFile =
    attrs:
    (builtins.concatStringsSep "\n" (
      lib.mapAttrsToList (name: value: "${name}=${escapeValue value}") attrs
    ));
in
{
  inherit convertToEnvFile;
}
