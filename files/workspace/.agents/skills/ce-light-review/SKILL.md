---
name: ce:light-review
description: >-
  4개 핵심 리뷰어(correctness, testing, maintainability, performance)를 사용하는
  경량 코드 리뷰 스킬. 코드 변경의 로직 오류, 테스트 갭, 유지보수성, 성능 이슈를
  리포트 형태로 출력한다. 자동 수정이나 PR 작업은 하지 않는다.
argument-hint: "[PR number, branch name, or empty for current branch]"
---

# Light Review

코드 변경을 4개 핵심 리뷰어로 리뷰하고, 결과를 리포트로 출력한다.

## Reviewers

| 리뷰어 | 에이전트 ID | 초점 |
|---|---|---|
| **Correctness** | `compound-engineering:review:correctness-reviewer` | 로직 오류, 엣지 케이스, 상태 버그, 에러 전파 |
| **Testing** | `compound-engineering:review:testing-reviewer` | 커버리지 갭, 약한 단언, 취약한 테스트 |
| **Maintainability** | `compound-engineering:review:maintainability-reviewer` | 커플링, 복잡성, 네이밍, 죽은 코드, 추상화 부채 |
| **Performance** | `compound-engineering:review:performance-reviewer` | DB 쿼리, 데이터 변환, 캐싱, 비동기, I/O 성능 |

## Severity Scale

| 레벨 | 의미 | 조치 |
|---|---|---|
| **P0** | 치명적 — 장애, 취약점, 데이터 손실 | 머지 전 반드시 수정 |
| **P1** | 높음 — 정상 사용에서 발생 가능한 결함 | 수정 권장 |
| **P2** | 중간 — 엣지 케이스, 성능 후퇴, 유지보수 함정 | 쉬우면 수정 |
| **P3** | 낮음 — 작은 개선 | 사용자 판단 |

## Workflow

### Stage 1: Determine Diff Scope

**인자가 PR 번호 또는 URL인 경우:**

먼저 worktree가 clean한지 확인한다:

```bash
git status --porcelain
```

비어있지 않으면 사용자에게 알린다: "커밋되지 않은 변경이 있습니다. stash하거나 커밋한 후 다시 실행하세요." 진행하지 않는다.

```bash
gh pr checkout <number-or-url>
gh pr view <number-or-url> --json title,body,baseRefName,headRefName,url
```

그 다음 PR의 base 브랜치 기준으로 diff를 계산한다:

```bash
BASE=$(git merge-base HEAD origin/<baseRefName>)
git diff --name-only $BASE
git diff -U10 $BASE
```

**인자가 브랜치 이름인 경우:**

```bash
git checkout <branch>
```

기본 브랜치를 찾아서 diff를 계산한다:

```bash
DEFAULT_BRANCH=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')
# fallback: main 또는 master
BASE=$(git merge-base HEAD origin/$DEFAULT_BRANCH)
git diff --name-only $BASE
git diff -U10 $BASE
```

**인자가 없으면 (현재 브랜치):**

위의 브랜치 모드와 동일하게 현재 브랜치에서 기본 브랜치 대비 diff를 계산한다.

**diff가 비어있으면** 사용자에게 알리고 종료한다.

### Stage 2: Understand Intent

변경의 목적을 파악한다:

- PR 모드: PR 제목, 본문, 링크된 이슈에서 추출
- 브랜치 모드: `git log --oneline ${BASE}..HEAD`에서 추출
- 대화 맥락에서 보충

2-3줄의 intent summary를 작성한다:

```
Intent: 세금 계산을 단순화하기 위해 다단계 요율 조회를 고정 요율로 교체.
면세 처리 엣지 케이스가 후퇴하면 안 됨.
```

이 summary를 모든 리뷰어에게 전달한다.

### Stage 3: Spawn Reviewers

4개 리뷰어를 **병렬로** 서브에이전트로 스폰한다. 각 서브에이전트에 전달할 것:

1. 리뷰어의 역할 설명
2. Intent summary
3. 파일 목록과 diff

각 서브에이전트는 **읽기 전용**이다 — 파일을 수정하지 않는다. JSON 형식으로 findings를 반환한다:

```json
{
  "reviewer": "correctness",
  "findings": [
    {
      "file": "path/to/file",
      "line": 42,
      "title": "Finding title",
      "severity": "P1",
      "confidence": 0.85,
      "description": "What's wrong and how to fix it",
      "evidence": "Code snippet or reasoning"
    }
  ]
}
```

### Stage 4: Merge Findings

1. confidence 0.60 미만은 제거한다
2. 같은 파일, 비슷한 라인(+/-3), 비슷한 제목의 findings를 병합한다 — 가장 높은 severity 유지
3. severity (P0 → P3) → confidence (내림차순) → 파일 경로 → 라인 번호 순으로 정렬한다

### Stage 5: Present Report

```markdown
## Review Report

**Scope:** [변경된 파일 수]개 파일, [추가/삭제 라인 수]
**Intent:** [intent summary]
**Reviewers:** correctness, testing, maintainability, performance

### P0 — Critical
(있으면 나열)

### P1 — High
- **[title]** (`file:line`) — [reviewer]
  [description]

### P2 — Moderate
...

### P3 — Low
...

### Verdict
[Ready to merge / Ready with fixes / Not ready]
(수정이 필요하면 수정 순서 제안)
```

## Quality Gates

리포트를 출력하기 전에 확인한다:

1. **모든 finding이 구체적인 조치를 포함하는가** — "consider" 같은 모호한 표현 대신 구체적 수정 방법을 제시해야 한다
2. **오탐이 없는가** — 주변 코드를 실제로 읽어서 확인했는지. 다른 곳에서 이미 처리된 "버그"를 지적하고 있지 않은지
3. **severity가 적절한가** — 스타일 이슈가 P0이거나, 데이터 손실이 P3이면 안 된다

## After Review

리포트를 출력하면 끝이다. 다음을 하지 않는다:
- 파일 자동 수정
- 커밋, push, PR 생성
- todo 파일 생성
- .context/ 아티팩트 저장
