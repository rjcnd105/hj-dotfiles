{ pkgs, lib, ... }:
{
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
  ];

  programs.z.enable = true;

  # 완전 대체 목록
  home.shellAliases = {
    grep = "rg";
    find = "fd";
    ps = "procs";
    sd = "sed";
  };
}
