{ config, lib, pkgs, machine, mgconf, ... }:

let
  crednames = {
    root_pw_hashed = "root_pw_hashed";
    host_key = "host_key";
    host_pubkey = "host_pubkey";
  };
  credfile = credname: "/sys/firmware/qemu_fw_cfg/by_name/opt/io.systemd.credentials/${credname}/raw";
in {
  networking.hostName = mgconf.hostname;

  nix.settings.allowed-users = ["root"];
  security.sudo.enable = false;

  environment.defaultPackages = pkgs.lib.mkForce [];

  fileSystems."/var".options = ["noexec"];

  systemd.network.enable = true;
  systemd.network.networks."20-lan" = {
    matchConfig.Type = "ether";
    networkConfig = {
      Address = mgconf.address;
      Gateway = mgconf.gateway;
      DNS = "1.1.1.1";
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

  microvm = {
    volumes = [
      {
        mountPoint = "/var";
        image = "var.img";
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
    socket = "control.socket";

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
}
