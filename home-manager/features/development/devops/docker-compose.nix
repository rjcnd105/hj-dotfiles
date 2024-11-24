
# docker-compose.nix
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    docker-compose
  ];

  programs.zsh.shellAliases = {
    dc = "docker-compose";
    dcu = "docker-compose up -d";    # 백그라운드 실행
    dcd = "docker-compose down";     # 중지 및 제거
    dcl = "docker-compose logs -f";  # 실시간 로그
    dcr = "docker-compose restart";  # 재시작
  };
}
