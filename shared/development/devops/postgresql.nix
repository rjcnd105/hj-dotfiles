{ pkgs, customConfig, ... }: let
    PGHOST = "localhost";
    PGPORT = 5432;

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

    authentication = ''
      local all all trust
      host all all 127.0.0.1/32 trust
    '';
  };

  environment.variables = {
    inherit PGHOST;
    PGPORT = toString PGPORT;

    # 히스토리 설정
    USQL_HISTORY_FILE = "$HOME/.usql_history";
  };
}
