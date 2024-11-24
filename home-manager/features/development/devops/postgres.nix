{ config, pkgs, ... }:
{
  # PostgreSQL 서비스 활성화
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_17;  # 버전 선택

    # 데이터베이스 디렉토리 위치 설정 (기본값)
    dataDir = "${config.home.homeDirectory}/.local/share/postgresql";

    # PostgreSQL 설정
    settings = {
      listen_addresses = "localhost";
      port = 5432;
    };

    initdbArgs = [
      "--encoding=UTF8"
    ];
  };

  # PostgreSQL 관련 도구들 설치
  home.packages = with pkgs; [
    # CLI 도구
    postgresql_17   # psql 등 기본 도구들
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

  program.zsh = {
    initExtra = ''
      function local_psql() {
         usql "postgres://$PGHOST:$PGPORT/$1"
      }
    '';
  };
}
