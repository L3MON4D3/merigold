{
  description = "NixOS in MicroVMs";

  nixConfig = {
    extra-substituters = [ "https://microvm.cachix.org" ];
    extra-trusted-public-keys = [ "microvm.cachix.org-1:oXnBc6hRE3eX5rSYdRyMYXnfzcCxC7yKPTbZXALsqys=" ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    microvm = {
      url = "github:microvm-nix/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, flake-utils, microvm, ... }@inputs : flake-utils.lib.eachDefaultSystem(system: let
    pkgs = import inputs.nixpkgs { inherit system; };
  in rec {
    packages = {
      default = packages.merigold_test;
      merigold_test = nixosConfigurations.merigold.config.microvm.declaredRunner;
    };
    nixosModules.merigold = import ./configuration.nix;
    nixosConfigurations.merigold = inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        microvm.nixosModules.microvm
        nixosModules.merigold
        {
          _module.args = {
            inherit system self;
            mgconf = {
              hostname = "merigold-test";
            };
          };
        }
      ];
    };
  });
}
