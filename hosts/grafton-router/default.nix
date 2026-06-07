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

  sops-nix.nixosModules.sops

  ./containers.nix
  ./configuration.nix
  ./hardware-configuration.nix
  ./http.nix
  ./sops.nix

  ./networking
  ./services
]
