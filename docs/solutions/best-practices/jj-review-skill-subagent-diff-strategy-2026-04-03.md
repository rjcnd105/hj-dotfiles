---
title: jj 리뷰 스킬의 서브에이전트 diff 전달 전략
category: best_practice
date: 2026-04-03
tags:
  - jj
  - code-review
  - subagent
  - skill-authoring
  - token-optimization
severity: medium
component: tooling
root_cause: missing_tooling
resolution_type: tooling_addition
---

# jj 리뷰 스킬의 서브에이전트 diff 전달 전략

## Problem

jj(Jujutsu) 기반 프로젝트에서 compound-engineering:review 에이전트를 활용한 코드 리뷰 스킬을 만들 때, diff를 어떻게 추출하고 서브에이전트에 전달할지, 불필요한 토큰 소모를 어떻게 줄일지 설계가 필요했다.

## Symptoms

- 서브에이전트에 jj 실행을 맡기면 Bash 권한 문제로 실패
- diff 전체를 무조건 전달하면 lock 파일, 빌드 산출물까지 포함되어 토큰 낭비
- Agent tool에 reasoning_effort 파라미터가 없어 에이전트별 비용 조절 불가
- jj는 git과 CLI가 다름 (`-U10` 미지원, `--context N` 사용, revset 문법)

## What Didn't Work

- **서브에이전트에서 jj 직접 실행**: Bash 권한이 메인 세션과 별도로 관리되어 denied. `bypassPermissions` 모드도 서브에이전트의 Bash를 허용하지 않았다.
- **orchestrator agent 패턴**: 메인 → orchestrator agent → review agent 3단 구조. orchestrator가 jj를 실행해야 하는데 역시 Bash 권한 문제 발생.
- **diff 전문 무조건 전달**: lock 파일, 삭제/이동 파일의 diff까지 포함되어 context 낭비.
- **파일 경로만 전달 + Read**: 수정된 파일의 경우 "무엇이 바뀌었는지"를 알 수 없어 이전 상태와 비교 불가.

## Solution

**3단계 필터링 전략:**

1. **메인 세션에서 `jj diff --stat` 실행** → 변경 파일 목록 + 변경 유형 파악
2. **분류**:
   - diff 불필요: 삭제, 이동, lock/빌드 파일 → stat 정보만 전달
   - diff 필요: 새 파일, 수정된 소스 코드
3. **`jj diff <리뷰 대상 파일들>` 실행** → 필터링된 diff만 추출
4. **에이전트 프롬프트에 diff + stat 요약 전달** → 에이전트는 diff로 변경 파악, 필요 시 Read로 주변 맥락 추가

**모델 혼합 전략 (reasoning_effort 대안):**

- `correctness-reviewer`: opus (로직 추론 필요)
- `testing-reviewer`, `maintainability-reviewer`: sonnet (패턴 매칭 위주)
- conditional agents: opus (도메인 전문성 필요)

**jj revset 활용 (부모 bookmark 탐색):**

```bash
# 가장 가까운 조상 bookmark 찾기
jj log -r 'heads(::@- & bookmarks())' --no-graph -T 'bookmarks'

# fork_point 기준 diff
jj diff --from 'fork_point(@ | <parent-bookmark>)' --stat
```

## Why This Works

- **메인 세션이 jj 실행**: Bash 권한 문제 회피. 서브에이전트는 Read/Grep/Glob만 필요.
- **선택적 diff 전달**: lock 파일 수천 줄의 diff가 context에 들어가지 않음.
- **diff + Read 조합**: diff로 "무엇이 바뀌었는지" 알고, Read로 "주변 맥락"을 보충. 양방향 통신 불가 제약을 우회.
- **모델 혼합**: testing/maintainability는 패턴 매칭 성격이 강해 sonnet으로 충분. correctness는 실행 경로 추론이 필요해 opus 가치가 있음.

## Prevention

- 스킬에서 서브에이전트에 Bash 의존 명령을 맡기지 않는다. VCS 명령은 메인 세션이 실행하고 결과를 전달한다.
- jj 명령은 git과 플래그가 다르므로 실제 실행으로 검증한다 (예: `-U10` → `--context 10`).
- diff 전체를 전달하기 전에 stat으로 파일을 분류하고 리뷰 불필요 파일을 제외한다.
