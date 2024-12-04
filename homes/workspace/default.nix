{
  config,
  inputs,
  pkgs,
  customConfig,
  ...
}:
{
  imports = [
    ./ssh-config.nix
    ../../sharedHome/cli
    ../../sharedHome/development
  ];

  home.sessionVariables = {
    EDITOR = "zed";
    SHELL = "nu";

    XDG_CONFIG_HOME = "${config.home.homeDirectory}/.config";
    XDG_CACHE_HOME = "${config.home.homeDirectory}/.cache";
    XDG_DATA_HOME = "${config.home.homeDirectory}/.local/share";
    XDG_STATE_HOME = "${config.home.homeDirectory}/.local/state";
  };

  home.sessionPath = [
    "/usr/bin"
    "${config.home.homeDirectory}/bin"
    "${config.home.homeDirectory}/.nix-profile/bin"
    "${config.home.profileDirectory}/bin"
  ];

  services = {
    gpg-agent = {
      enable = true;
    };

  };

  home.stateVersion = inputs.nixpkgs.lib.trivial.release;

  home.packages = with pkgs; [
    nix
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
    p7zip
    zstd
  ];

  programs.mise = {
    enable = true;
  };

  home.shellAliases = {
    grep = "rg";
    find = "fd";
    ps = "procs";
    sd = "sed";
    ping = "gping"; # 그래픽 ping
  };

  xdg = {
    enable = true;
  };

}
