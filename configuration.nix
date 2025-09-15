{ config, lib, pkgs, machine, mgconf, ... }:

let
  crednames = {
    root_pw_hashed = "root_pw_hashed";
    host_key = "host_key";
    host_pubkey = "host_pubkey";
  };
  credfile = credname: "/sys/firmware/qemu_fw_cfg/by_name/opt/io.systemd.credentials/${credname}/raw";
in {
  microvm = {
    volumes = [
      {
        mountPoint = "/var";
        image = "${mgconf.img_path}";
        # 1_000_000 MB
        # 1TB
        size = 256;
      }
    ];
    shares = if mgconf.share_store then [ {
      tag = "ro-store";
      source = "/nix/store";
      mountPoint = "/nix/.ro-store";
    } ] else [];

    credentialFiles = {
      ${crednames.host_key} = mgconf.guest_keyfile; 
      ${crednames.host_pubkey} = mgconf.guest_pubkeyfile; 
    };

    hypervisor = "qemu";
    socket = "${mgconf.control_socket}";

    interfaces = [
      {
        type = "macvtap";
        id = mgconf.host_macvtapname;
        mac = mgconf.mac;
        macvtap = {
          link = mgconf.host_if;
          mode = "bridge";
        };
      }
    ];
  };

  networking.hostName = mgconf.hostname;

  fileSystems."/var".options = ["noexec"];

  systemd.network.enable = true;
  systemd.network.networks."20-lan" = {
    matchConfig.Type = "ether";
    networkConfig = {
      Address = mgconf.address;
      Gateway = mgconf.gateway_ip;
      DNS = "1.1.1.1";
      DNSOverTLS = true;
      DNSSEC = true;
      IPv6AcceptRA = false;
      DHCP = false;
    };
  };

  # make sure these are available when activation scripts are executed.
  boot.initrd.availableKernelModules = ["qemu_fw_cfg"];

  services.openssh = {
    enable = true;
    ports = [22];
    settings = {
      PasswordAuthentication = false;
      AllowUsers = ["root"];
      X11Forwarding = false;
    };
    hostKeys = lib.mkForce [];
  };

  system.activationScripts.test = {
    deps = [];
    text = ''
      mkdir -p /etc/ssh/
      install -m 600 -o root ${credfile crednames.host_key} "/etc/ssh/ssh_host_ed25519_key"
      install -m 644 -o root ${credfile crednames.host_pubkey} "/etc/ssh/ssh_host_ed25519_key.pub"
    '';
  };
  users.users.root = {
    openssh.authorizedKeys.keys = [
      mgconf.pubkey
    ];
    # hashedPasswordFile = "/sys/firmware/qemu_fw_cfg/by_name/opt/io.systemd.credentials/${crednames.root_pw_hashed}/raw";
    # allow login only via sshd.
    password = mgconf.password;
  };

  system.stateVersion = lib.trivial.release;

  security.sudo.enable = false;

  environment.defaultPackages = pkgs.lib.mkForce [ ];
  nix.enable = false;

  environment.systemPackages = mgconf.systemPackages;

  services.caddy = {
    enable = true;
    extraConfig =
    # caddy
    ''
      # don't redir .well-known so caddy can do automatic ACME.
      nix-cache.l3mon4.de nix-cache.${mgconf.hostname}.internal {
        @not-well-known {
          not path /.well-known
        }
        redir @not-well-known https://l3mon4d3-nix-cache.s3.eu-central-003.backblazeb2.com{uri}
      }
      nix-tarballs.l3mon4.de nix-tarballs.${mgconf.hostname}.internal {
        @not-well-known {
          not path /.well-known
        }
        redir @not-well-known https://l3mon4d3-nix-tarballs.s3.eu-central-003.backblazeb2.com{uri}
      }
    '';
    # virtualHosts = {
      # "nix-cache.internal".extraConfig =
      # # caddy
      # ''
        # redir https://s3.eu-central-003.backblazeb2.com/l3mon4d3-nix-tarballs{uri}
      # '';
    # };
  };

  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 443 80 ];
  networking.firewall.allowedUDPPorts = lib.mkForce [];
  networking.nftables.enable = true;
}
