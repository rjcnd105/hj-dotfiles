# Maintenance

## 설계 의도

jj(Jujutsu) 워크플로에서 compound-engineering:review 에이전트를 활용한 코드 리뷰 자동화.
git 기반 ce-light-review의 jj 대응 버전이되, 에이전트를 diff 내용에 따라 동적으로 선택한다.

## 제약사항

- Agent tool에 `reasoning_effort` 파라미터가 없어 `model` 선택으로 대체
  - correctness-reviewer: opus (깊은 추론 필요)
  - testing/maintainability/project-standards: sonnet (패턴 매칭 위주)
  - conditional agents: opus (도메인 전문성 필요)

## 수정 제약

- review-agents.md의 에이전트 목록은 compound-engineering:review:* 에이전트 변경 시 동기화 필요
- findings JSON 스키마는 ce-light-review와 호환 유지

## 피드백 이력

- 2026-04-03: 초기 버전. always-on 3개 + conditional 동적 선택 구조로 시작. sonnet/opus 혼합 전략 채택.
