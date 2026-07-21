# Maintenance

## 설계 의도

jj(Jujutsu) 워크플로에서 compound-engineering:review 에이전트를 활용한 코드 리뷰 자동화.
git 기반 ce-light-review의 jj 대응 버전이되, 에이전트를 diff 내용에 따라 동적으로 선택한다.

## 제약사항

- Agent tool에 `reasoning_effort` 파라미터 없음 → `model` 선택으로 대체
  - correctness-reviewer: opus (깊은 추론 필요)
  - testing/maintainability/project-standards: sonnet (패턴 매칭 위주)
  - conditional agents: opus (도메인 전문성 필요)
- 서브에이전트에서 jj(Bash) 실행 불가 → 메인 세션이 diff 추출, 결과를 프롬프트로 전달
- Agent 양방향 통신 불가 → diff를 선제적으로 필터링하여 전달

## 수정 제약

- review-agents.md의 에이전트 목록은 compound-engineering:review:* 에이전트 변경 시 동기화 필요
- findings JSON 스키마는 ce-light-review와 호환 유지
- jj CLI 플래그는 git과 다름 (`--context` not `-U`, revset 문법)

## 피드백 이력

- 2026-04-03: 초기 버전. always-on 3개 + conditional 동적 선택. sonnet/opus 혼합 전략.
- 2026-04-03: 테스트 반영. jj `-U10` → `--context` 수정. 서브에이전트 Bash 불가 확인 → 메인 세션 diff 추출 방식으로 전환. stat 기반 파일 분류 + 선택적 diff 전달로 토큰 최적화.
