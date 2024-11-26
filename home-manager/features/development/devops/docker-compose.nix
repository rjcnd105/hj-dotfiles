# docker-compose.nix
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    docker
    docker-compose
    lazydocker
  ];

  programs.zsh.shellAliases = {
    d = "docker";
    dps = "docker ps"; # 실행 중인 컨테이너 목록
    dex = "docker exec -it"; # 컨테이너 접속 (예: dex <container> sh)
    dlogs = "docker logs -f"; # 실시간 로그 (예: dlogs <container>)

    dc = "docker-compose";
    dcu = "docker-compose up -d"; # 백그라운드 실행
    dcd = "docker-compose down"; # 중지 및 제거
    dcl = "docker-compose logs -f"; # 실시간 로그
    dcr = "docker-compose restart"; # 재시작
  };
}
