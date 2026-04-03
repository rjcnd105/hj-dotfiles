---
name: jj-review-branch
description: >-
  jj bookmark의 전체 변경사항(부모 bookmark 대비 diff)을 분석하여 적합한
  compound-engineering:review 에이전트를 자동 선택하고 심층 병렬 코드 리뷰를 수행한다.
argument-hint: "[base bookmark, default: 부모 bookmark 자동 탐색]"
---

# jj Review Branch

bookmark 단위의 전체 diff를 compound-engineering:review 에이전트로 심층 리뷰한다.

## Workflow

### 1. Base 결정 및 Diff 추출

**부모 bookmark 탐색 순서:**

1. 인자가 있으면 그것을 base로 사용
2. 없으면 `heads(::@- & bookmarks())` — @의 가장 가까운 조상 bookmark을 자동 탐색
3. 조상 bookmark이 없으면 `trunk()` fallback

찾은 부모 bookmark과의 `fork_point`를 기준으로 diff를 추출한다.

```bash
# Step 1: 부모 bookmark 찾기 (인자 없을 때)
jj log -r 'heads(::@- & bookmarks())' --no-graph -T 'bookmarks ++ "\n"'
# 결과 예시: feature-a  →  이것이 BASE

# Step 2: fork_point 기준 diff
jj log -r 'fork_point(@ | feature-a)..@' --no-graph
jj diff --from 'fork_point(@ | feature-a)' --stat
jj diff --from 'fork_point(@ | feature-a)' -U10
```

diff가 비어있으면 알리고 종료.

### 2. 변경 의도 파악

커밋 이력에서 의도를 추출한다:

```bash
jj log -r 'fork_point(@ | <base>)..@' --no-graph -T 'description ++ "\n---\n"'
```

2-3줄의 intent summary를 작성하여 모든 에이전트에 전달한다.

### 3. 에이전트 선택

diff의 파일 확장자, 변경 영역, 변경 규모를 분석하여 에이전트를 선택한다.
선택 기준은 [references/review-agents.md](references/review-agents.md) 참조.

**Always-on** (항상 실행):
- `correctness-reviewer` — **opus**
- `testing-reviewer` — sonnet
- `maintainability-reviewer` — sonnet
- `project-standards-reviewer` — sonnet

**Conditional**: diff 내용에 해당하는 에이전트를 **빠짐없이** 추가한다 (opus).
branch 리뷰는 전체 변경을 포괄하므로, 조건 만족 시 반드시 포함.

### 4. 에이전트 스폰

선택된 에이전트를 **전부 병렬로** Agent tool로 스폰:

- `subagent_type`: `compound-engineering:review:<agent-name>`
- `model`: 에이전트별 지정 (위 표 참조)
- 전달 정보: intent summary, 커밋 이력, 파일 목록, diff 전문

각 에이전트는 **읽기 전용**. JSON findings 반환 (jj-review와 동일 스키마).

### 5. 결과 병합 및 리포트

1. confidence < 0.60 제거
2. 같은 파일, 유사 라인(+-3), 유사 제목 findings 병합 — 최고 severity 유지
3. severity -> confidence -> 파일 -> 라인 순 정렬

```markdown
## Branch Review Report

**Scope:** [파일 수]개 파일, [추가/삭제], [커밋 수]개 커밋
**Branch:** [bookmark name] <- [base bookmark]
**Intent:** [intent summary]
**Reviewers:** [에이전트 목록]

### P0 — Critical
### P1 — High
### P2 — Moderate
### P3 — Low

### Verdict
[Ready to merge / Ready with fixes / Not ready]
(수정 필요 시 우선순위별 수정 순서 제안)
```

리포트 출력 후 종료. 파일 수정, 커밋, PR 생성 하지 않는다.

## Severity Scale

| 레벨 | 의미 |
|---|---|
| **P0** | 치명적 — 장애, 취약점, 데이터 손실 |
| **P1** | 높음 — 정상 사용에서 발생 가능한 결함 |
| **P2** | 중간 — 엣지 케이스, 성능 후퇴 |
| **P3** | 낮음 — 작은 개선 |
