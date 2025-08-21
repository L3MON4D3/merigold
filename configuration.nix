{ config, lib, pkgs, machine, mgconf, ... }:

{
  networking.hostName = mgconf.hostname;
  users.users.root.password = "";
  
  nix.settings.allowed-users = ["root"];
  security.sudo.enable = false;

  environment.defaultPackages = pkgs.lib.mkForce [];

  fileSystems."/var".options = ["noexec"];

  microvm = {
    volumes = [ {
      mountPoint = "/var";
      image = "var.img";
      # 1_000_000 MB
      # 1TB
      size = 256;
    } ];
    shares = [ {
      # use proto = "virtiofs" for MicroVMs that are started by systemd
      proto = "9p";
      tag = "ro-store";
      # a host's /nix/store will be picked up so that no
      # squashfs/erofs will be built for it.
      source = "/nix/store";
      mountPoint = "/nix/.ro-store";
    } ];

    # "qemu" has 9p built-in!
    hypervisor = "qemu";
    socket = "control.socket";
  };
}
