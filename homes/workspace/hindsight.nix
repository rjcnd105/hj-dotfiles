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
      # 최소 구성: 세션 첫 프롬프트에 recall 결과를 한 번 주입하고, LLM을 쓰는 부가 기능은 끈다.
      autoInject = "recall";
      # 기본 recall은 observation만 찾는데, 서버에서 통합을 꺼 두어 observation이 생기지 않는다.
      recallOptions.types = [
        "world"
        "experience"
      ];
      autoSeed = false;
      codebaseSurvey = false;
      pageTriggerType = "manual";
      # 기억 정책은 서버 기본값 한 곳에 둔다. 클라이언트가 bank에 자기 mission과 strategy를 쓰지 못하게 한다.
      manageBankConfig = false;
      # 페이지를 쓰지 않으므로 턴마다 하던 페이지 조회와 도구 안내 재주입을 사실상 끈다.
      # 0은 클라이언트가 기본값 1로 되돌리므로 큰 값을 준다(조회는 세션당 한 번만 남는다).
      pageRefreshEveryTurns = 100000;
      # 세션 시작 안내문은 끌 수 없고 페이지 검색부터 하라고 시킨다. 한 줄을 덧붙여 바로잡는다.
      toolGuideExtra = "- This bank keeps no pages: skip hindsight_search_pages, hindsight_list_pages and hindsight_capture_initiative. When a past failure, fix, decision or user feedback would help, call hindsight_reflect(query).";
    };
  };
}
