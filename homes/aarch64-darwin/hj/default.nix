{
  # Snowfall Lib provides a customized `lib` instance with access to your flake's library
  # as well as the libraries available from your flake's inputs.
  lib,
  # An instance of `pkgs` with your overlays and packages applied is also available.
  pkgs,
  # You also have access to your flake's inputs.
  inputs,

  # Additional metadata is provided by Snowfall Lib.
  namespace, # The namespace used for your flake, defaulting to "internal" if not set.
  home, # The home architecture for this host (eg. `x86_64-linux`).
  target, # The Snowfall Lib target for this home (eg. `x86_64-home`).
  format, # A normalized name for the home target (eg. `home`).
  virtual, # A boolean to determine whether this home is a virtual target using nixos-generators.
  host, # The host name for this home.

  # All other arguments come from the home home.
  config,
  ...
}:
{

  imports = [
    ../../../shared/cli
    ../../../shared/development
    ./ssh-conf.nix
  ];

  home.sessionVariables = {
    EDITOR = "zed";
  };

  home.packages = with pkgs; [
    direnv # folder 기반 env 설정
    ripgrep # grep 대체 (rg)
    sd # sed 대체 (더 직관적)
    procs # ps 대체
    hyperfine # 벤치마크 도구
    termshark # Wireshark의 TUI 버전
    bandwhich # 실시간 네트워크 사용량을 프로세스별로 표시
    mtr-gui # traceroute 대체, 더 상호작용적
    jq # json 파싱
    tlrc # 문서 보기
    just # script 태스크 관리
    coreutils # 기본 유틸리티
    file # 파일 타입 확인
    fd # find 대체
    restic # 백업 도구
    nmap # 네트워크 스캔
    pwgen # 패스워드 생성
    fastfetch # 빠른 fetch
    curl # 다운로드
    procs # ps 대체 - 실시간 프로세스 정보
    gping # ping 대체, 그래프 표시 기능
    dua # 디스크 사용량
    vim
    p7zip
    zstd
  ];

  home.shellAliases = {
    grep = "rg";
    find = "fd";
    ps = "procs";
    sd = "sed";
    ping = "gping"; # 그래픽 ping
  };

  home.sessionPath = [
    "$HOME/bin"
    "$HOME/.local/bin"
  ];
}
