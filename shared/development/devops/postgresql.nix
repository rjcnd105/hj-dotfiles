{
  config,
  pkgs,
  inputs,
  ...
}:
let
  PGHOST = "localhost";
  PGPORT = 5432;
  PGDATA = "/var/lib/postgresql/${config.services.postgresql.package.psqlSchema}";
in
{

  environment.systemPackages = [
    pkgs.postgresql_17
    pkgs.usql
    # pkgs.libyaml
  ];

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_17;
    enableTCPIP = true;
    port = PGPORT;
    dataDir = PGDATA;

    authentication = ''
      host all all all scram-sha-256
    '';
  };

  environment.variables = {
    inherit PGHOST;
    PGPORT = toString PGPORT;
    PGDATA = toString PGDATA;

    # 히스토리 설정
    USQL_HISTORY_FILE = "$HOME/.usql_history";
  };
}
