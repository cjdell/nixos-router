{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    nixos-utils = {
      url = "github:cjdell/nixos-utils";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    headplane = {
      url = "github:tale/headplane/v0.6.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      ...
    }@inputs:
    {
      nixosConfigurations =
        let
          system = "x86_64-linux";
          hosts = builtins.filter (x: x != null) (
            nixpkgs.lib.mapAttrsToList (name: value: if (value == "directory") then name else null) (
              builtins.readDir ./hosts
            )
          );
        in
        builtins.listToAttrs (
          (map (host: {
            name = host;
            value = nixpkgs.lib.nixosSystem {
              inherit system;
              pkgs = import nixpkgs {
                inherit system;
                config = {
                  allowUnfree = true;
                };
              };
              modules = [
                # This fixes nixpkgs (for e.g. "nix shell") to match the system nixpkgs
                {
                  nix.registry.nixpkgs.flake = nixpkgs;
                  networking.hostName = host;
                }
              ]
              ++ (import (./hosts + "/${host}") inputs);
              specialArgs = {
                inherit inputs;
              };
            };
          }))
            hosts
        );
    };
}
