---
name: jj-review
description: >-
  jj revision의 변경사항을 분석하여 적합한 compound-engineering:review 에이전트를
  자동 선택하고 병렬 코드 리뷰를 수행한다.
argument-hint: "[revision, default: @]"
---

# jj Review

jj revision의 diff를 compound-engineering:review 에이전트로 리뷰한다.

## Workflow

### 1. Diff 추출

```bash
REV="${ARG:-@}"
jj diff -r "$REV" --stat
jj diff -r "$REV" -U10
```

diff가 비어있으면 알리고 종료.

### 2. 에이전트 선택

diff의 파일 확장자, 변경 영역, 변경 규모를 분석하여 에이전트를 선택한다.
선택 기준은 [references/review-agents.md](references/review-agents.md) 참조.

**Always-on** (항상 실행):
- `correctness-reviewer` — **opus**
- `testing-reviewer` — sonnet
- `maintainability-reviewer` — sonnet

**Conditional**: diff 내용에 해당하는 에이전트만 추가 (opus).

### 3. 에이전트 스폰

선택된 에이전트를 **전부 병렬로** Agent tool로 스폰:

- `subagent_type`: `compound-engineering:review:<agent-name>`
- `model`: 에이전트별 지정 (위 표 참조)
- 전달 정보: 파일 목록, diff 전문, 변경 의도 요약

각 에이전트는 **읽기 전용**. JSON으로 findings 반환:

```json
{
  "reviewer": "<agent-name>",
  "findings": [
    {
      "file": "path/to/file",
      "line": 42,
      "title": "제목",
      "severity": "P0|P1|P2|P3",
      "confidence": 0.85,
      "description": "문제와 수정 방법",
      "evidence": "코드 또는 근거"
    }
  ]
}
```

### 4. 결과 병합 및 리포트

1. confidence < 0.60 제거
2. 같은 파일, 유사 라인(+-3), 유사 제목 findings 병합 — 최고 severity 유지
3. severity -> confidence -> 파일 -> 라인 순 정렬

```markdown
## Review Report

**Scope:** [파일 수]개 파일, [추가/삭제]
**Revision:** [revision ID]
**Reviewers:** [에이전트 목록]

### P0 — Critical
### P1 — High
### P2 — Moderate
### P3 — Low

### Verdict
[Ready / Ready with fixes / Not ready]
```

리포트 출력 후 종료. 파일 수정, 커밋, PR 생성 하지 않는다.

## Severity Scale

| 레벨 | 의미 |
|---|---|
| **P0** | 치명적 — 장애, 취약점, 데이터 손실 |
| **P1** | 높음 — 정상 사용에서 발생 가능한 결함 |
| **P2** | 중간 — 엣지 케이스, 성능 후퇴 |
| **P3** | 낮음 — 작은 개선 |
