{
  programs.eza = {
    enable = true;
    icons = "always";
    enableNushellIntegration = true;

    extraOptions = [
      "--group-directories-first"
      "--header"
      "--octal-permissions"
      "--hyperlink"
    ];
  };

  home.sessionVariables = {
    FZF_ALT_C_OPTS = "--preview 'eza --tree --color=always {} | head -200'";
  };

  home.shellAliases = rec {
    # 기본
    ls = "eza --icons --git";
    ll = "eza -l --icons --git"; # 긴 형식 + 아이콘 + git 상태
    la = "eza -la --icons --git"; # 숨김 파일 포함
    lt1 = "eza --tree --icons -L 1"; # 트리 보기 (1단계 깊이)
    lt2 = "eza --tree --icons -L 2"; # 트리 보기 (2단계 깊이)
    lt = lt2;
    lt3 = "eza --tree --icons -L 3";
    llt1 = "eza -l --tree --icons -L 1"; # 트리 보기 (자세히)
    llt2 = "eza -l --tree --icons -L 2"; # 트리 보기 (자세히)
    llt3 = "eza -l --tree --icons -L 3"; # 트리 보기 (자세히)

    # 디렉토리 트리
    tree = lt2;
    tree3 = lt3;

    # 정렬
    lg = "eza -l --icons --git-ignore"; # git-ignore 파일 제외
    lm = "eza -l --icons --sort=modified"; # 수정 시간순
    lsize = "eza -l --icons --sort=size"; # 크기순

    # 특수 용도
    ldot = "eza -ld --icons .*"; # 숨김 파일만
    ldir = "eza -lD --icons"; # 디렉토리만
    lfile = "eza -lf --icons"; # 파일만
  };
}
