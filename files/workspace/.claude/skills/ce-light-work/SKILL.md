---
name: ce:light-work
description: >-
  구현 플랜을 읽고 체계적으로 실행하는 경량 실행 스킬. 플랜의 Implementation Units를
  태스크로 분해하고, 순서대로 실행하며, 테스트와 증분 커밋을 수행한다.
  PR 생성이나 shipping은 포함하지 않는다 — 실행과 커밋까지만 담당한다.
argument-hint: "[plan file path]"
---

# Light Work

구현 플랜을 읽고 체계적으로 실행한다. 플랜의 Implementation Units를 태스크로 분해하고, 각 태스크를 순서대로 실행하면서 테스트와 증분 커밋을 수행한다.

이 스킬은 실행과 커밋까지만 담당한다. PR 생성, 브랜치 push, 코드 리뷰는 사용자가 직접 처리한다.

## Input Document

<input_document> $ARGUMENTS </input_document>

**입력이 비어 있으면** 사용자에게 물어본다: "실행할 플랜 파일 경로를 알려주세요."

## Workflow

### Phase 1: Read and Prepare

1. **플랜 읽기**
   - 플랜 문서를 완전히 읽는다
   - Implementation Units가 있으면 그것을 실행의 기본 단위로 사용한다
   - 각 Unit의 `Execution note`가 있으면 확인한다 (test-first, characterization-first 등)
   - `Deferred to Implementation` 섹션이 있으면 실행 중 해결해야 할 항목으로 기억한다
   - `Scope Boundaries` 섹션이 있으면 범위를 벗어나지 않도록 참조한다
   - 불명확한 점이 있으면 **지금** 질문한다

2. **현재 브랜치 확인**
   - 이미 feature 브랜치에 있으면 그대로 진행할지 물어본다
   - 기본 브랜치에 있으면 새 브랜치를 만들지 물어본다

3. **태스크 생성**
   - 플랜의 Implementation Units를 태스크로 변환한다
   - 각 Unit의 Goal을 태스크 제목으로, Files/Approach를 설명으로 사용한다
   - 의존 관계를 설정한다
   - 테스트 태스크를 포함한다

### Phase 2: Execute

각 태스크를 순서대로 실행한다:

```
while (태스크 남음):
  - 태스크를 in-progress로 표시
  - 플랜에서 참조한 파일들을 읽는다
  - 기존 패턴을 찾아 따른다 (Patterns to follow 참조)
  - 구현한다
  - 새 기능에 대한 테스트를 작성한다
  - 테스트를 실행한다
  - 태스크를 completed로 표시
  - 증분 커밋 여부를 판단한다
```

**Unit에 `Execution note`가 있으면 따른다:**
- test-first → 실패하는 테스트를 먼저 작성하고, 그 다음 구현
- characterization-first → 기존 동작을 캡처하는 테스트를 먼저 작성하고, 그 다음 변경

**증분 커밋 기준:**

| 커밋할 때 | 커밋하지 않을 때 |
|---|---|
| 논리적 단위 완료 (모델, 서비스, 컴포넌트) | 큰 단위의 일부분만 완료 |
| 테스트 통과 + 의미 있는 진행 | 테스트 실패 중 |
| 컨텍스트 전환 직전 (백엔드 → 프론트엔드) | 순수 스캐폴딩 |

커밋 메시지가 "WIP"나 "partial X"가 된다면 아직 커밋할 때가 아니다.

**패턴 따르기:**
- 플랜의 `Patterns to follow`에 명시된 파일을 먼저 읽는다
- 네이밍 컨벤션을 정확히 맞춘다
- 기존 컴포넌트/유틸을 재사용한다
- 확실하지 않으면 유사한 구현을 grep으로 찾는다

**테스트:**
- 각 변경 후 관련 테스트를 실행한다 — 끝까지 미루지 않는다
- 실패하면 즉시 수정한다
- 새 기능에는 테스트를 추가한다

### Phase 3: Quality Check

PR을 만들기 전에 (사용자가 직접 만듦) 기본 품질을 확인한다:

1. 전체 테스트 통과 (프로젝트의 테스트 명령어 사용)
2. 린트 통과 (프로젝트의 린트 명령어 사용)
3. 코드가 기존 패턴을 따르는지 확인
4. 모든 태스크가 completed인지 확인
5. 플랜에 `Requirements Trace`가 있으면 각 요구사항이 충족되었는지 확인
6. `Deferred to Implementation` 항목이 해결되었는지 확인

### Phase 4: Done

1. 완료된 작업을 요약한다
2. 플랜 파일의 frontmatter `status`를 `completed`로 업데이트한다
3. 후속 작업이 필요하면 언급한다

PR 생성, 브랜치 push, 스크린샷, 배지 등은 하지 않는다.

## Rules

- PR을 생성하지 않는다
- 브랜치를 push하지 않는다
- 스크린샷을 캡처/업로드하지 않는다
- Figma 디자인 싱크를 하지 않는다
- Operational Validation Plan을 작성하지 않는다
- 코드 리뷰 에이전트를 호출하지 않는다
- Swarm Mode / Agent Teams를 사용하지 않는다
- 기본 브랜치에 직접 커밋하지 않는다 — 사용자 확인 필수
