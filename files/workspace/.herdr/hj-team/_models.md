# Model Profiles (`_models.md`)

`_routes.json`의 역할-모델 배정 근거를 기록하는 운영자 문서다. 새 모델이 나오거나 체감이 바뀌면 `hc-team` 스킬의 갱신 절차에 따라 이 파일과 `_routes.json`을 함께 고친다.

## claude-fable-5-2 (`claude --model claude-fable-5-2 --effort xhigh|high`)  확인: 2026-11-23
- 강점: 시스템 전체 아키텍처 설계, 다단계 계획 수립, 트레이드오프 판단, 모션·UI 완성도 판정 [커뮤니티 + 로컬]
- 약점: 고비용 및 5시간 구독 한도 소모가 매우 빠름 — 일상 구현이나 반복 작업에 남발 금지 [커뮤니티]
- 쓰는 route: `plan` (`xhigh`), `design-review` (`high`, Neon 구현과의 이종 교차 리뷰)

## claude-opus-5-5 (`claude --model claude-opus-5-5 --effort high`)  확인: 2026-11-23
- 강점: 터미널 중심 다중 턴 상태 추적, 안정적인 다중 파일 원인 분석·리팩터링, 픽셀 아트 제작(Fable 대비 절반 단가) [커뮤니티 + 로컬]
- 약점: 단순 정형 구현 워커로는 GPT-6.2 Sol 대비 비용 부담 [커뮤니티]
- 쓰는 route: `investigate`, `pixel-art`

## gpt-6.2-astra (`codex -m gpt-6.2-astra` / `pi --provider openai --model gpt-6.2-astra`)  확인: 2026-11-23
- 강점: 복잡한 다중 파일 구현·리팩터링·상태 머신·3D/게임 로직, 적대적 코드 리뷰에서의 실제 결함(verified defects) 탐지 최상위. **Fable 5.2보다 실체감 비용·구독 쿼터 효율이 훨씬 우수**하므로, 토큰이 많이 들지만 태스크·계약이 어느 정도 정해진 복잡한 작업에서는 Fable 5.2보다 Astra를 우선 선택 [커뮤니티 + 로컬]
- 약점: 창의적 탐색·열린 기획·오케스트레이션·의도 파악이 약함("문자 그대로 해석" 경향), 리뷰 시 과잉 지적(false positive)과 same-lab bias 비율이 높음, Sol 대비 단가는 높음 [커뮤니티 + 로컬]
- 쓰는 route: `implement-complex` (`pi`, `high`), `deep-review` (`codex`, `xhigh`, read-only)

## gpt-6.2-sol (`pi --provider openai --model gpt-6.2-sol --thinking high`)  확인: 2026-11-23
- 강점: 스펙과 계약이 명확히 주어진 정형 코딩·리팩터링·반복 테스트 워커로 최고 가성비(Astra 대비 ~25% 비용) [커뮤니티 + 로컬]
- 약점: 창의적 아이디어·UX 감각·열린 기획·오케스트레이션과 모호한 의도 파악이 매우 약함. 선행 플래너/트리아지가 범위를 고정한 뒤 실행 워커로만 투입 [커뮤니티 + 로컬]
- 쓰는 route: `implement`

## gemini-4-neon (`agy --model gemini-4-neon-high|medium`)  확인: 2026-11-23
- 강점: 사람 같은 자연스러운 UX 직관·창의적 UI/모션 변형 탐색·사용자 여정 설계·코드 블로트 제거, 1M 컨텍스트와 멀티모달 화면 이해(`Neon high`가 `Opus 5.5 high` 상회 평가 다수) [커뮤니티]
- 약점: Pro 플랜 구독 쿼터 소모가 빠름, 하네스 의존성이 큼, 일부 특수 로컬 MCP 연동에서 투박한 사례 [커뮤니티]
- 쓰는 route: `creative-dev` (`high`), `ux-ideate` (`high`), `browser-qa` (`medium`, 반복 QA 쿼터 절약)

## 관찰 로그
- 2026-11-21 `plan`: `claude-fable-5-2`가 `hc-team` 설계 검토에서 P0 8건을 사전 차단하고 `_routes.json` 분리안을 제시함.
- 2026-11-21 `deep-review`: `codex -m gpt-6.2-astra` `xhigh`가 실측 기반 적대적 리뷰에서 P1 11건·P2 24건을 정확히 탐지함.
- 2026-11-21 `implement`: `pi` `gpt-6.2-sol` 4개 병렬 레인이 계약대로 CLI/Mod/Skill을 빠르게 구현함.
- 2026-11-23 X·Reddit 재검토: GPT-6.2 Sol/Astra의 의도 파악·창의성 약점과 Astra의 false positive 경향, Gemini 4 Neon의 UX/창의 강점 및 쿼터 특성을 반영해 `creative-dev`·`ux-ideate`(Neon High), `implement-complex`(Astra High), `browser-qa`(Neon Medium)로 역할을 재분리함.
