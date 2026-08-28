{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    concatLines
    filterAttrs
    mkIf
    mkOption
    types
    ;

  enabledApps = filterAttrs (_: app: app.enable) config.homelab.apps;
  pgApps = filterAttrs (
    _: app: app.contract.schemaVersion == 2 && app.contract.needs.postgres
  ) enabledApps;
  pgAppList = builtins.attrValues pgApps;

  # app-containers.nix와 같은 규약: role = db = <name>_<channel> (하이픈 → 언더스코어).
  pgNameFor = app: lib.replaceStrings [ "-" ] [ "_" ] "${app.contract.name}_${app.contract.channel}";
  subnetFor = app: "10.90.${toString app.host.subnetId}.0/24";
  bridgeFor = app: "br-${app.contract.name}-${app.contract.channel}";
in
{
  options.homelab.postgres.enable = mkOption {
    type = types.bool;
    default = pgApps != { };
    defaultText = lib.literalMD "`true` when any admitted v2 app sets `needs.postgres`";
    description = ''
      Shared native PostgreSQL for v2 apps. Auto-enabled by admitted contracts;
      set explicitly to provision the server ahead of an app migration window.
    '';
  };

  config = mkIf config.homelab.postgres.enable {
    services.postgresql = {
      enable = true;
      # 컨테이너 PG(postgres:18)와 동일 메이저 — pg_dump 이관 호환.
      package = pkgs.postgresql_18;
      # listen은 '*'이지만 방화벽이 앱 브리지 인터페이스에만 5432를 연다.
      enableTCPIP = true;
      ensureDatabases = map pgNameFor pgAppList;
      ensureUsers = map (app: {
        name = pgNameFor app;
        ensureDBOwnership = true;
      }) pgAppList;
      authentication = concatLines (
        map (app: "host ${pgNameFor app} ${pgNameFor app} ${subnetFor app} scram-sha-256") pgAppList
      );
    };

    networking.firewall.interfaces = builtins.listToAttrs (
      map (app: {
        name = bridgeFor app;
        value.allowedTCPPorts = [ 5432 ];
      }) pgAppList
    );

    # role 비밀번호를 sops에서 동기화한다. LoadCredential이 root 전용 secret을
    # postgres 사용자에게만 노출하고, SQL은 stdin으로 전달해 argv에 남지 않는다.
    systemd.services.homelab-postgres-credentials = mkIf (pgAppList != [ ]) {
      description = "Sync shared PostgreSQL role passwords from sops";
      requires = [
        "postgresql.service"
        "sops-install-secrets.service"
      ];
      # ensureUsers(role 생성)는 postgresql-setup.service가 수행한다 — 그 전에
      # ALTER ROLE이 실행되면 role이 없다 (Phase 3 컷오버에서 실측).
      after = [
        "postgresql.service"
        "postgresql-setup.service"
        "sops-install-secrets.service"
      ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = "postgres";
        LoadCredential = map (
          app:
          "${app.host.postgresPasswordSecret}:${config.sops.secrets.${app.host.postgresPasswordSecret}.path}"
        ) pgAppList;
      };
      script = concatLines (
        map (app: ''
          PG_APP_PASSWORD=$(cat "$CREDENTIALS_DIRECTORY/${app.host.postgresPasswordSecret}") \
            ${config.services.postgresql.package}/bin/psql \
            --dbname postgres --no-psqlrc --quiet \
            --set ON_ERROR_STOP=1 --file - <<'SQL'
          \getenv pw PG_APP_PASSWORD
          ALTER ROLE ${pgNameFor app} WITH PASSWORD :'pw';
          SQL
        '') pgAppList
      );
    };
  };
}
