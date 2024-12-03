{ config, pkgs, ... }:
{

  # PostgreSQL 관련 도구들 설치
  home.packages = with pkgs; [
    # CLI 도구
    postgresql_17 # psql 등 기본 도구들
    usql
  ];

  # 환경 변수 설정
  home.sessionVariables = {
    PGHOST = "localhost";
    PGPORT = "5432";
    PGDATA = "${config.home.homeDirectory}/.local/share/postgresql";

    # 히스토리 설정
    USQL_HISTORY_FILE = "$HOME/.usql_history";
  };

  # programs.fish = {
  #  functions = {
  #    local_psql = ''
  #      function local_psql
  #        usql "postgres://$PGHOST:$PGPORT/$argv[1]"
  #      end
  #    '';
  #  };
  # };
}
