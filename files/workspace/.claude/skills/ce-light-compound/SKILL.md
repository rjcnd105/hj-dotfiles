---
name: ce:light-compound
description: >-
  최근 해결한 문제를 docs/solutions/에 구조화된 문서로 기록하는 경량 문서화 스킬.
  서브에이전트 없이 대화 맥락에서 직접 문제와 해결책을 추출하고, YAML frontmatter가
  포함된 검색 가능한 솔루션 문서를 생성한다.
argument-hint: "[optional: brief context about the fix]"
---

# Light Compound

최근 해결한 문제를 `docs/solutions/`에 구조화된 문서로 기록한다. 서브에이전트를 사용하지 않고, 대화 맥락에서 직접 문제와 해결책을 추출하여 single-pass로 문서를 작성한다.

## Usage

```
/ce:light-compound                    # 가장 최근 해결한 문제를 문서화
/ce:light-compound [brief context]    # 추가 맥락 제공
```

## Preconditions

- 문제가 해결된 상태여야 한다 (진행 중이면 안 됨)
- 해결책이 검증되었어야 한다
- 사소한 문제(단순 오타, 명백한 실수)가 아니어야 한다

## Workflow

### 1. Extract from Conversation

대화 이력에서 다음을 추출한다:

- **문제**: 무엇이 잘못되었는지 (에러 메시지, 관찰된 동작)
- **조사 과정**: 시도했지만 실패한 접근들
- **근본 원인**: 왜 문제가 발생했는지
- **해결책**: 실제 수정 내용 (코드 예시 포함)
- **예방책**: 재발 방지 방법

### 2. Classify

**problem_type 결정** (아래 중 하나):

| problem_type | 디렉토리 |
|---|---|
| build_error | build-errors/ |
| test_failure | test-failures/ |
| runtime_error | runtime-errors/ |
| performance_issue | performance-issues/ |
| database_issue | database-issues/ |
| security_issue | security-issues/ |
| ui_bug | ui-bugs/ |
| integration_issue | integration-issues/ |
| logic_error | logic-errors/ |
| developer_experience | developer-experience/ |
| workflow_issue | workflow-issues/ |
| best_practice | best-practices/ |
| documentation_gap | documentation-gaps/ |

**파일명**: `[sanitized-problem-slug]-[YYYY-MM-DD].md`

### 3. Search Existing Docs

`docs/solutions/`에서 관련 기존 문서를 Grep으로 검색한다. 이 단계를 건너뛰면 중복 문서가 생길 수 있다.

1. 문제 맥락에서 키워드를 추출한다 (모듈명, 기술 용어, 에러 메시지)
2. 카테고리가 명확하면 해당 디렉토리 내에서 검색한다
3. Grep으로 frontmatter의 title, tags를 검색한다
4. 후보가 있으면 frontmatter(첫 30줄)만 읽어 관련성을 판단한다
5. 관련 문서가 있으면 `## Related` 섹션에 링크한다

### 4. Write Document

```markdown
---
title: [Problem title]
category: [problem_type]
date: YYYY-MM-DD
tags:
  - [tag1]
  - [tag2]
severity: [critical|high|medium|low]
component: [affected component]
root_cause: [root cause type]
resolution_type: [resolution type]
---

# [Problem title]

## Problem

[1-2문장. 무엇이 잘못되었는지.]

## Symptoms

- [관찰된 증상, 에러 메시지]

## What Didn't Work

- [시도했지만 실패한 접근과 실패 이유]

## Solution

[실제 수정 내용. before/after 코드 예시 포함.]

## Why This Works

[근본 원인 설명과 해결책이 그것을 어떻게 해결하는지.]

## Prevention

- [재발 방지 전략, 모범 사례, 테스트 케이스]

## Related

- [기존 관련 문서 링크 (있으면)]
```

**YAML frontmatter 필드 값 (검증용):**

- **component**: rails_model, rails_controller, rails_view, service_object, background_job, database, frontend_stimulus, hotwire_turbo, email_processing, brief_system, assistant, authentication, payments, development_workflow, testing_framework, documentation, tooling
- **root_cause**: missing_association, missing_include, missing_index, wrong_api, scope_issue, thread_violation, async_timing, memory_leak, config_error, logic_error, test_isolation, missing_validation, missing_permission, missing_workflow_step, inadequate_documentation, missing_tooling, incomplete_setup
- **resolution_type**: code_fix, migration, config_change, test_fix, dependency_update, environment_setup, workflow_improvement, documentation_update, tooling_addition, seed_data_update

### 5. Save and Report

1. 디렉토리가 없으면 생성: `docs/solutions/[category]/`
2. 파일을 저장한다
3. 결과를 출력한다:

```
Documentation complete.

File created:
- docs/solutions/[category]/[filename].md

Related docs found:
- [링크 (있으면)]
```

## Rules

- 서브에이전트를 스폰하지 않는다 (Context Analyzer, Solution Extractor, Related Docs Finder 모두 없음)
- GitHub issue 검색을 하지 않는다
- 외부 fetch(WebFetch, WebSearch)를 하지 않는다
- compound-refresh를 호출하지 않는다
- specialized agent review(performance-oracle, security-sentinel 등)를 하지 않는다
- 기존 문서 Grep 검색 단계를 건너뛰지 않는다
- 대화 맥락에서 추출할 수 없는 내용을 추측으로 채우지 않는다
