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
    secretdir = "/home/simon/projects/vm-test/secrets";
    vmname = "merigold-test";
    vm_runtimedir = "/run/${vmname}";
    mgconf = {
      hostname = "${vmname}";
      address = "192.168.178.31/24";
      mac = "02:b6:c0:23:7f:08";
      host_if = "enp34s0";
      host_macvtapname = "macvtap-mgtest";
      gateway_ip = "192.168.178.1";
      gateway_mac = "0c:72:74:fc:b9:de";
      localnet_allowlist = [
        # {ip = "192.168.178.20"; mac = "02:b5:0d:d2:90:a5";}
        {ip = "192.168.178.21"; mac = "02:44:3a:85:35:ae";}
      ];
      pubkey = import ./pubkey.nix; # allowed ssh-pubkey
      guest_keyfile = "${vm_runtimedir}/secrets/ed25519_key";
      guest_pubkeyfile = "${vm_runtimedir}/secrets/ed25519_key.pub";
      share_store = true;
      password = ""; # set to null on production server!!
      systemPackages = with pkgs; [dig arp-scan];
      img_path = "${vm_runtimedir}/var.img";
      control_socket = "${vm_runtimedir}/control.socket";
    };
    vm_nftable = pkgs.writeText "vm-nftable" (''
      define allowed_macs = {${pkgs.lib.strings.concatMapStrings (host: "${host.mac},") mgconf.localnet_allowlist}}
      define allowed_ips = {${pkgs.lib.strings.concatMapStrings (host: "${host.ip},") mgconf.localnet_allowlist}}
      # hardcode this for now.
      # verify that this matches `sysctl net.ipv4.ip_local_port_range` for all allowed hosts!!!
      define dynamic_ports = 32768-60999
      define tablename = ${mgconf.host_macvtapname}
    '' + builtins.readFile ./vm.nftables);
  in rec {
    packages = {
      default = packages.merigold_test;
      merigold_test = pkgs.writeShellApplication (let
        runner = nixosConfigurations.merigold.config.microvm.declaredRunner;
      in {
        name = "setup-run-merigold-test";
        runtimeInputs = with pkgs; [ coreutils nftables ];
        text = ''
          if [[ $EUID -ne 0 ]]; then
            printf "vm-setup needs root to add network-interfaces. Aborting."
            exit 1
          fi

          mkdir -p ${vm_runtimedir}/secrets
          cp ${secretdir}/* ${vm_runtimedir}/secrets
          chown microvm:kvm ${vm_runtimedir} -R

          ${runner}/bin/macvtap-up
          nft -f ${vm_nftable}
          sudo -u microvm ${runner}/bin/microvm-run
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
            mgconf = mgconf;
          };
        }
      ];
    };
  });
}
