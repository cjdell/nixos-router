{
  nixos-utils,
  sops-nix,
  headplane,
  ...
}:

[
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

  # provides `services.headplane.*` NixOS options.
  headplane.nixosModules.headplane

  {
    # provides `pkgs.headplane`
    nixpkgs.overlays = [ headplane.overlays.default ];
  }
]
