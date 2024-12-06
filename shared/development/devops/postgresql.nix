{ pkgs, customConfig, ... }: let
    PGHOST = "localhost";
    PGPORT = 5432;
    PGDATA = /var/lib/postgresql_17/data;
in
{

  environment.systemPackages = [
    pkgs.postgresql_17
    pkgs.usql
  ];


  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_17;
    enableTCPIP = true;
    port = PGPORT;
  };

  environment.variables = {
    inherit PGHOST;
    PGPORT = toString PGPORT;
    PGDATA = toString PGDATA;

    # 히스토리 설정
    USQL_HISTORY_FILE = "$HOME/.usql_history";
  };
}
