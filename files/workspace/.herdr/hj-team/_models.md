# Model Profiles (`_models.md`)

`_routes.json`의 역할-모델 배정 근거를 기록하는 운영자 문서다. 새 모델이 나오거나 체감이 바뀌면 `hc-team` 스킬의 갱신 절차에 따라 이 파일과 `_routes.json`을 함께 고친다.

## claude-fable-5-2 (`claude --model claude-fable-5-2 --effort xhigh|high`)  확인: 2026-11-21
- 강점: 아키텍처 설계, 복잡한 시스템 계획 수립, 트레이드오프 판단, 모션·UI 감각 리뷰 [커뮤니티 + 로컬]
- 약점: 고비용, 상대적으로 느린 응답 속도 [커뮤니티]
- 쓰는 route: `plan` (`xhigh`), `design-review` (`high`)

## claude-opus-5-5 (`claude --model claude-opus-5-5 --effort high`)  확인: 2026-11-21
- 강점: 터미널 중심 다중 턴 상태 추적, 복잡한 리팩터링·원인 조사, Aseprite 픽셀 아트(ADR-0059) [커뮤니티 + 로컬]
- 약점: 일상 단순 구현에 쓰기에는 비용이 높음 [커뮤니티]
- 쓰는 route: `investigate`, `pixel-art`

## gpt-6.2-astra (`codex -m gpt-6.2-astra -c model_reasoning_effort="xhigh"`)  확인: 2026-11-21
- 강점: 고복잡도 심층 분석, 다중 파일 정밀 디버깅, 적대적 코드 리뷰, 명시된 제약의 엄격한 준수 [커뮤니티 + 로컬]
- 약점: 열린 계획 수립이나 제약이 느슨한 기획 작업에서는 과도하게 문자 그대로 해석하거나 문맥을 가정하는 경향, 높은 토큰 비용 [커뮤니티 + 로컬]
- 쓰는 route: `deep-review`

## gpt-6.2-sol (`pi --provider openai --model gpt-6.2-sol --thinking high`)  확인: 2026-11-21
- 강점: 빠르고 안정적인 구현·테스트 루프, Astra 대비 약 25% 토큰 비용의 높은 효율 [커뮤니티 + 로컬]
- 약점: 초고난도 교차 시스템 버그에서는 Astra/Fable로 에스컬레이션 필요 [커뮤니티]
- 쓰는 route: `implement`

## gemini-4-neon-high (`agy --model gemini-4-neon-high`)  확인: 2026-11-21
- 강점: 1M 장문 컨텍스트, 빠른 단계 수렴, 멀티모달 브라우저·게임 화면 검증, 낮은 에이전트 세션 비용 [커뮤니티]
- 약점: 20턴 이상의 깊은 다중 파일 디버깅에서는 Opus/Astra 대비 다소 약함 [커뮤니티]
- 쓰는 route: `browser-qa`

## 관찰 로그
- 2026-11-21 `plan`: `claude-fable-5-2`가 `hc-team` 설계 검토에서 P0 8건을 사전 차단하고 `_routes.json` 분리안을 제시함.
- 2026-11-21 `deep-review`: `codex -m gpt-6.2-astra` `xhigh`가 실측 기반 적대적 리뷰에서 P1 11건·P2 24건을 정확히 탐지함.
- 2026-11-21 `implement`: `pi` `gpt-6.2-sol` 4개 병렬 레인이 계약대로 CLI/Mod/Skill을 빠르게 구현함.
