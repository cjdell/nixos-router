{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixos-hardware,
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
