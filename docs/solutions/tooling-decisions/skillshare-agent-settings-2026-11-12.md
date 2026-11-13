---
title: skillshare 기반 에이전트 skill·MCP·지침 관리
date: 2026-11-12
category: tooling-decisions
module: workspace-agent-settings
problem_type: tooling_decision
component: tooling
severity: low
supersedes: apm-codex-first-agent-settings-2026-07-30.md
applies_when:
  - "Claude Code, Codex, Cursor, Pi에 같은 skill·MCP·지침을 배포할 때"
  - "skill을 추가·갱신·제거하거나 MCP 서버를 바꿀 때"
  - "files/workspace가 Home Manager를 통해 사용자 홈에 투영될 때"
tags: [skillshare, codex, claude-code, cursor, pi, agent-skills, mcp, dotfiles, mise]
---

# skillshare 기반 에이전트 skill·MCP·지침 관리

## Decision

APM을 걷어내고 `files/workspace`를 skillshare 프로젝트 하나로 쓴다.
`files/workspace/.skillshare/config.yaml`이 skill, MCP, 공용 지침 배포의
단일 권위다. skillshare 자체는 mise로 설치한다.

```toml
[tools."github:runkids/skillshare"]
version = "latest"
```

global mode(`~/.config/skillshare`)는 쓰지 않는다. `~/.mcp.json`,
`~/.codex/config.toml`, `~/.cursor/mcp.json`이 저장소 파일로 가는 링크라서
global MCP sync가 링크를 거부한다. Home Manager가 이미 `files/workspace`를
홈에 투영하므로 project mode 출력이 곧 사용자 범위 설정이다.

macOS의 `~/.config/skillshare/config.yaml`은 Herdr skillshare 패널이 global
범위를 오류 없이 읽도록 둔 빈 placeholder다(`skillshare init --no-copy
--no-targets --no-git --no-skill`). target이나 skill을 추가하지 않는다.

## Authority

- `.skillshare/config.yaml`: target, 원격 skill 목록(`skills:`), audit 기준,
  MCP 서버, extras(공용 지침 배포)
- `.skillshare/skills.lock.json`: 원격 skill의 resolved commit
- `.skillshare/skills/<name>/`: skill 원본
  - 직접 작성한 local skill은 git에 추적한다.
  - 원격 skill은 skillshare가 관리하는 `.skillshare/.gitignore`가 제외한다.
    새 머신에서는 `skillshare install -p`로 받는다.
- `.codex/AGENTS.md`: 공용 지침 원본. 직접 수정한다.
- 생성물(직접 수정하지 않음)
  - Claude Code: `.claude/skills/<name>/`, `.mcp.json`,
    `.claude/rules/personal-agent-guide.md`(`.codex/AGENTS.md`로 가는 symlink)
  - Codex: `.agents/skills/<name>/`, `.codex/config.toml`의 `[mcp_servers.*]`
  - Cursor: `.cursor/mcp.json`, `.cursor/rules/personal-agent-guide.mdc`
    (frontmatter 뒤에 append 블록). Cursor는 `.agents/skills`를 읽으므로
    cursor target의 skill 배포는 끈다.
  - Pi: `.config/pi/AGENTS.md`(`.codex/AGENTS.md`로 가는 symlink,
    `homes/workspace/pi.nix`가 `~/.pi/agent/AGENTS.md`로 연결)
  - Antigravity: `.gemini/AGENTS.md`(`.codex/AGENTS.md`의 copy,
    `homes/file.nix`가 `~/.gemini/AGENTS.md`로 연결)
  - `.claude/skills/`, `.agents/skills/` 루트의 `.skillshare-manifest.json`

MCP 파일은 skillshare가 통째로 소유하지 않는다. `config.yaml`의 서버만 갱신하고,
`.mcp.json`의 `node_repl`, `.codex/config.toml`의 `brilliant`처럼 직접 넣은
서버는 그대로 둔다.

skillshare 밖에 남는 항목:

- `.claude/skills/synced`: Claude 계정 동기화 skill. 루트 `.gitignore`가 제외한다.
- `ego-browser`, `hindsight-coding-agent`: 앱·플러그인이 제공하는 skill 링크
- `.config/pi/mcp.json`(codegraph): skillshare에 pi target이 없어 손으로 관리한다.
  Pi는 `~/.agents/skills`를 직접 탐색하고, 제외 목록은
  `.config/pi/settings.json`의 `skills`가 가진다.

## Copy mode

claude, codex target은 `mode: copy`다. symlink mode는 `~/.claude/skills/<name>`이
gitignore된 `.skillshare/skills/<name>`을 가리키므로, git으로 저장소를 받는
homelab(`filesHost = workspace`, comin)에서는 링크가 끊긴다. copy mode는 실제
파일을 `.claude/skills`, `.agents/skills`에 쓰고 git이 그대로 배포하므로
homelab에서 skillshare를 실행하지 않아도 된다.

## Plugins

plugin은 skillshare로 관리하지 않고 각 도구의 native 선언에 둔다.

- Claude Code: `.claude/settings.json`의 `enabledPlugins`,
  `extraKnownMarketplaces`
- Codex: `.codex/config.toml`의 `[plugins]`, `[marketplaces]`
- Pi: `.config/pi/settings.json`의 `packages`

이유는 세 가지다.

- project mode는 Codex plugin을 지원하지 않는다.
- managed plugin은 머신별 `skillshare-<plugin>-<hash>` marketplace를 만들어
  추적 중인 settings에 머신 로컬 경로를 쓴다.
- `plugin import`는 기존 설치를 머신 로컬 receipt로만 기록해 재현되지 않는다.

## Nix Projection

`homes/file.nix`는 `.skillshare/` 아래 파일을 홈에 링크하지 않는다. skillshare는
현재 디렉토리의 `.skillshare/config.yaml`로 project mode를 판정하므로, 링크하면
`~`에서 실행한 skillshare가 `~`를 두 번째 프로젝트로 잡는다.

`.claude/skills`, `.claude/rules`, `.agents`, `.cursor/rules`는 `.manual-link`
marker로 디렉토리 전체를 링크한다. `.codex/AGENTS.md`, `.gemini/AGENTS.md`,
`.mcp.json`, `.codex/config.toml`, `.cursor/mcp.json`은 파일별 링크다.
`mkLinkFolders`는 symlink를 건너뛰므로 `.codex/AGENTS.md`와 `.gemini/AGENTS.md`는
일반 파일로 두고, `.config/pi/AGENTS.md` symlink는 `homes/workspace/pi.nix`가
`~/.pi/agent/AGENTS.md`로 연결한다.

## Workflow

`files/workspace`에서 실행한다. TUI를 피하려면 `</dev/null` 또는 `--no-tui`를 쓴다.

```bash
skillshare install -p                 # lock 기준 원격 skill 받기
skillshare install <source> -p        # 원격 skill 추가
skillshare sync -p                    # skill을 target에 복사
skillshare sync mcp -p --no-tui       # MCP 서버를 각 target 파일에 반영
skillshare sync extras -p             # .codex/AGENTS.md를 Claude·Cursor·Pi·Antigravity에 배포
skillshare update -p                  # 원격 skill 갱신
skillshare uninstall <name> -p --force
skillshare status -p
skillshare doctor -p
```

skill을 바꾼 뒤에는 `.claude/skills`, `.agents/skills`의 복사본도 함께 커밋한다.

특정 agent에서만 skill을 끌 때는 target exclude를 쓴다. Claude `/skills`가
쓰는 `.claude/settings.json`의 `skillOverrides`는 skillshare와 Herdr 패널이 읽지
않으므로, 그쪽으로 끄면 패널에 계속 사용 가능한 것으로 보인다. claude target은
현재 `elixir`, `find-docs`, `obsidian-bases`, `gitbutler`(skill name `but`)를
제외한다.

```bash
skillshare target claude --add-exclude <dir-name> -p && skillshare sync -p
```

새 clone에서는 `install -p`를 `sync -p`보다 먼저 실행한다. 원격 skill 원본은
gitignore되어 clone에 없으므로, `sync -p`를 먼저 하면 원본이 없는 복사본 84개를
prune한다(2026-11-12 sandbox `--dry-run`에서 확인). homelab처럼 git으로 받은
복사본만 쓰는 머신에서는 skillshare를 실행하지 않는다.

## Audit

`audit.block_threshold`는 `CRITICAL`이다. `prompt-injection-1` 규칙이 JS의
`root:` 줄을 CRITICAL로 오탐해 `modern-web-guidance` 설치를 막았다. upstream
내용을 확인한 뒤 `--force`로 설치했으므로, `update`가 같은 이유로 막히면 내용을
다시 확인하고 `--force`로 진행한다.

## Migration Removed

- `apm.yml`, `apm.lock.yaml`, `.apm/`, `apm_modules/`, `.apm-local/`
- `.config/ruler/`
- 6개월(2026-05-12 기준) 넘게 갱신되지 않은 skill: `hook-development`,
  `skill-development`, `skill-creator`, local `kb`
- Codex `config.toml`의 끊긴 `[[skills.config]]` 경로, 제거된 plugin의
  hook state, 사라진 project 항목
- Pi `settings.json`의 없는 skill 제외 항목

`obsidian-cli`, `obsidian-bases`, `claude-api`는 local 사본 대신 upstream
원격 skill로 다시 받았다.

## References

- [skillshare docs](https://skillshare.runkids.cc/docs)
- [Command reference](https://skillshare.runkids.cc/docs/reference/commands)
- [Migration](https://skillshare.runkids.cc/docs/how-to/advanced/migration)
- [Sharing MCP](https://skillshare.runkids.cc/docs/how-to/daily-tasks/sharing-mcp)
- [Sharing plugins](https://skillshare.runkids.cc/docs/how-to/daily-tasks/sharing-plugins)
- [audit](https://skillshare.runkids.cc/docs/reference/commands/audit)
