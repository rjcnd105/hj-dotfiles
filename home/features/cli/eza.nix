{
  programs.eza = {
    enable = true;

    extraOptions = [
      "--group-directories-first"  # 디렉토리 먼저 표시
      "--header"                   # 헤더 표시
    ];
  };

  # 추가 alias 설정
   programs.zsh.shellAliases = {
     # 기본

     ls="eza --icons=always --git";
     ll = "eza -l --icons --git";         # 긴 형식 + 아이콘 + git 상태
     la = "eza -la --icons --git";        # 숨김 파일 포함
     lt = "eza --tree --icons -L 2";      # 트리 보기 (2단계 깊이)
     lt2 = "eza --tree --icons -L 2";      # 트리 보기 (2단계 깊이)
     lt3 = "eza --tree --icons -L 3";
     llt = "eza -l --tree --icons -L 2";  # 트리 보기 (자세히)

     # 정렬
     lg = "eza -l --icons --git-ignore";  # git-ignore 파일 제외
     lm = "eza -l --icons --sort=modified"; # 수정 시간순
     lsize = "eza -l --icons --sort=size";  # 크기순

     # 특수 용도
     ldot = "eza -ld --icons .*";         # 숨김 파일만
     ldir = "eza -lD --icons";            # 디렉토리만
     lfile = "eza -lf --icons";           # 파일만
  }
}
