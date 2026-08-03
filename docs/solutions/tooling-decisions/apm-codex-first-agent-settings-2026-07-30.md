---
title: APM 기반 Codex 우선 에이전트 설정 관리
date: 2026-07-30
category: tooling-decisions
module: workspace-agent-settings
problem_type: tooling_decision
component: tooling
severity: low
applies_when:
  - "Codex, Claude Code, Cursor에 같은 agent primitive를 배포할 때"
  - "skill, instruction, agent, hook, MCP를 하나의 manifest로 관리할 때"
  - "files/workspace가 Home Manager를 통해 사용자 홈에 투영될 때"
tags: [apm, codex, claude-code, cursor, agent-skills, mcp, dotfiles, mise]
---

# APM 기반 Codex 우선 에이전트 설정 관리

## Decision

`files/workspace`를 하나의 project-scoped Microsoft Agent Package Manager
(APM) 프로젝트로 사용한다. 별도의 APM global install은 만들지 않는다.
Home Manager가 이 경로를 사용자 홈에 out-of-store symlink로 투영하므로
project output이 곧 사용자 범위 설정이다.

Codex 설정을 권위 소스로 삼고 APM target은 다음처럼 고정한다.

```yaml
targets:
  - codex
  - claude
  - cursor
```

Claude Code와 Cursor에만 존재하던 별도 plugin/marketplace/hook 조합으로
기능을 추가하지 않는다. Codex에서 사용하는 공통 primitive를 APM이 각
target의 native path로 변환한다.

## Authority

- `files/workspace/apm.yml`
  - 공개 package/plugin 의존성
  - Codex 기준 MCP 서버
  - 고정 target 목록
- `files/workspace/.apm/`
  - 직접 작성한 skill
  - 공통 reviewer agent
  - Codex의 `Personal Agent Guide` 원본 instruction
- `files/workspace/apm.lock.yaml`
  - 원격 의존성의 resolved commit과 배포 파일
- APM 생성물
  - Codex: `.agents/skills/`, `.codex/agents/`, `.codex/AGENTS.md`
  - Claude Code: `.claude/skills/`, `.claude/agents/`,
    `.claude/rules/`
  - Cursor: `.agents/skills/`, `.cursor/agents/`, `.cursor/rules/`,
    `.cursor/hooks.json`, `.cursor/mcp.json`
  - MCP: `.codex/config.toml`, `.mcp.json`, `.cursor/mcp.json`

`.agents/skills/`와 `.claude/skills/`는 더 이상 작성 위치가 아니다.
직접 만든 skill은 `.apm/skills/<name>/`에서 수정하고 `apm install`로
다시 생성한다.

## Tool Installation

APM 자체는 mise의 `latest` channel로 선언한다.

```toml
[tools.apm]
version = "latest"
```

Codex CLI는 이 선언의 대상이 아니다. Codex는 Bun global package
`@openai/codex`로 설치하며 현재 실행 경로는
`/Users/hj/.cache/.bun/bin/codex`다. APM은 Codex binary를 설치하지 않고
설정과 agent package만 배포한다.

## Workflow

`files/workspace`에서 실행한다.

```bash
apm install
apm compile \
  --target codex \
  --single-agents \
  --output .codex/AGENTS.md
```

의존성 업데이트는 먼저 계획을 확인한 뒤 lock을 갱신한다.

```bash
apm update --dry-run
apm update --yes
apm compile \
  --target codex \
  --single-agents \
  --output .codex/AGENTS.md
```

재현 설치는 다음 명령을 사용한다.

```bash
apm install --frozen
apm audit --ci
```

`--global` 또는 `-g`는 사용하지 않는다. `files/workspace`가 이미 Nix로
사용자 홈에 적용되므로 별도 global APM authority를 만들면 설정이
이중화된다.

## Secrets and Target Differences

Context7 인증 키는 mise가 환경에 제공하고 Codex가 시작 시 해석한다.
`apm.yml`의 `env_http_headers`는 Codex native passthrough field로
유지한다. APM 0.26.0은 이 필드를 다른 target에도 그대로 기록하고
unknown-key warning을 출력하지만 secret 값 자체를 생성 파일에 쓰지
않는다.

APM이 표현하지 못하는 runtime 설정은 native file에 남긴다.

- OpenAI가 공급하는 Codex bundled/primary/curated plugin enablement,
  모델, TUI, desktop 설정: `.codex/config.toml`
- Claude Code의 권한, 언어, effort 같은 runtime preference:
  `.claude/settings.json`
- Cursor editor preference: `.config/cursor/settings.json`
- Claude Code profile 자료: `.claude/profiles/`

이 항목들은 package source가 아니며 APM 의존성과 경쟁하지 않는다.
`.claude/settings.local.json`은 project-local override 경로이므로 사용자 홈
projection에 사용하지 않는다. 공통 MCP 목록은 APM이 생성한 `.mcp.json`이
소유하고, `.claude/settings.json`은 Claude에서 활성화할 공통 서버 목록과
Claude native preference만 소유한다.

저장소 루트의 `CLAUDE.md`는 `@AGENTS.md`만 import한다. 공통 작업 지침은
`AGENTS.md`를 단일 권위로 유지하고 Claude 전용 복사본을 만들지 않는다.
공통 hook은 APM source에 실제 실행 대상과 함께 선언된 경우에만 생성한다.
현재는 공통 hook이 없으므로 `.codex/hooks.json`, `.claude/apm-hooks.json`,
`.codex/apm-hooks.json`을 두지 않는다.

`ego-browser`는 설치된 ego lite 앱에서 확인한 현재 skill tree를
`.apm/skills/ego-browser/`에 복사해 관리한다. 앱을 업데이트한 뒤 skill도
갱신하려면 새 tree를 이 원본 위치에 다시 반영하고 `apm install`과
`apm audit --ci`를 실행한다. manifest가 없는 앱 내부 경로를 직접 local
dependency로 삼지 않으므로 lockfile 감사도 재현 가능하다.

기존 OpenCode 설정에서 공통으로 재사용 가능한 primitive는 Codex 기준
APM source로 옮겼다.

- `atlassian-api-guidelines`, `feature-planner`, `using-jj`:
  `.apm/skills/`
- `commit-review`, `review-{backend,frontend,devops,lead}`:
  `.apm/agents/`
- `gh_grep`, `exa`: `apm.yml`의 native HTTP MCP

OpenCode 전용 model, provider, permission, Gemini auth plugin 설정은
Codex/Claude/Cursor와 호환되는 공통 primitive가 아니므로 투영하지 않는다.
APM agent source에는 Codex가 실제로 보존하는 `name`, `description`, body를
권위로 두고, Claude Code와 Cursor가 같은 persona를 받게 한다.

## Nix Projection

APM이 전부 소유하는 생성 디렉토리에는 `.manual-link` marker를 둔다.
`homes/file.nix`는 marker가 있는 디렉토리를 개별 파일 집합이 아니라
out-of-store directory symlink 하나로 연결한다. 따라서 새 skill이나
agent가 생성되어도 별도 Home Manager 파일 목록을 추가하지 않는다.

`.codex/agents/`는 예외로 파일별 링크를 사용한다. Codex native plugin이
관리하는 `~/.codex/agents/compound-engineering/`과 APM 생성 agent가 같은
부모 디렉토리를 공유하므로, 디렉토리 전체를 대체하면 native plugin
agent를 잃게 된다. 파일별 Home Manager projection은 APM agent를 추가하면서
runtime 소유 하위 디렉토리를 보존한다.

`apm_modules/`는 설치 cache이므로 추적하지 않는다. `apm.yml`,
`.apm/`, `apm.lock.yaml`, target 생성물만 저장소에 남긴다.

## Migration Removed

이 결정으로 다음 legacy authority를 제거했다.

- `skills-lock.json`
- fish의 `skills` wrapper
- `.local/scripts/skills-cleanup`
- Claude Code의 독립 plugin, marketplace, plugin 제공 skill과 hook
- 실행 파일이 사라진 Claude hook/status line 및 Codex hook 사본
- 별도 내용을 가진 `CLAUDE.original.md`와 stale `CLAUDE.md`
- Codex의 외부 native marketplace 중 비활성 항목과
  `agent-skills@agent-skills` plugin entry
- 현재 target이 아닌 OpenCode의 독립 runtime/model/plugin 설정

`addyosmani/agent-skills`는 native Codex marketplace 대신 `apm.yml`
의존성으로 설치되어 세 target에 동일한 skill, agent, hook을 제공한다.

## References

- [APM targets matrix](https://microsoft.github.io/apm/reference/targets-matrix/)
- [APM manifest schema](https://microsoft.github.io/apm/reference/manifest-schema/)
- [APM MCP installation](https://microsoft.github.io/apm/consumer/install-mcp-servers/)
