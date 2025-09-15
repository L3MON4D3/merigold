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
    # needs impure eval, but good in this case because ips and macs are defined
    # in the os-config, and I'd like this to be DRY.
    os_data = builtins.fromJSON (builtins.readFile /etc/nixos-data);
    lan = os_data.network.lan;
    mgconf = {
      hostname = "${vmname}";
      address = "${lan.peers.merigold-test.address}/24";
      mac = "${lan.peers.merigold-test.mac_address}";
      host_if = "${lan.peers.carmine.phys_interface}";
      host_macvtapname = "macvtap-mgtest";
      gateway_ip = "${lan.gateway_peer.address}";
      gateway_mac = "${lan.gateway_peer.mac}";
      localnet_allowlist = [
        lan.peers.carmine
      ];
      pubkey = os_data.pubkey; # allowed ssh-pubkey
      guest_keyfile = "${vm_runtimedir}/secrets/ed25519_key";
      guest_pubkeyfile = "${vm_runtimedir}/secrets/ed25519_key.pub";
      share_store = true;
      password = ""; # set to null on production server!!
      systemPackages = with pkgs; [ dig arp-scan neovim ]; # remove for production.
      img_path = "${vm_runtimedir}/var.img";
      control_socket = "${vm_runtimedir}/control.socket";
    };
    vm_nftable = mgconf: pkgs.writeText "vm-nftable" (''
      define allowed_macs = {${mgconf.gateway_mac}, ${pkgs.lib.strings.concatMapStrings (host: "${host.mac},") mgconf.localnet_allowlist}}
      define allowed_ips = {${pkgs.lib.strings.concatMapStrings (host: "${host.address},") mgconf.localnet_allowlist}}
      # hardcode this for now.
      # verify that this matches `sysctl net.ipv4.ip_local_port_range` for all allowed hosts!!!
      define dynamic_ports = 32768-60999
    '' + (builtins.replaceStrings ["DEVICENAME_PLACEHOLDER"] [mgconf.host_macvtapname] (builtins.readFile ./vm.nftables)));
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
          nft -f ${vm_nftable mgconf}
          sudo -u microvm ${runner}/bin/microvm-run
          nft delete table netdev ${mgconf.host_macvtapname}
        '';
      });
      test-ruleset = vm_nftable mgconf;
    };
    nixosModules = {
      merigold = import ./configuration.nix;
    };
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
    lib.mkRuleset = vm_nftable;
  });
}
