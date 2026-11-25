{ config, ... }:
let
  worktrunk = config.programs.worktrunk.package;
in
{
  programs.worktrunk.enable = true;

  # 업스트림 main의 플러그인은 아직 릴리스되지 않은 wt 서브커맨드를 호출하므로,
  # 설치된 wt와 같은 태그의 소스를 로컬 marketplace로 등록해 버전을 맞춘다.
  home.file.".local/share/worktrunk/marketplace" = {
    source = worktrunk.src;
    force = true;
  };
}
