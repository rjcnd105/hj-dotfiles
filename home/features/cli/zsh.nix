{ pkgs, ... }:
{
  programs.zsh = {
    enable = true;

    # 기본 설정
    enableAutosuggestions = true; # 명령어 자동 제안
    enableCompletion = true; # 향상된 자동 완성
    autocd = true; # 디렉토리 이름만으로 cd 가능
    defaultKeymap = "emacs"; # 키맵 설정

    # 히스토리 설정
    history = {
      expireDuplicatesFirst = true; # 중복된 히스토리는 우선 삭제
      extended = true; # 확장 히스토리 형식 사용
      ignoreDups = true; # 중복된 명령어 무시
      save = 10000; # 저장할 히스토리 개수
      share = true; # 여러 세션간 히스토리 공유
      size = 10000; # 메모리상 히스토리 크기
    };

    # oh-my-zsh 설정
    oh-my-zsh = {
      enable = true;
      theme = "robbyrussell"; # 깔끔하고 정보가 충분한 테마
      plugins = [
        "git" # git 관련 단축어 및 정보 표시
        "docker" # docker 명령어 자동완성
        "fzf" # fuzzy finder 통합
        "z" # 디렉토리 빠른 이동
        "history-substring-search" # 히스토리 부분 문자열 검색
        "colored-man-pages" # man 페이지 색상 강조
        "command-not-found" # 명령어 찾을 수 없을 때 제안
      ];
    };

    # 추가 플러그인 (oh-my-zsh 외부)
    plugins = [
      {
        name = "zsh-syntax-highlighting";
        src = pkgs.fetchFromGitHub {
          owner = "zsh-users";
          repo = "zsh-syntax-highlighting";
          rev = "0.7.1";
          sha256 = "gJZjxRz3gmxFlf2fGzqBB5R4gL/Ci15+Ivw3zDRm6Vg=";
        };
      }
    ];

    # 환경 변수 설정
    sessionVariables = {
      EDITOR = "zed";
      VISUAL = "zed";
      LANG = "ko_KR.UTF-8";
      LC_ALL = "ko_KR.UTF-8";
    };

    # 별칭 설정
    shellAliases = {
      # 기본 명령어 개선
      ls = "eza --icons --git"; # eza로 ls 대체
      l = "eza -lah --git"; # 자세한 목록
      cat = "bat --style=plain"; # bat으로 cat 대체
      top = "btop"; # btop으로 top 대체

      # 개발 도구
      d = "docker";
      dc = "docker-compose";

      # 시스템 관리
      update = "sudo nixos-rebuild switch";
      hm = "home-manager switch";
    };

    # 추가 zsh 설정
    initExtra = ''
      # fzf 키바인딩 설정
      bindkey '^P' up-line-or-search
      bindkey '^N' down-line-or-search
      bindkey '^R' fzf-history-widget

      # 디렉토리 스택 설정
      setopt AUTO_PUSHD                  # cd 시 자동으로 디렉토리 스택에 추가
      setopt PUSHD_IGNORE_DUPS          # 중복된 디렉토리는 추가하지 않음
      setopt PUSHD_MINUS                # +/- 디렉토리 스택 탐색 방향 변경

      # 자동 완성 개선
      zstyle ':completion:*' menu select
      zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

      # nix-direnv 후크 추가
      eval "$(direnv hook zsh)"

      # 필요한 경우 특정 경로 추가
      path+=("$HOME/.local/bin")
      export PATH
    '';

    # 로케일 설정
    localVariables = {
      LANG = "ko_KR.UTF-8";
      LC_ALL = "ko_KR.UTF-8";
    };
  };
}
