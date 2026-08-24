{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";

    microvm = {
      url = "github:microvm-nix/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    frigate-whisper = {
      # TEMPORARY: local path input (same as nixos-utils). A relative path
      # (path:../Projects/frigate-whisper) fails in pure evaluation mode, so an
      # absolute path is used. Restore `url = "github:cjdell/frigate-whisper";`
      # and run `nix flake lock` to switch back to the hosted copy.
      url = "path:/home/cjdell/Projects/frigate-whisper";
    };

    nixos-utils = {
      # TEMPORARY: use the local clone instead of the github source. A relative
      # path (path:../Projects/nixos-utils) fails in pure evaluation mode, so an
      # absolute path is used. Restore `url = "github:cjdell/nixos-utils";` and run
      # `nix flake lock` to switch back to the hosted copy.
      url = "path:/home/cjdell/Projects/nixos-utils";
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
      microvm,
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
                microvm.nixosModules.host
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
