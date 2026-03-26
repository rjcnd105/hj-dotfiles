---
title: "feat: nix-dots 프로젝트용 에이전트 하네스 (CLAUDE.md) 구축"
type: feat
status: active
date: 2026-03-26
---

# feat: nix-dots 프로젝트용 에이전트 하네스 구축

## Overview

nix-dots 저장소에서 AI 에이전트가 효과적으로 작업할 수 있도록 프로젝트 루트 `CLAUDE.md` 단일 파일을 구축한다. 에이전트의 실제 실수를 방지하는 지시에 집중하고, 에이전트가 코드에서 직접 파악 가능한 정보는 제외한다.

## Problem Frame

현재 nix-dots 저장소에는 프로젝트 전용 `CLAUDE.md`가 없다. 에이전트가 이 저장소에서 작업할 때:
- `darwin-rebuild`를 직접 호출하면 `env.nix` 누락으로 빌드 실패
- `systems/` vs `homes/` vs `sharedHome/` 구분을 모르고 엉뚱한 곳에 설정 추가
- `getModulePaths`의 6-경로 해석 패턴(system-skip 포함)을 모르면 모듈을 잘못된 위치에 생성
- sops-nix 비밀을 평문으로 커밋할 수 있음
- `env.nix` 자동생성 파일을 수정하려 할 수 있음

## Requirements Trace

- R1. 프로젝트 루트 `CLAUDE.md` 단일 파일로 핵심 컨텍스트 제공
- R2. 모든 줄이 "이걸 빼면 에이전트가 실수할까?" 기준을 통과
- R3. 에이전트가 빌드 검증과 시스템 적용을 명확히 구분하여 실행 가능
- R4. Nix 모듈 수정, dotfiles 관리, 탐색 등 모든 작업 유형 지원

## Scope Boundaries

- 기존 `files/workspace/.claude/CLAUDE.md` (글로벌 워크스페이스용)는 수정하지 않음
- `.claude/rules/` 디렉토리 미생성 — 현재 규모(호스트 1개, 모듈 ~20개)에서 path-scoped rules의 토큰 절약 효과가 미미(~150토큰, 컨텍스트의 0.075%)하므로 단일 파일로 충분
- `.claude/skills/`, `ai.md`, AGENTS.md는 범위 밖

## Context & Research

### Relevant Code and Patterns

- `flake.nix:42-47` — `hosts` 맵 (key: `workspace_hj`, hostName: `workspace`, system: `aarch64-darwin`)
- `flake.nix:56-65` — `getModulePaths`: 6개 경로를 시도하며 존재하는 것만 로드 (system-skip shortcut 포함)
- `flake.nix:78-85` — `myOptions` 컨텍스트 객체: key, email, system, hostName, userName, paths, absoluteProjectPath
- `systems/default.nix:12-17` — 환경 변수 설정 (`USER_HOST = myOptions.hostName` = `workspace`)
- `homes/file.nix` — 재귀적 파일 심링크 + `.manual-link` 센티넬
- `justfile` — 빌드 명령어 (`darwin-switch`, `build_hj-workspace`)

### Key Naming Convention (리뷰에서 발견된 critical issue)

- **Flake key**: `workspace_hj` — flake 참조에 사용 (예: `--flake .#workspace_hj`)
- **hostName** (`$USER_HOST`): `workspace` — 디렉토리명에 사용 (예: `systems/workspace/`, `files/workspace/`)
- **userName** (`$USER`): `hj`

이 세 가지 식별자를 혼용하면 안 됨.

### External References

- Anthropic CLAUDE.md 모범 사례: "이걸 빼면 에이전트가 실수할까?" 기준
- 3개 독립 subagent 리뷰: scope-guardian, simplicity, feasibility — 모두 단일 파일 구조로 수렴

## Key Technical Decisions

- **CLAUDE.md 단일 파일**: 3개 subagent 리뷰가 공통으로 권장. path-scoped rules 2파일의 최대 절약이 ~150토큰(0.075%)으로 유지보수 비용 대비 효과 없음. 숫자 줄 수 제한 없이, "이걸 빼면 에이전트가 실수할까?" 기준만 적용.
- **빌드 vs 적용 분리**: `just build_hj-workspace` = 검증(에이전트 자율 실행 OK), `just darwin-switch` = 시스템 적용(사용자 확인 후 실행). feasibility 리뷰에서 darwin-switch가 macOS 서비스를 재시작한다는 점을 지적.
- **정적 호스트 정보**: `$USER_HOST` 동적 확인 대신, CLAUDE.md에 "현재 호스트: workspace (aarch64-darwin)" 정적 명시. 호스트 1개에서 환경 변수 확인은 불필요한 tool call 유발.
- **`getModulePaths` 6-경로 전체 기재**: system-skip shortcut(`{prefix}/{host}/`, `{prefix}/{host}/{user}/`)을 누락하면 에이전트가 모듈 위치를 잘못 판단. 6개 패턴 모두 나열하거나 `flake.nix:56-65` 직접 참조.
- **모듈 시그니처 유연화**: 고정 패턴 대신 "`myOptions`는 항상 포함, 나머지 인자는 기존 유사 모듈 참조". 실제로 모듈마다 `config`, `lib`, `inputs` 포함 여부가 다름.
- **`@path` import 미사용**: `@flake.nix` import는 146줄 전체를 주입. 포인터만 사용.
- **스타일 규칙 미포함**: `with pkgs;` 사용 여부, 상대 경로 import 등은 에러가 아닌 스타일 선호. Nix sandbox가 이미 강제하는 것은 기재 불필요.
- **`shared/` 디렉토리 미기재**: `getModulePaths` 바깥에 있고 거의 비어있어, Module Layers에 포함하면 에이전트가 여기에 모듈을 잘못 추가할 위험.

## Open Questions

### Resolved During Planning

- **Q: 3파일(CLAUDE.md + 2 rules) vs 1파일?** → 1파일. 3개 독립 리뷰어가 공통으로 권장. 토큰 절약 효과 미미.
- **Q: `$USER_HOST` 동적 확인 vs 정적 명시?** → 정적. 호스트 1개에서 `echo $USER_HOST`는 불필요한 tool call.
- **Q: 숫자 줄 수 제한?** → 없음. "이걸 빼면 에이전트가 실수할까?" 기준이 자기 조절적.
- **Q: `shared/`를 Module Layers에 포함?** → 아니오. `getModulePaths` 바깥이라 혼란 유발.
- **Q: `nix flake check` 검증 명령어 포함?** → 아니오. 현재 darwinConfiguration 평가 오류 상태.

### Deferred to Implementation

- 향후 호스트 추가 시 정적 호스트 정보를 동적 패턴으로 전환 여부
- `nix flake check` 오류 해결 후 검증 명령어 추가 여부

## Implementation Units

- [ ] **Unit 1: 프로젝트 루트 CLAUDE.md 작성**

**Goal:** 에이전트가 이 프로젝트에서 실수하지 않기 위한 필수 컨텍스트를 단일 파일로 제공

**Requirements:** R1, R2, R3, R4

**Dependencies:** None

**Files:**
- Create: `CLAUDE.md`

**Approach:**

섹션 구성 (모든 줄은 "이걸 빼면 에이전트가 실수할까?" 기준 통과 필수):

1. **프로젝트 한 줄 소개** — Nix flake 기반 macOS dotfiles (nix-darwin + home-manager)

2. **Build & Verify** — 가장 중요한 섹션. 에이전트의 빌드 실수를 직접 방지.
   - `just build_hj-workspace` — 빌드 검증 (에이전트가 자율 실행 가능)
   - `just darwin-switch` — 빌드 + 시스템 적용 (**시스템 상태를 변경하므로 사용자 확인 후 실행**)
   - `nixfmt <file>` — Nix 파일 포맷팅
   - ⚠️ `darwin-rebuild`를 직접 호출하지 말 것 — justfile이 `createEnv.sh`로 `env.nix`를 생성해야 함
   - ⚠️ `env.nix`는 자동생성 파일 — 절대 수정하지 말 것

3. **Architecture** — 모듈 해석 규칙.
   - `getModulePaths`가 6개 경로를 시도 (존재하는 것만 로드). flake.nix:56-65 참조:
     ```
     {prefix}/default.nix
     {prefix}/{system}/default.nix
     {prefix}/{system}/{host}/default.nix
     {prefix}/{system}/{host}/{user}/default.nix
     {prefix}/{host}/default.nix          ← system-skip shortcut
     {prefix}/{host}/{user}/default.nix   ← system-skip shortcut
     ```
   - 현재 호스트: flake key `workspace_hj`, hostName `workspace` (= `$USER_HOST` = 디렉토리명), system `aarch64-darwin`
   - `myOptions` 컨텍스트가 모든 모듈에 전달됨. `myOptions`는 항상 포함하되, 나머지 인자(`config`, `lib`, `inputs` 등)는 기존 유사 모듈의 시그니처를 참조

4. **Module Layers** — 디렉토리별 역할 구분.
   - `systems/` — nix-darwin 시스템 설정 (`getModulePaths "systems"`)
   - `homes/` — home-manager 사용자 설정 (`getModulePaths "homes"`)
   - `sharedHome/` — 모든 호스트가 공유하는 home-manager 모듈. **변경 시 전체 호스트에 영향**
   - `files/{host}/` — 정적 dotfiles, `~/`로 재귀 심링크됨. `.manual-link` 파일이 있는 디렉토리는 통째로 링크
   - 호스트별 경로: `systems/workspace/`, `homes/workspace/`, `files/workspace/`, `secrets/workspace/`

5. **Secrets** — sops-nix + age 암호화. 평문 비밀 절대 커밋 금지. `.sops.yaml`에 creation_rules 정의.

글로벌 `~/.claude/CLAUDE.md`에 이미 있는 VCS 지시(jj 사용)는 중복하지 않음.

**Patterns to follow:**
- Anthropic 모범 사례: 모든 줄에 대해 "이걸 빼면 에이전트가 실수할까?" 자문
- flake key(`workspace_hj`) vs hostName(`workspace`) vs userName(`hj`) 구분 명확히

**Test scenarios:**
- 새 대화에서 에이전트가 `just build_hj-workspace`로 검증하는지
- 에이전트가 `darwin-rebuild`를 직접 호출하지 않는지
- `just darwin-switch` 실행 전에 사용자 확인을 구하는지
- `systems/` 파일 수정 시 `homes/`와 구분하는지
- env.nix를 수정하려 하지 않는지
- `getModulePaths`의 system-skip shortcut을 이해하는지

**Verification:**
- "이걸 빼면 에이전트가 실수할까?" 기준을 통과하지 못하는 줄이 없음
- flake key vs hostName vs userName 구분이 명확
- 빌드(검증)과 적용(시스템 변경)이 분리되어 있음

## Explicit Assumptions

- 글로벌 `~/.claude/CLAUDE.md`의 jj 관련 지시가 이미 로드되므로, 프로젝트 CLAUDE.md에서 VCS 지시를 중복하지 않는다.
- `just` 명령어는 Claude Code의 Bash tool에서 실행 가능하다 (mise가 PATH에 just를 포함).
- 호스트가 1개(`workspace_hj`)인 동안은 단일 CLAUDE.md로 충분하다. 호스트가 2개 이상이 되면 `.claude/rules/`와 동적 환경 변수 패턴을 도입한다.

## System-Wide Impact

- **Interaction graph:** CLAUDE.md는 Claude Code 세션 시작 시 자동 로드. 글로벌 `~/.claude/CLAUDE.md`와 자동 병합됨. 양쪽에 모순되는 지시가 없도록 주의.
- **Error propagation:** CLAUDE.md 내 잘못된 빌드 명령어는 에이전트의 무한 디버깅 루프를 유발할 수 있음. `nix flake check`는 현재 오류 상태이므로 제외.
- **State lifecycle risks:** `just darwin-switch`가 시스템 상태를 변경하므로, 에이전트 자율 실행을 명시적으로 금지.
- **docs/plans/ vs .claude/plans/:** 글로벌 CLAUDE.md가 plan을 `.claude/plans/`에 저장하라고 하지만, 이 프로젝트는 `docs/plans/`를 사용 중. 필요시 프로젝트 CLAUDE.md에서 오버라이드 가능.

## Risks & Dependencies

- **justfile shell 호환성**: justfile이 `set shell := ["zsh", "-cu"]`를 사용. `just`가 PATH에 있으면 Claude Code Bash tool에서 실행 가능하지만, 실행 시 검증 필요.
- **CLAUDE.md 유지보수 부담**: 단일 파일이므로 유지보수 포인트가 1개. Nix 모듈 추가/삭제 시 CLAUDE.md 업데이트는 거의 불필요 (모듈별 상세를 기재하지 않으므로).
- **글로벌 CLAUDE.md 충돌**: 양쪽 CLAUDE.md에 모순되는 지시가 생기면 에이전트 행동이 불안정. VCS 지시를 중복하지 않는 것으로 완화.

## Sources & References

- Anthropic 공식 CLAUDE.md 모범 사례
- ryanmsnyder/nix-config CLAUDE.md (Nix 프로젝트 실례)
- josix/awesome-claude-md 컬렉션
- 3개 독립 subagent 리뷰 (scope-guardian, code-simplicity, feasibility)

## Review Notes

**Inline review (Phase 1):**
7개 렌즈로 리뷰 수행. `nix flake check` 제거, 6→3파일 축소, `@path` import 제거 등 반영.

**Subagent review (Phase 2):**
3개 독립 subagent(scope-guardian, code-simplicity, feasibility)가 공통으로 지적한 사항을 반영:

1. **3파일 → 1파일 축소** — path-scoped rules의 ~150토큰 절약이 유지보수 비용 대비 무의미. `.claude/rules/` 디렉토리 미생성.
2. **숫자 줄 수 제한 제거** — 80/15/12줄 제한이 writing을 constraint-satisfaction puzzle로 만듦. "이걸 빼면 에이전트가 실수할까?" 기준으로 대체.
3. **`$USER_HOST`/`$SYSTEM` 동적 필터링 제거** — 호스트 1개에서 필터링 대상 없음. 정적 명시로 대체.
4. **`$USER_HOST` = `workspace` (≠ `workspace_hj`) 구분 명확화** — flake key vs hostName vs userName 세 식별자를 명시적으로 구분.
5. **`just darwin-switch` 자율 실행 경고 추가** — 시스템 상태 변경 명령이므로 사용자 확인 후 실행으로 분리.
6. **`shared/` Module Layers에서 제거** — `getModulePaths` 바깥의 거의 비어있는 디렉토리. 포함하면 에이전트가 잘못된 위치에 모듈 추가.
7. **`getModulePaths` 6-경로 전체 기재** — system-skip shortcut 2개가 누락되면 에이전트가 모듈 해석을 잘못 이해.
8. **모듈 시그니처 유연화** — 고정 패턴 대신 "myOptions 항상 포함, 나머지는 기존 모듈 참조".
9. **스타일 규칙(`with pkgs;`, 상대 경로) 제거** — 에러 방지가 아닌 스타일 선호. Nix sandbox가 이미 강제하는 것 포함.
10. **"Adding a Tool" 섹션 제거** — 기존 코드에서 자명한 패턴.
11. **"Host & Platform" → Architecture에 통합** — 호스트 1개에서 별도 섹션 불필요.

**Review confidence:** High — 3개 독립 리뷰어가 동일 방향으로 수렴. 모든 critical issue 반영 완료.

## Decision Brief

**Recommendation:**
nix-dots 저장소에 에이전트 하네스가 없어, 에이전트가 `darwin-rebuild` 직접 호출, `env.nix` 수정, 평문 비밀 커밋 같은 실수를 할 수 있는 문제. 프로젝트 루트 CLAUDE.md 단일 파일로 핵심 안전장치와 아키텍처 컨텍스트를 제공하여 해결.

- **Effort:** Trivial (< 15 min) — 1개 파일 신규 생성, 기존 코드 수정 없음
- **Risk:** 매우 낮음. 새 파일 1개, 삭제만으로 원복 가능.
- **If we skip this:** 에이전트가 매 세션마다 프로젝트 구조를 탐색해야 하고, darwin-rebuild 직접 호출이나 env.nix 수정 같은 실수 가능성 잔존.
- **Reversible?** Yes — 파일 1개 삭제로 완전 원복.

**Actions:**
1. `CLAUDE.md` 생성 — Build & Verify, Architecture (getModulePaths 6-경로), Module Layers, Secrets, flake key/hostName/userName 구분

**Prompts used:**
- 현재 프로젝트를 상세하게 분석해서 agent에게 도움이 될만한 context, 지침, 룰, 하네스를 적고 싶어
- 에이전트가 효과적으로 동작할 수 있고 토큰을 낭비하지 않게끔 정말 효과적인 예시들을 기반으로
- $USER $USER_HOST $SYSTEM 들을 통해서 현재 사용자 환경을 기반으로 확인해서 불필요한 context를 줄이고 싶어
- 최신의 nix flake best practices 기반으로 review + 에이전트 친화적인 구성인지 검토
- 너무 제약사항, workflow가 많거나 복잡하지는 않은지, 과하지는 않은지 검토 (3개 독립 subagent)
