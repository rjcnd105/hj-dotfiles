{
  config,
  inputs,
  pkgs,
  customConfig,
  ...
}:
{
  imports = [
    inputs.catppuccin.homeManagerModules.catppuccin
    {
      catppuccin = {
        enable = true;
        flavor = "macchiato";
      };
    }
    ./ssh-config.nix
    ../../sharedHome/cli
    ../../sharedHome/development
  ];

  home.sessionVariables = {
    EDITOR = "zed";
  };
  home.sessionPath = [
    "$HOME/bin"
    "$HOME/.local/bin"
  ];

  home.stateVersion = inputs.nixpkgs.lib.trivial.release;

  home.packages = with pkgs; [
    nix
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

}
