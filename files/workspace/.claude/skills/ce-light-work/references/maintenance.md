# ce:light-work Maintenance Guide

이 문서는 ce:light-work 스킬을 수정하는 에이전트를 위한 설계 맥락 문서다. 런타임에 로드되지 않는다.

## 설계 의도

compound-engineering의 ce:work는 실행 후 PR 생성, 스크린샷 캡처/업로드, Operational Validation Plan 작성, Compound Engineering 배지 삽입, Swarm Mode 등 shipping 관련 기능이 많다. 사용자는 PR을 직접 만들기를 원하므로 실행과 커밋까지만 담당하는 경량 버전을 만들었다.

## 원본 스킬 경로

```
~/.claude/plugins/cache/compound-engineering-plugin/compound-engineering/*/skills/ce-work/SKILL.md
```

## 제거한 것과 이유

| 제거 항목 | 이유 |
|---|---|
| Phase 4: Ship It 전체 (커밋 포맷, 스크린샷, PR 생성, 배지) | 사용자가 PR을 직접 처리. 가장 큰 토큰 절약 |
| Figma Design Sync | 이 사용자의 워크플로우에서 불필요 |
| Swarm Mode / Agent Teams | 대규모 협업 기능. light에서 불필요 |
| Operational Validation Plan | PR 관련 기능이므로 함께 제거 |
| Phase 3.2: ce:review 연동 | 리뷰는 별도로 ce:light-review를 사용 |
| System-Wide Test Check 5개 질문 매트릭스 | 핵심 루프에서 과도한 절차. 테스트 실행으로 충분 |
| Simplify as You Go | 별도 리팩토링은 사용자 판단 |
| Subagent dispatch 전략의 상세 가이드 | 기본 실행으로 충분 |

## 반드시 유지할 것

1. **플랜 읽기 + 태스크 분해** — Implementation Units를 태스크로 변환하는 것이 핵심
2. **태스크 실행 루프** — 순서대로 실행, 패턴 따르기, 테스트, 완료 표시
3. **증분 커밋** — 논리적 단위별 커밋 판단 기준
4. **Execution note 존중** — test-first, characterization-first 등 플랜의 실행 자세를 따름
5. **Deferred to Implementation 확인** — 플랜이 남긴 미해결 항목을 실행 중 해결
6. **Quality Check** — 테스트 + 린트 최소 확인
7. **플랜 status 업데이트** — 완료 시 frontmatter를 completed로 변경

## 수정 시 제약

1. **PR 관련 기능을 추가하지 않는다** — PR 생성이 필요하면 ce:work를 쓰거나 사용자가 직접 한다
2. **출력 형식 호환성** — ce:plan, ce:light-plan이 생성한 플랜을 모두 읽을 수 있어야 한다. Implementation Units 구조를 전제로 한다
3. **self-contained** — ce:work를 알고 있다고 전제하지 않는다
4. **description에 트리거 문구를 넣지 않는다**

## 사용자 피드백 이력 (2026-03-27 ~ 2026-03-30)

- PR은 사용자가 직접 한다 — Phase 4 (Ship It) 전부 제거
- Figma sync, Swarm Mode, 스크린샷/이미지 업로드 제거
- Operational Validation Plan 제거
- ce:review 연동 제거
- 핵심 루프(read plan → tasks → execute → test → commit)는 온전히 유지해야 한다
