{ pkgs, lib, ... }:
{
  home.packages =
    with pkgs;
    [
      coreutils  # 기본 유틸리티
      file      # 파일 타입 확인
      fd        # find 대체
      restic    # 백업 도구
      nmap      # 네트워크 스캔
      pwgen     # 패스워드 생성
      fastfetch # 빠른 fetch
      curl      # 다운로드
      procs     # ps 대체 - 실시간 프로세스 정보
      gping     # ping 대체, 그래프 표시 기능
      dua       # 디스크 사용량
      vim
      p7zip
      zstd
    ];

  home.shellAliases = {
      ping = "gping";        # 그래픽 ping
  };
}
