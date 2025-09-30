{ config, lib, pkgs, machine, data, mgconf, ... }:

{
  services.pds = {
    enable = true;
    pdsadmin.enable = true;
    settings = {
      PDS_HOSTNAME = "pds.l3mon4.de";
      PDS_PORT = mgconf.ports.pds;
      PDS_HOST = "127.0.0.1";
      PDS_EMAIL_FROM_ADDRESS = "simon@l3mon4.de";
      PDS_EMAIL_SMTP_URL = "smtp:///?sendmail=true";
    };
    environmentFiles = [
      "${config.l3mon.credentials.pds_env.file}"
    ];
  };
  users.users.pds.extraGroups = [ "msmtp-user" ];

  services.caddy = {
    enable = true;
    extraConfig =
    # caddy
    ''
      pds.l3mon4.de pds.${mgconf.hostname}.internal {
        log {
          level INFO
        }
        reverse_proxy http://127.0.0.1:${toString mgconf.ports.pds}
      }
    '';
  };
}

