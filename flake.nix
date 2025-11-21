{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
  };

  outputs =
    {
      self,
      nixpkgs,
    }@attrs:
    {
      nixosConfigurations.NixOS-Router =
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
            ./containers.nix
            ./configuration.nix
            ./hardware-configuration.nix
            ./http.nix
            ./rollback.nix

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
