{ pkgs, ... }:
{
  programs.zsh = {
    enable = true;

    # 기본 설정
    enableAutosuggestions = true; # 명령어 자동 제안
    enableCompletion = true; # 향상된 자동 완성
    enableSyntaxHighlighting = true;

    # 히스토리 설정
    history = {
      expireDuplicatesFirst = true; # 중복된 히스토리는 우선 삭제
      extended = true; # 확장 히스토리 형식 사용
      ignoreDups = true; # 중복된 명령어 무시
      save = 10000; # 저장할 히스토리 개수
      share = true; # 여러 세션간 히스토리 공유
      size = 10000; # 메모리상 히스토리 크기
    };


    # 환경 변수 설정
    sessionVariables = {
      EDITOR = "zed";
      VISUAL = "zed";
      LANG = "ko_KR.UTF-8";
      LC_ALL = "ko_KR.UTF-8";
    };

    # 별칭 설정
    shellAliases = {
      update = "sudo nixos-rebuild switch";
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
