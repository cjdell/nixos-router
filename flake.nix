{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

    nixos-utils = {
      url = "github:cjdell/nixos-utils";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixos-utils,
      sops-nix,
    }@attrs:
    {
      nixosConfigurations.router =
        let
          system = "x86_64-linux";
        in
        nixpkgs.lib.nixosSystem {
          inherit system;
          pkgs = import nixpkgs {
            inherit system;
            config = {
              allowUnfree = true;
            };
          };
          modules = [
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

            # This fixes nixpkgs (for e.g. "nix shell") to match the system nixpkgs
            {
              nix.registry.nixpkgs.flake = nixpkgs;
            }
          ];
        };
    };
}
