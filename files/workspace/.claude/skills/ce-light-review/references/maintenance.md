# ce:light-review Maintenance Guide

이 문서는 ce:light-review 스킬을 수정하는 에이전트를 위한 설계 맥락 문서다. 런타임에 로드되지 않는다.

## 설계 의도

compound-engineering의 ce:review는 최대 13+개의 리뷰어 페르소나를 스폰하고, confidence-gated dedup, autofix cycle, artifact 저장, todo 생성 등 복잡한 후처리를 수행한다. 대부분의 일상적인 리뷰에서는 핵심 4개 리뷰어면 충분하다.

## 원본 스킬 경로

```
~/.claude/plugins/cache/compound-engineering-plugin/compound-engineering/*/skills/ce-review/SKILL.md
```

원본은 `references/` 디렉토리에 persona-catalog.md, subagent-template.md, diff-scope.md, findings-schema.json, review-output-template.md 등 다수의 참조 파일을 포함한다.

## 리뷰어 선택 근거

| 유지 | 제거 | 이유 |
|---|---|---|
| correctness | security | 사용자가 명시적으로 제외 |
| testing | api-contract | conditional — light에서 불필요 |
| maintainability | data-migrations | conditional — light에서 불필요 |
| performance | reliability | conditional — light에서 불필요 |
| | dhh-rails, kieran-rails/python/ts | stack-specific — light에서 불필요 |
| | julik-frontend-races | stack-specific — light에서 불필요 |
| | agent-native-reviewer | CE always-on — light에서 불필요 |
| | learnings-researcher | CE always-on — light에서 불필요 |
| | schema-drift-detector | CE conditional — light에서 불필요 |
| | deployment-verification-agent | CE conditional — light에서 불필요 |

**security를 제거한 이유**: 사용자가 "키워드 기반으로 하지 말고 performance review만 포함해줘"라고 명시적으로 요청했다. security를 conditional로 포함하는 방안을 제안했으나 거부됨. 보안 리뷰가 필요하면 원본 ce:review를 사용한다.

## 제거한 것과 이유

| 제거 항목 | 이유 |
|---|---|
| 9개 conditional/stack-specific/CE 리뷰어 | 핵심 4개로 충분. 가장 큰 토큰 절약 |
| Autofix 모드 | 리포트만 출력하는 경량 버전 |
| Report-only 모드 | 모드 분기 자체가 불필요. 항상 interactive |
| After Review fix cycle (fixer subagent, bounded rounds) | 리포트 출력 후 끝 |
| Todo 파일 생성 | 사용자가 직접 처리 |
| .context/ artifact 저장 | 불필요한 파일 생성 |
| Protected Artifacts 로직 | 해당 리뷰어가 없으므로 불필요 |
| Action routing (safe_auto, gated_auto, manual, advisory) | 수정을 안 하므로 routing 불필요 |
| 복잡한 PR base ref 해결 로직 (~100줄) | 간소화된 git merge-base로 충분 |
| Language-Aware Conditionals | conditional 리뷰어가 없으므로 불필요 |

## 반드시 유지할 것

1. **4개 리뷰어 병렬 스폰** — 이것이 "리뷰" 스킬의 핵심. 리뷰어를 줄이면 역할 자체가 약화됨
2. **Diff scope 결정** — PR/브랜치/현재 브랜치 3가지 입력 모드
3. **Intent discovery** — 리뷰어에게 변경 목적을 전달해야 정확한 리뷰 가능
4. **Severity scale (P0-P3)** — 표준화된 심각도 분류
5. **Confidence gate (0.60)** — 노이즈 필터링
6. **Findings dedup** — 여러 리뷰어가 같은 이슈를 찾을 수 있으므로 병합 필요
7. **Quality Gates** — 오탐 검증, actionable 확인, severity 적절성

## 수정 시 제약

1. **리뷰어를 추가하려면 신중하게** — 리뷰어 하나가 서브에이전트 하나다. 5개 이상이면 ce:review를 쓰는 게 낫다
2. **autofix를 추가하지 않는다** — 자동 수정이 필요하면 ce:review의 autofix 모드를 사용한다
3. **self-contained** — ce:review를 알고 있다고 전제하지 않는다. 리뷰어 에이전트 ID는 스킬에 명시되어 있어야 한다
4. **description에 트리거 문구를 넣지 않는다**
5. **리포트 출력 후 추가 작업을 하지 않는다** — fix cycle, todo, artifact 모두 없음

## 사용자 피드백 이력 (2026-03-27 ~ 2026-03-30)

- 리뷰어 4개: correctness, testing, maintainability, performance
- security는 명시적으로 제외됨 (키워드 기반 conditional 방안도 거부)
- Autofix/Report-only 모드 제거 — Interactive 리포트만
- After Review fix cycle 제거 — 리포트 출력 후 끝
- 복잡한 base ref 해결 로직 간소화
