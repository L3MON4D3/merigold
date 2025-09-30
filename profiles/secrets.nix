{ config, lib, pkgs, machine, data, ... }:

with lib; {
  options.l3mon.credentials = {
    host_key = mkOption {
      type = types.attrs;
      default = rec {
        name = "host_key";
        file = "/sys/firmware/qemu_fw_cfg/by_name/opt/io.systemd.credentials/${name}/raw";
      };
    };
    host_pubkey = mkOption {
      type = types.attrs;
      default = rec {
        name = "host_pubkey";
        file = "/sys/firmware/qemu_fw_cfg/by_name/opt/io.systemd.credentials/${name}/raw";
      };
    };
    pds_env = mkOption {
      type = types.attrs;
      default = rec {
        name = "pds_env";
        file = "/sys/firmware/qemu_fw_cfg/by_name/opt/io.systemd.credentials/${name}/raw";
      };
    };
    smtp_password = mkOption {
      type = types.attrs;
      default = rec {
        name = "smtp_password";
        file = "/sys/firmware/qemu_fw_cfg/by_name/opt/io.systemd.credentials/${name}/raw";
      };
    };
  };
}
