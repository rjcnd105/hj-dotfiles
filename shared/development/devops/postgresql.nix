{... }: let
    PGHOST = "localhost";
    PGPORT = "5432";
    PGDATA = "$HOME/.local/share/postgresql";
in
{

  environment.systemPackages = [
    pkgs.postgresql_17
    pkgs.usql
  ];


  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_17;
    dataDir = PGDATA;
  };

  environment.variables = {
    inherit PGHOST PGPORT PGDATA;

    # 히스토리 설정
    USQL_HISTORY_FILE = "$HOME/.usql_history";
  };

  users.users.${user}.programs.nushell.extraConfig = ''
    def local_psql [db: string] {
      usql $"postgres://${PGHOST}:${PGPORT}/($db)"
    }
  '';
}
