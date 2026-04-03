# Review Agents 선택 기준

## Always-on

| 에이전트 | model | 초점 |
|---|---|---|
| `correctness-reviewer` | opus | 로직 오류, 엣지 케이스, 상태 버그, 에러 전파 |
| `testing-reviewer` | sonnet | 커버리지 갭, 약한 단언, 취약한 테스트 |
| `maintainability-reviewer` | sonnet | 커플링, 복잡성, 네이밍, 죽은 코드 |

`jj-review-branch` 추가:

| `project-standards-reviewer` | sonnet | CLAUDE.md/AGENTS.md 기준 준수 |

## Conditional

diff 분석 결과 해당 조건을 만족할 때만 추가. 모두 **opus**.

### 언어별

| 조건 | 에이전트 |
|---|---|
| `.py` 파일 변경 | `kieran-python-reviewer` |
| `.ts`/`.tsx` 파일 변경 | `kieran-typescript-reviewer` |

### 도메인별

| 조건 | 에이전트 |
|---|---|
| auth, 권한, 사용자 입력 처리 | `security-reviewer` |
| DB 쿼리, 루프, 캐싱, I/O 경로 | `performance-reviewer` |
| 에러 핸들링, 재시도, 타임아웃, 비동기 | `reliability-reviewer` |
| API 라우트, 요청/응답 타입, 직렬화 | `api-contract-reviewer` |
| 마이그레이션, 스키마 변경, 데이터 변환 | `data-migrations-reviewer` |
| async UI, Stimulus/Turbo, DOM 타이밍 | `julik-frontend-races-reviewer` |
| 에이전트 도구, 시스템 프롬프트 | `agent-native-reviewer` |

### 규모/위험 기반

| 조건 | 에이전트 |
|---|---|
| >=50 변경 라인 OR auth/payments/data mutations/외부 API | `adversarial-reviewer` |
