{ config, lib, pkgs, machine, mgconf, ... }:

let
  smtp_pass_path = "/var/secrets/smtp_password";
in {
  users = {
    users.msmtp-user = {
      group = "msmtp-user";
      isSystemUser = true;
      uid = mgconf.ids.msmtp-user;
    };
    groups.msmtp-user.gid = mgconf.ids.msmtp-user;
  };

  system.activationScripts.smtp_passwordfile = {
    deps = [];
    text = ''
      mkdir -p /var/secrets/
      install -m 440 -o msmtp-user -g msmtp-user ${config.l3mon.credentials.smtp_password.file} "${smtp_pass_path}"
    '';
  };

  programs.msmtp = {
    enable = true;
    accounts.default = {
      auth = true;
      tls = true;
      host = "smtp.mailbox.org";
      from = "simon@l3mon4.de";
      user = "simon@l3mon4.de";
      passwordeval = ''${pkgs.coreutils}/bin/cat "${smtp_pass_path}"'';
    };
  };
}
