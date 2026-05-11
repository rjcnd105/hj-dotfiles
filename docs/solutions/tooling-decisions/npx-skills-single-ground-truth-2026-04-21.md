---
title: npx skills 미러 단일화 — .agents를 ground truth로, 나머지 provider는 삭제
date: 2026-04-21
category: tooling-decisions
module: workspace-skills-management
problem_type: tooling_decision
component: tooling
severity: low
applies_when:
  - "npx skills CLI로 agent skill 설치 관리 중"
  - ".claude 외 여러 provider(.augment, .codebuddy, .junie 등) 디렉토리가 저절로 생겼을 때"
  - "Claude Code/Codex처럼 .agents-compatible active tools만 쓰는 dotfiles 환경"
tags: [npx-skills, agent-skills, ai-providers, symlinks, dotfiles, workspace]
---

# npx skills 미러 단일화 — .agents를 ground truth로, 나머지 provider는 삭제

## Context

`npx skills add <skill>`을 쓰면 `skills-lock.json` 매니페스트에 등재되고, skill 컨텐츠가 `.agents/skills/<name>/`에 clone된다. 동시에 CLI가 **알려진 AI 에이전트 플러그인 디렉토리 전부**에 심링크 미러를 만든다. 이번 workspace(`files/workspace/`)에서 실제 생긴 미러 디렉토리:

```
.adal .augment .bob .claude .codebuddy .commandcode .continue .cortex
.crush .factory .goose .iflow .junie .kilocode .kiro .kode .mcpjam
.mux .neovate .openhands .pi .pochi .qoder .qwen .roo .trae .vibe
.windsurf .zencoder
```

각 디렉토리 안에 `skills/` 서브가 있고 그 안의 모든 항목이 `../../.agents/skills/<name>`으로 가는 심링크. CLI 입장에선 "어떤 AI 도구를 쓰든 동일 skill 경로 인식"을 의도한 설계지만, **Claude Code/Codex + `.agents`만 쓰는 환경에서는 27~28개 provider 미러가 전부 dead weight**.

사용자 관찰: "왜 자꾸 저렇게 다른 AI provider들까지 다 추가되는 걸까?"

## Guidance

`skills` CLI를 쓰는 단일-도구 환경에서는 **`.agents/skills/`를 단일 ground truth로 정의**하고, 나머지를 다음 규칙으로 정리한다.

### 1. 보존

- `.agents/skills/` — 공개 skill + 본인 작성 skill 모두 이 곳에만 실제 파일로 존재
- `.claude/skills/` — 전부 `../../.agents/skills/<name>` 심링크. 본인 작성 skill도 예외 없음
- `.codex/skills/` — Codex 전용 system/plugin skill 경로. repo-local agent mirror cleanup에서 보존
- `skills-lock.json` — `npx skills update` 동작 전제, 유지

### 2. 삭제

- `.adal`, `.augment`, `.bob`, `.codebuddy`, … `.zencoder` 등 Claude/.agents 아닌 provider 디렉토리 전체
- 깨진 심링크(`find -type l` + 타겟 부재 테스트)

### 3. 본인 작성 skill 이동 규칙

`.claude/skills/<name>` 에 실제 디렉토리(심링크 아님)로 들어있는 개인 skill은 `.agents/skills/<name>`으로 이동 후 동일 이름 심링크로 교체한다. 이렇게 해야 공개 skill과 동일한 업데이트/검색 경로를 공유한다.

```bash
for name in <your-skills>; do
  src=".claude/skills/$name"
  dst=".agents/skills/$name"
  if [ -d "$src" ] && [ ! -L "$src" ]; then
    mv "$src" "$dst"
    ln -s "../../.agents/skills/$name" "$src"
  fi
done
```

### 4. 재발 방지 (해결 — 2026-04-27)

`skills --help` 기준 CLI가 `--agent <agents>` 옵션을 제공하므로, provider mirror 생성을 처음부터 제한한다.

- `files/workspace/.config/fish/user-functions.fish`의 `skills` fish function이 `skills add` / `skills experimental_sync` 호출에 `--agent claude-code codex`를 자동 추가한다.
- `files/workspace/.local/scripts/skills-cleanup`이 `.agents`, `.claude`, `.codex`, `.config`, `.hindsight`, `.local` 외 provider mirror 디렉토리와 깨진 skill symlink를 정리한다.
- `skills update` 후에도 cleanup을 실행해 update 과정에서 생기는 mirror drift를 제거한다.

## Why This Matters

- **인지 부담**: `ls files/workspace/` 결과에 30개 가까운 dotdir이 뜨면 실제 유의미한 `.claude`, `.config`, `.hindsight` 등을 가린다.
- **VCS 노이즈**: dotfiles 저장소(jj/git)에 매번 symlinks 수십~수백 개 포함된 diff가 찍힘 — 리뷰 불가.
- **동기화 실수**: 심링크 미러를 실파일로 착각해 `.agents/`만 지우면 모든 미러가 dangling. 반대로 미러를 지우고 `.agents/`는 방치하면 diff에 없어진 심링크 대거 표시.
- **일원화 이득**: 업데이트/검색/편집 경로가 하나. `.agents/skills/<name>/SKILL.md` 만 편집하면 모든 에이전트 관점에서 반영.

## When to Apply

- `npx skills` CLI를 쓰는 레포에서 최초 skill 설치 후 `.augment` 등 낯선 dotdir 등장 시
- 사용자가 Claude Code/Codex처럼 `.agents/` 호환 active tools만 쓰는 경우
- dotfiles 레포의 VCS diff에 dotdir 심링크 수백 개가 보일 때

## Examples

### Before

```
files/workspace/
├── .adal/skills/          # 심링크 미러 1
├── .agents/skills/        # 실제 콘텐츠 (ground truth)
├── .augment/skills/       # 심링크 미러 2
├── .claude/
│   └── skills/
│       ├── ce-light-compound/   # 실제 디렉토리 (본인 작성)
│       ├── elixir/              # 실제 디렉토리 (본인 작성)
│       ├── anki-connect -> ../../.agents/skills/anki-connect
│       └── ... (121개 심링크 + 12개 실제)
├── .codebuddy/skills/     # 심링크 미러 3
├── ... (.junie, .windsurf, .zencoder 등 27개)
└── skills-lock.json
```

### After

```
files/workspace/
├── .agents/skills/        # ground truth — 공개 + 본인 작성 12개 모두
│   ├── ce-light-compound/
│   ├── elixir/
│   ├── anki-connect/
│   └── ...
├── .claude/
│   └── skills/            # 전부 심링크
│       ├── ce-light-compound -> ../../.agents/skills/ce-light-compound
│       ├── elixir -> ../../.agents/skills/elixir
│       ├── anki-connect -> ../../.agents/skills/anki-connect
│       └── ...
└── skills-lock.json
```

### jj 복원 팁

실수로 `.agents/`를 삭제해 `.claude/skills/*` 심링크가 대량 dangling된 경우, `jj op log`로 삭제 직전 snapshot의 commit_id를 찾아 선택적 복원:

```bash
jj op log --limit 10                       # 삭제 전 snapshot 찾기
jj restore --from <commit_id> files/workspace/.agents files/workspace/skills-lock.json
```

## Related

- `docs/solutions/developer-experience/claude-remote-control-nixos-systemd-user-service-2026-04-17.md` — workspace dotfiles 관리 맥락
- `files/workspace/.agents/skills/find-skills/SKILL.md` — npx skills CLI 공식 설명 (`npx skills find/add/check/update`)
- [skills.sh](https://skills.sh/) — skill 레지스트리
