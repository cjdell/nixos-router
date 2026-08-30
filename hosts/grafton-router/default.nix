{
  nixos-utils,
  sops-nix,
  ...
}:

[
  ../../utils/oci.nix

  nixos-utils.nixosModules.rollback
  nixos-utils.nixosModules.containers
  nixos-utils.nixosModules.notifications
  nixos-utils.nixosModules.health

  sops-nix.nixosModules.sops

  ./networking
  ./services
  ./virtual-machines

  ./containers.nix
  ./configuration.nix
  ./hardware-configuration.nix
  ./http.nix
  ./sops.nix
]
