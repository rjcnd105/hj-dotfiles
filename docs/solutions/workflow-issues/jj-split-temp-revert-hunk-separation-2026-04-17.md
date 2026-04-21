---
title: jj split의 hunk 단위 분리 — temp-revert 기법으로 non-interactive 달성
date: 2026-04-17
category: workflow-issues
module: jj / vcs
problem_type: workflow_issue
component: development_workflow
severity: medium
applies_when:
  - working copy에 의미적으로 서로 다른 변경이 한 파일 안에 섞여 있을 때
  - 에이전트/스크립트 등 non-interactive 환경에서 hunk 분리가 필요할 때
  - `jj split -i` diff editor 실행이 불가능한 상황 (CI, 자동화, Claude Code 등)
tags:
  - jj
  - jujutsu
  - commit-split
  - vcs-workflow
  - non-interactive
  - hunk-split
---

# jj split의 hunk 단위 분리 — temp-revert 기법으로 non-interactive 달성

## Context

jj의 `jj split`은 두 가지 동작 모드가 있다:

1. **파일 단위 split**: `jj split <PATH>...` — 지정 경로의 변경 전체를 첫 커밋으로, 나머지는 working copy(child)로 이동. Non-interactive.
2. **hunk 단위 split**: `jj split -i` — diff editor를 열어 hunk 단위로 선택. Interactive TTY 필요.

문제 상황: 하나의 파일 안에 의미가 다른 여러 변경이 섞여 있어 hunk 단위 분리가 필요한데, non-interactive 환경에서 작업해야 하는 경우. (예: Claude Code가 세션 내에서 의미별 커밋 분리 수행)

이번 세션 실제 사례: `sharedHome/development/default.nix`에 `./lsp.nix` import + `./go.nix` import 두 줄이 동시에 추가된 상태. 각각 다른 커밋으로 분리 필요. `files/workspace/.claude/settings.json`에도 `SessionStart` hook 등록과 `enabledPlugins`/`effortLevel` 변경이 같은 파일에 공존.

## Guidance

**Temp-revert 3-step 기법** — interactive 없이 hunk-level split 달성:

1. **원복 편집**: 첫 커밋에 포함하고 싶지 **않은** hunk를 "파일 원본 상태"로 되돌린다. `jj diff <file>`로 원본 값을 먼저 파악.
2. **파일 단위 split**: `jj split -m "<message>" <file> [other-files...]` 실행. 첫 커밋엔 남긴 변경만 포함, working copy(child)는 원본 상태 파일을 보유.
3. **재적용**: working copy에서 원복했던 부분을 원래 최종 상태로 다시 편집. 이 변경은 child 커밋에 들어간다.

결과적으로 하나의 working copy 변경이 두 개의 의미적으로 분리된 커밋 체인(`parent: 첫 커밋` ← `child: 재적용 분`)으로 나뉜다.

### 핵심 워크플로 예시

파일 `settings.json`에 hunk A(유지) + hunk B(분리) 공존 상태:

```bash
# 1. Hunk B 부분만 원본값으로 되돌림 (Edit 도구)
#    Hunk A는 그대로 유지

# 2. split 실행 — 이 파일 + 관련 다른 파일들을 첫 커밋으로
jj split -m "feat: hunk A 관련 변경" path/to/settings.json related/file.sh

# 3. working copy(child)에서 Hunk B 재적용
#    Edit 도구로 final 값 다시 설정

# 4. (선택) 추가 split 또는 describe
jj split -m "chore: hunk B 관련 변경" path/to/settings.json
# or
jj describe -m "chore: hunk B 관련 변경"
```

### 연속 split로 레이어 스택 구성

`jj split`을 반복하면 working copy가 "미분류 변경 보관소" 역할을 하며 점진적으로 선형 커밋 스택을 생성한다:

```
main ← C1 (의미 A) ← C2 (의미 B) ← C3 (의미 C) ← @ working copy (나머지 or 빈 상태)
```

각 단계: `jj diff <scope>` 확인 → 해당 scope만 split → 반복. Git의 interactive rebase + stash 조합을 대체한다.

## Why This Matters

1. **jj는 stage 개념이 없다** — Git처럼 `git add -p`로 hunk를 스테이징하는 방법이 없음. 모든 변경은 자동 snapshot되어 working copy 커밋에 즉시 반영.
2. **Non-interactive 요구** — 에이전트/자동화는 TTY 기반 diff editor를 못 씀. `jj split -i` 경로 차단됨.
3. **의미 있는 커밋 히스토리** — 레이어/기술/의미별로 분리된 커밋은 bisect, cherry-pick, revert, PR 리뷰 모두에서 가치가 크다. "작업 끝나면 squash" 패턴은 의미 유실.
4. **jj의 rewrite 친화성을 살림** — jj는 커밋 rewrite가 기본 동작이라 temp-revert → re-apply 패턴이 저비용. op log로 전체 롤백 가능.

## When to Apply

- 한 파일에 의미가 다른 여러 hunk가 섞여 있고, 각각을 별도 커밋으로 분리하고 싶을 때
- `jj split -i` diff editor를 못 쓰는 환경(Claude Code, CI, 자동화 스크립트)
- 이미 working copy에 많은 변경이 누적되어 의미별로 정리하고 싶을 때
- 여러 파일에 걸친 변경도 혼합: 일부 파일은 `jj split <path>`로 단순 분리, 특정 파일만 temp-revert 필요

**쓰지 말아야 할 때**:
- 변경이 단순하고 파일 단위 split으로 충분할 때 — `jj split <path>`만으로 해결
- Interactive 환경에서 이미 `jj split -i`로 편하게 쪼갤 수 있을 때

## Examples

### 실제 세션 사례: default.nix hunk 분리

**원본(main)**:
```nix
{
  imports = [
    ./devops
  ];
}
```

**Working copy (두 작업 혼재)**:
```nix
{
  imports = [
    ./devops
    ./lsp.nix
    ./go.nix
  ];
}
```

**목표**: `./go.nix` 변경만 첫 커밋으로, `./lsp.nix`는 다음 커밋.

```bash
# 1. lsp.nix 줄 임시 제거 (Edit)
#    default.nix 현재: devops + go.nix만 남김

# 2. Go stack split
jj split -m "feat(dev): Go 모던 스택 + LSP/formatter 설정 추가" \
  sharedHome/development/go.nix \
  sharedHome/development/default.nix \
  files/workspace/.config/zed/settings.json \
  files/workspace/.config/helix/languages.toml

# 3. working copy에 lsp.nix import 재적용 (Edit)
#    default.nix 현재: devops + lsp.nix + go.nix (정상 상태)

# 4. LSP bundle split
jj split -m "feat(dev): 공통 LSP 번들 sharedHome 추가" \
  sharedHome/development/lsp.nix \
  sharedHome/development/default.nix
```

결과: 두 커밋 각각 자기완결. `jj show <go-commit>` → `default.nix +1 ./go.nix import`만 표시. `jj show <lsp-commit>` → `default.nix +1 ./lsp.nix import` + `lsp.nix 신규`.

### 주의사항

- **원본값 파악 필수**: `jj diff <file>` 또는 `jj file show -r <parent> <file>`로 원본 확인 후 정확히 원복해야 함. 부정확한 원복은 split 후 diff가 오염됨.
- **순서 고려**: 첫 커밋 = 유지할 변경, 두 번째 커밋(working copy에 재적용) = 원복했던 변경. 체인 순서 반대로 하고 싶으면 `jj rebase`로 재배치.
- **op log 안전망**: 실수해도 `jj op log` → `jj op restore <id>`로 롤백 가능.

## Related

- `docs/solutions/best-practices/jj-review-skill-subagent-diff-strategy-2026-04-03.md` — jj diff를 서브에이전트에 전달하는 별도 기법 (topic 다름, 같은 jj 도메인)
- `~/.claude/CLAUDE.md` VCS 우선순위 — 프로젝트 `.jj` 존재 시 jj 우선
- jj 공식 문서 `jj split --help` — `[FILESETS]` 인자와 `-m` 플래그
