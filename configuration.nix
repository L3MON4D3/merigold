{ config, lib, pkgs, machine, mgconf, ... }:

{
  networking.hostName = mgconf.hostname;
  users.users.root.password = "";
  
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

  microvm = {
    volumes = [ {
      mountPoint = "/var";
      image = "var.img";
      # 1_000_000 MB
      # 1TB
      size = 256;
    } ];

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
