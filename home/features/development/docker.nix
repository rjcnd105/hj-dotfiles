# docker.nix
let
  users = import ../../../users/user.nix;
in
{
  virtualisation.docker = {
    enable = true;
    # enableNvidia = true;  # NVIDIA GPU 지원이 필요한 경우
    autoPrune = {
      enable = true;        # 사용하지 않는 이미지/컨테이너 자동 정리
      dates = "monthly";     # 월간 정리
    };
  };

  # aliases나 추가 설정을 위한 zsh 구성
  programs.zsh.shellAliases = {
    d = "docker";
    dps = "docker ps";      # 실행 중인 컨테이너 목록
    dex = "docker exec -it"; # 컨테이너 접속 (예: dex <container> sh)
    dlogs = "docker logs -f"; # 실시간 로그 (예: dlogs <container>)
  };

  # docker 그룹에 사용자 추가
  users.users.${users.default}.extraGroups = [ "docker" ];
}
