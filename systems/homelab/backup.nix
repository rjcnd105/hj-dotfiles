{
  config,
  pkgs,
  ...
}:
let
  dumpDir = "/var/backup/deopjib";
in
{
  sops.secrets = {
    BACKUP_R2_ACCESS_KEY_ID.mode = "0400";
    BACKUP_R2_SECRET_ACCESS_KEY.mode = "0400";
    # 계정 ID가 포함된 R2 엔드포인트 URL — 공개 레포에 남기지 않으려 sops로 관리.
    BACKUP_RESTIC_REPOSITORY.mode = "0400";
    BACKUP_RESTIC_PASSWORD.mode = "0400";
  };

  # restic의 S3 백엔드는 AWS_* 환경변수를 요구한다. 값 합성은 템플릿에서만.
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
    # 백업 직전 컨테이너 PG 논리 덤프. platform-v2 Phase 3 이관 후에는
    # 호스트 PostgreSQL 대상으로 교체한다 (docs/plans/platform-v2.md).
    backupPrepareCommand = ''
      set -euo pipefail
      ${pkgs.podman}/bin/podman exec deopjib-dev-db \
        pg_dump -U deopjib --clean --if-exists deopjib \
        | ${pkgs.zstd}/bin/zstd -q -f -o ${dumpDir}/deopjib.sql.zst
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

  # Persistent 타이머가 부팅 직후 발화할 수 있으므로 secrets 렌더 이후로 순서 고정.
  systemd.services.restic-backups-homelab = {
    requires = [ "sops-install-secrets.service" ];
    after = [
      "sops-install-secrets.service"
      "network-online.target"
    ];
    wants = [ "network-online.target" ];
  };
}
