---
name: ce:light-plan
description: >-
  구조화된 구현 플랜을 빠르게 생성하는 경량 플래닝 스킬. 코드베이스를 직접 탐색하고,
  필요시 외부 문서 리서치를 수행하여 Implementation Units 기반의 실행 가능한 플랜을 작성한다.
  ce:plan과 동일한 출력 형식이므로 ce:work, ce:light-work로 바로 실행 가능하다.
argument-hint: "[feature description or requirements doc path]"
---

# Light Plan

코드베이스를 직접 탐색하고, 필요시 외부 문서를 리서치하여 구조화된 구현 플랜을 작성한다.

이 스킬이 생성하는 플랜은 Implementation Units 기반의 실행 가능한 문서다. 각 Unit은 하나의 atomic commit에 해당하는 작업 단위로, 파일 경로, 접근 방식, 테스트 시나리오, 완료 기준을 포함한다.

## Feature Description

<feature_description> $ARGUMENTS </feature_description>

**입력이 비어 있으면** 사용자에게 물어본다: "무엇을 플랜하고 싶으신가요?"

## Workflow

### 1. Source & Scope

1. `docs/brainstorms/`에서 관련 requirements 문서가 있는지 Glob으로 빠르게 확인한다
2. 있으면 읽고 problem frame, requirements, scope boundaries를 가져온다
3. 없으면 feature description에서 직접 시작한다
4. 불명확한 점이 있으면 **하나만** 질문하고 진행한다

### 2. Direct Code Exploration

Grep/Glob/Read로 관련 코드를 직접 탐색한다. 이 단계를 건너뛰면 코드 기반이 아닌 추측 기반 플랜이 되므로 반드시 수행한다.

1. 변경 대상 파일과 주변 파일을 찾는다
2. 기존 패턴과 컨벤션을 파악한다
3. 관련 테스트 파일을 찾는다
4. `docs/solutions/`에서 관련 문서가 있으면 참고한다 (Grep으로 키워드 검색)

탐색은 간결하게 — 관련 파일 5-10개 수준이면 충분하다.

### 3. External Research (필요시)

작업이 다음에 해당하면 외부 리서치를 수행한다:
- 코드베이스에 관련 패턴이 없는 새로운 기술 영역
- 보안, 결제, 외부 API 등 고위험 주제
- 프레임워크/라이브러리의 버전별 동작 확인이 필요한 경우

리서치가 필요하다고 판단하면 다음 에이전트를 병렬로 스폰한다:

- `compound-engineering:research:best-practices-researcher` — 업계 모범 사례, 커뮤니티 컨벤션
- `compound-engineering:research:framework-docs-researcher` — 프레임워크/라이브러리 공식 문서, 버전별 제약

코드베이스에 이미 충분한 패턴이 있으면 이 단계를 건너뛴다. 판단을 간단히 공유한다:
- "코드베이스에 충분한 패턴이 있어 외부 리서치 없이 진행합니다."
- "이 부분은 코드베이스에 패턴이 없어 외부 문서를 확인합니다."

### 4. Structure the Plan

**파일 네이밍**: `docs/plans/YYYY-MM-DD-NNN-<type>-<descriptive-name>-plan.md`
- `docs/plans/` 없으면 생성
- 오늘 날짜 기존 파일 확인하여 순번 결정 (001부터, 3자리 zero-pad)
- type은 `feat`, `fix`, `refactor` 중 하나
- descriptive-name은 3-5단어, kebab-case

**Implementation Units 작성**:
- 2-4개의 구현 단위로 분해
- 각 단위는 하나의 의미 있는 변경에 해당
- 의존 순서대로 정렬
- 체크박스 문법(`- [ ]`)으로 진행 추적 가능하게

### 5. Write the Plan

아래 템플릿을 따른다. Optional 표시된 섹션은 해당 플랜에 실질적 가치가 있을 때만 포함한다.

```markdown
---
title: [Plan Title]
type: [feat|fix|refactor]
status: active
date: YYYY-MM-DD
origin: docs/brainstorms/YYYY-MM-DD-<topic>-requirements.md  # 있을 때만
---

# [Plan Title]

## Overview

[무엇을 왜 변경하는지. 1-3문장.]

## Scope Boundaries

- [명시적 비목표나 제외 사항]

## Relevant Code and Patterns

- [탐색에서 발견한 기존 파일, 패턴, 컨벤션]

## External References (optional)

- [외부 리서치에서 얻은 참고 문서나 모범 사례]

## Key Technical Decisions

- [결정]: [근거]

## Implementation Units

- [ ] **Unit 1: [Name]**

  **Goal:** [이 단위가 달성하는 것]

  **Dependencies:** [None / Unit N / 외부 전제조건]

  **Files:**
  - Create: `path/to/new_file`
  - Modify: `path/to/existing_file`
  - Test: `path/to/test_file`

  **Approach:**
  - [핵심 설계/순서 결정]

  **Patterns to follow:**
  - [기존 코드에서 따를 패턴이나 파일]

  **Test scenarios:**
  - [구체적 시나리오와 기대 동작]
  - [엣지 케이스나 실패 경로]

  **Verification:**
  - [이 단위가 완료되었음을 확인하는 기준]

## Risks (optional)

- [의미 있는 리스크, 의존성, 순서 관련 우려]

## Open Questions (optional)

- [플랜 작성 중 해결하지 못한 질문과 이유]
```

### 6. Save and Report

1. `docs/plans/`에 파일을 저장한다
2. 저장 경로를 출력한다: `Plan written to docs/plans/[filename]`

## Rules

- 로컬 리서치 서브에이전트(repo-research-analyst, learnings-researcher, spec-flow-analyzer)를 스폰하지 않는다. 외부 리서치 에이전트(best-practices-researcher, framework-docs-researcher)는 Step 3에서 필요시 스폰할 수 있다
- 코드 탐색 단계(Step 2)를 건너뛰지 않는다
- 구현 코드를 포함하지 않는다 (import문, 메서드 시그니처, 프레임워크 문법 등)
- git 명령어, 커밋 메시지, 테스트 실행 레시피를 포함하지 않는다
- 플랜 작성 후 옵션 메뉴를 제시하지 않는다 — 저장하고 경로를 알리면 끝이다
