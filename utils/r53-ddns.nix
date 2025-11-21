# r53-ddns.nix
{ pkgs, route53Creds }:

# Define the function that takes hostname, domain, and zone as arguments.
{ hostname, domain, zone }:
let
  serviceName = "r53-ddns-${zone}";
in
{
  systemd.timers."${serviceName}" = {
    description = "${serviceName} timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "15min";
      OnUnitActiveSec = "15min";
    };
  };

  systemd.services."${serviceName}" = {
    description = "${serviceName} service";
    serviceConfig = {
      ExecStart = "${pkgs.r53-ddns}/bin/r53-ddns -zone-id ${zone} -domain ${domain} -hostname ${hostname}";
      EnvironmentFile = route53Creds;
      DynamicUser = true;
    };
  };
}
