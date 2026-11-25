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

  conventions = import ./app-conventions.nix { inherit lib; };
  inherit (conventions)
    appSubnetFor
    bridgeInterfaceFor
    sharedPostgresNameFor
    usesSharedPostgres
    ;

  enabledApps = filterAttrs (_: app: app.enable) config.homelab.apps;
  pgApps = filterAttrs (_: usesSharedPostgres) enabledApps;
  pgAppList = builtins.attrValues pgApps;
in
{
  options.homelab.postgres.enable = mkOption {
    type = types.bool;
    default = pgApps != { };
    defaultText = lib.literalMD "`true` when any admitted app sets `needs.postgres`";
    description = ''
      Shared native PostgreSQL for admitted apps. Auto-enabled by admitted contracts;
      set explicitly to provision the server ahead of an app migration window.
    '';
  };

  config = mkIf config.homelab.postgres.enable {
    services.postgresql = {
      enable = true;
      package = pkgs.postgresql_18;
      enableTCPIP = true;
      ensureDatabases = map sharedPostgresNameFor pgAppList;
      ensureUsers = map (app: {
        name = sharedPostgresNameFor app;
        ensureDBOwnership = true;
      }) pgAppList;
      authentication = concatLines (
        map (
          app:
          "host ${sharedPostgresNameFor app} ${sharedPostgresNameFor app} ${appSubnetFor app} scram-sha-256"
        ) pgAppList
      );
      # 모듈 기본값은 hba_file을 store 경로로 둔다. hba_file은 재시작해야 바뀌므로 hba만
      # 바뀌어도 postgres와 의존 앱이 모두 재시작된다. 고정 경로로 두고 내용이 바뀌면 reload만
      # 한다.
      settings.hba_file = lib.mkForce "/etc/postgresql/pg_hba.conf";
    };

    # 모듈 기본값은 target이 postgresql-setup을 requires하고 postgres는 target에 partOf다. 앱을
    # 들이면 setup이 바뀌어 switch가 setup을 멈추고, 그 stop이 target을 거쳐 postgres와 의존
    # 앱까지 내린다. wants면 setup만 다시 돈다. target은 wants에도 After=를 자동으로 붙인다.
    systemd.targets.postgresql = {
      requires = lib.mkForce [ "postgresql.service" ];
      wants = [ "postgresql-setup.service" ];
    };

    environment.etc."postgresql/pg_hba.conf".text = config.services.postgresql.authentication;
    systemd.services.postgresql = {
      reloadTriggers = [ config.environment.etc."postgresql/pg_hba.conf".source ];
      # 기본값인 stop 후 start는 그 사이 의존 unit의 start job이 옛 unit 정의로 postgres를
      # 다시 띄우면 start가 no-op이 되어 옛 설정에 머문다(2026-10-15 실측). restart는
      # daemon-reload 뒤에 무조건 돈다.
      stopIfChanged = false;
    };

    networking.firewall.interfaces = builtins.listToAttrs (
      map (app: {
        name = bridgeInterfaceFor app;
        value.allowedTCPPorts = [ 5432 ];
      }) pgAppList
    );

    sops.secrets = mkIf (pgAppList != [ ]) (
      builtins.listToAttrs (
        map (app: {
          name = app.host.postgresPasswordSecret;
          value.restartUnits = [ "homelab-postgres-credentials.service" ];
        }) pgAppList
      )
    );

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
        RemainAfterExit = true;
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
          ALTER ROLE ${sharedPostgresNameFor app} WITH PASSWORD :'pw';
          SQL
        '') pgAppList
      );
    };
  };
}
