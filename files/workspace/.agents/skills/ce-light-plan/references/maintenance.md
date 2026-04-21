# ce:light-plan Maintenance Guide

이 문서는 ce:light-plan 스킬을 수정하는 에이전트를 위한 설계 맥락 문서다. 런타임에 로드되지 않는다.

## 설계 의도

compound-engineering 플러그인의 ce:plan은 최소 2개의 로컬 리서치 서브에이전트(repo-research-analyst, learnings-researcher)를 항상 스폰하고, 조건부로 3개를 더 스폰한다. 이 과정이 토큰과 시간의 대부분을 차지한다.

ce:light-plan은 로컬 리서치 서브에이전트를 모두 제거하고, 에이전트가 직접 Grep/Glob/Read로 코드를 탐색하도록 한다. 외부 문서 리서치(best-practices-researcher, framework-docs-researcher)는 유지한다.

## 원본 스킬 경로

```
~/.claude/plugins/cache/compound-engineering-plugin/compound-engineering/*/skills/ce-plan/SKILL.md
```

버전이 업데이트되면 경로의 `*` 부분이 바뀐다.

## 제거한 것과 이유

| 제거 항목 | 이유 |
|---|---|
| `repo-research-analyst` 서브에이전트 | 직접 Grep/Glob으로 대체 가능. 토큰 절약 |
| `learnings-researcher` 서브에이전트 | docs/solutions/ 직접 Grep으로 대체. 토큰 절약 |
| `spec-flow-analyzer` 서브에이전트 | ultra-light 플랜에서 불필요 |
| Plan depth 분류 (Lightweight/Standard/Deep) | 항상 ultra-light 고정. 분류 로직 자체가 불필요 |
| High-Level Technical Design 섹션 | ultra-light에서 불필요 |
| Deep plan extensions (Alternative Approaches, Phased Delivery 등) | ultra-light에서 불필요 |
| Stakeholder and Impact Awareness | ultra-light에서 불필요 |
| Post-generation 옵션 메뉴 (7가지 선택지) | 불필요한 상호작용. 저장 후 바로 종료 |
| Issue Creation (GitHub/Linear 연동) | 사용자가 직접 처리 |
| Execution posture detection | ultra-light에서 불필요 |

## 반드시 유지할 것

이 항목들을 제거하면 "플랜" 스킬이 아니라 "wish-list" 스킬이 된다:

1. **코드 직접 탐색 단계** — 서브에이전트를 없앴으므로 직접 코드를 봐야 함. 이 단계가 빠지면 근거 없는 추측 플랜이 됨
2. **Implementation Units 구조** — Goal, Files, Approach, Patterns to follow, Test scenarios, Verification. 이게 ce:plan/ce:work와의 호환성 핵심
3. **파일 네이밍 컨벤션** — `docs/plans/YYYY-MM-DD-NNN-<type>-<name>-plan.md`
4. **frontmatter** — title, type, status, date. ce:work가 이것으로 플랜을 식별함
5. **외부 리서치 에이전트** — best-practices-researcher, framework-docs-researcher는 유지. 코드베이스에 패턴이 없는 새 기술 영역에서 필수
6. **체크박스 문법** — `- [ ]`로 진행 추적. ce:work가 이걸 업데이트함

## 수정 시 제약

1. **서브에이전트를 추가하지 않는다** — 로컬 리서치 에이전트를 다시 넣으면 ce:plan을 쓰는 것과 차이가 없어진다. 외부 리서치 2개는 이미 포함되어 있으므로 추가 에이전트가 필요하다면 그건 ce:plan의 영역이다
2. **출력 형식을 바꾸지 않는다** — ce:work, ce:light-work가 이 플랜을 읽고 실행하므로, Implementation Units 구조를 변경하면 호환성이 깨진다
3. **self-contained을 유지한다** — 이 스킬을 읽는 에이전트가 ce:plan을 알고 있으리라는 보장이 없다. "ce:plan의 경량 버전"이라는 설명만으로는 부족하다. 워크플로우가 독립적으로 이해 가능해야 한다
4. **description에 트리거 문구를 넣지 않는다** — "간단하게 플랜", "빠르게 플랜" 같은 트리거 패턴을 description에 나열하지 않는다
5. **원본 스킬이 업데이트되면 확인한다** — 원본 ce:plan의 Implementation Units 구조나 frontmatter 스펙이 바뀌면 light 버전도 맞춰야 한다

## 사용자 피드백 이력 (2026-03-27 ~ 2026-03-30)

- best-practices-researcher, framework-docs-researcher는 포함시켜야 한다 (로컬 리서치만 제거)
- description에 트리거 문구("간단하게 플랜", "빠르게 플랜" 등)를 넣지 않는다
- ce:plan을 알고 있다는 전제로 작성하지 않는다 — self-contained 필수
- Plan depth 분류 없이 항상 ultra-light
- 코드 탐색 단계를 건너뛰면 안 된다는 점을 스킬에 명시해야 한다
