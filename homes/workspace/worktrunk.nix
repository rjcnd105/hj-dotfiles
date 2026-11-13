{ config, ... }:
let
  worktrunk = config.programs.worktrunk.package;
in
{
  # wt 바이너리와 셸 통합(wt switch 후 cd)만 Home Manager 모듈에 맡긴다.
  # settings 미사용: files/workspace/.config/worktrunk/config.toml을 file.nix 링크로 관리한다.
  # claudeCodeIntegration 미사용: programs.claude-code가 아니라 저장소 settings.json을 쓴다.
  programs.worktrunk.enable = true;

  # Claude Code·Codex 플러그인 marketplace.
  # 업스트림 main의 플러그인은 아직 릴리스되지 않은 wt 서브커맨드를 호출하므로,
  # 설치된 wt와 같은 태그의 소스를 로컬 marketplace로 등록해 버전을 맞춘다.
  home.file.".local/share/worktrunk/marketplace" = {
    source = worktrunk.src;
    force = true;
  };
}
