{
  config,
  lib,
  pkgs,
  ...
}:
let
  dumpDir = "/var/backup/deopjib";
  databases = lib.unique config.services.postgresql.ensureDatabases;
in
{
  assertions = [
    {
      assertion = config.services.postgresql.enable;
      message = "homelab backup requires services.postgresql.enable.";
    }
  ];

  sops.secrets = {
    BACKUP_R2_ACCESS_KEY_ID.mode = "0400";
    BACKUP_R2_SECRET_ACCESS_KEY.mode = "0400";
    BACKUP_RESTIC_REPOSITORY.mode = "0400";
    BACKUP_RESTIC_PASSWORD.mode = "0400";
  };

  sops.templates."restic-r2.env" = {
    content = ''
      AWS_ACCESS_KEY_ID=${config.sops.placeholder.BACKUP_R2_ACCESS_KEY_ID}
      AWS_SECRET_ACCESS_KEY=${config.sops.placeholder.BACKUP_R2_SECRET_ACCESS_KEY}
    '';
    mode = "0400";
    owner = "root";
  };

  systemd.tmpfiles.rules = [ "d ${dumpDir} 0700 root root - -" ];

  services.restic.backups.homelab = {
    initialize = true;
    repositoryFile = config.sops.secrets.BACKUP_RESTIC_REPOSITORY.path;
    passwordFile = config.sops.secrets.BACKUP_RESTIC_PASSWORD.path;
    environmentFile = config.sops.templates."restic-r2.env".path;
    paths = [ dumpDir ];
    backupPrepareCommand = ''
      set -euo pipefail
      for db in ${lib.escapeShellArgs databases}; do
        tmp=${dumpDir}/."$db".sql.zst.tmp.$$
        ${pkgs.util-linux}/bin/runuser -u postgres -- \
          ${config.services.postgresql.package}/bin/pg_dump --clean --if-exists "$db" \
          | ${pkgs.zstd}/bin/zstd -q -f -o "$tmp"
        mv -f "$tmp" ${dumpDir}/"$db".sql.zst
      done
    '';
    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
    ];
    timerConfig = {
      OnCalendar = "*-*-* 04:30:00";
      Persistent = true;
      RandomizedDelaySec = "15m";
    };
  };

  systemd.services.restic-backups-homelab = {
    requires = [ "sops-install-secrets.service" ];
    # requires면 postgres가 멈춰 있을 때 백업이 postgres를 띄운다. switch 중이면 옛 unit 정의로
    # 떠서 새 설정이 적용되지 않는다(2026-10-15 실측). requisite는 postgres가 떠 있거나 시작
    # 중일 때만 진행하고 멈춰 있으면 백업만 실패시킨다.
    requisite = [ "postgresql.service" ];
    after = [
      "sops-install-secrets.service"
      "postgresql.service"
      "network-online.target"
    ];
    wants = [ "network-online.target" ];
  };
}
