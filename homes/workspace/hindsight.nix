# Hindsight 코딩 에이전트 클라이언트 (Claude Code, Codex, pi 공용).
# 서버는 systems/homelab/hindsight.nix. 세 에이전트가 같은 런타임과 설정 파일을 읽는다.
# 에이전트별 hook·MCP·extension 등록은 files/workspace 아래 각 설정 파일에 있고,
# 모두 ~/.hindsight/coding-agents/dist/* 를 가리킨다. 절차는 docs/guides/hindsight.md.
{ config, pkgs, ... }:
let
  version = "0.8.7";
  # npm tarball에 번들된 dist만 쓴다(의존성 없음). 버전을 올릴 때 hash도 같이 바꾼다.
  client = pkgs.fetchzip {
    url = "https://registry.npmjs.org/@vectorize-io/hindsight-coding-agents/-/hindsight-coding-agents-${version}.tgz";
    hash = "sha256-SEenIfAcyubDbsXLG8MzqCx84B1e1WZ/Nb9DrP10s8o=";
  };
in
{
  # 런타임은 store에 고정한다. autoUpdate가 꺼져 있으면 클라이언트는 이 디렉터리에 쓰지 않는다.
  home.file.".hindsight/coding-agents".source = client;

  sops.secrets.HINDSIGHT_API_KEY.mode = "600";

  sops.templates."hindsight-coding-agent.json" = {
    path = "${config.home.homeDirectory}/.hindsight/coding-agent.json";
    mode = "600";
    content = builtins.toJSON {
      serverMode = "self-hosted";
      apiUrl = "https://hindsight.deopjib.cc";
      apiToken = config.sops.placeholder.HINDSIGHT_API_KEY;
      autoUpdate = false;
      # 최소 구성: 프롬프트마다 recall만 주입하고, LLM을 쓰는 부가 기능은 끈다.
      autoInject = "recall";
      # 기본 recall은 observation만 찾는데, 서버에서 통합을 꺼 두어 observation이 생기지 않는다.
      recallOptions.types = [
        "world"
        "experience"
      ];
      autoSeed = false;
      codebaseSurvey = false;
      pageTriggerType = "manual";
    };
  };
}
