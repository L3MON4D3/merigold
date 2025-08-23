{
  description = "nixos-config for externally facing VM.";

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
      merigold_test = pkgs.writeShellApplication (let
        runner = nixosConfigurations.merigold.config.microvm.declaredRunner;
      in {
        name = "setup-run-merigold-test";
        runtimeInputs = with pkgs; [ coreutils ];
        text = ''
          if [[ $EUID -ne 0 ]]; then
            printf "vm-setup needs root to add network-interfaces. Aborting."
            exit 1
          fi
          ${runner}/bin/macvtap-up
          ${runner}/bin/microvm-run
        '';
      });
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
              address = "192.168.178.31/24";
              mac = "02:b6:c0:23:7f:08";
              host_if = "enp34s0";
              host_macvtapname = "macvtap-mgtest";
              gateway = "192.168.178.1";
            };
          };
        }
      ];
    };
  });
}
