# rules-audit Maintenance Guide

이 문서는 rules-audit 스킬을 수정하는 에이전트를 위한 설계 맥락 문서다. 런타임에 로드되지 않는다.

## 설계 의도

사용자는 Hindsight에 세션을 꾸준히 저장하고 `agent-personalization` mental model도 만들었지만, 그 분석 결과를 실제 CLAUDE.md와 rules/ 파일에 반영하는 과정은 완전히 수동이었다. 이 스킬은 그 간극을 메운다.

두 가지 리서치에서 설계 원칙을 도출했다:

### Anthropic "Harness Design for Long-Running Apps" (2026-03-24)
- **Generator-Evaluator 분리**: 자기 작업을 자기가 평가하면 관대해진다. Hindsight의 과거 피드백이 외부 평가자 역할
- **구체적 grading criteria**: 주관적 판단("좋은 rules인가?")을 5가지 객관적 기준으로 분해
- **비필수 scaffolding 제거**: 모델이 이미 잘 하는 것에 대한 규칙은 토큰 낭비. Relevance 기준으로 감지
- **Sprint contract**: 변경 전에 사용자와 기준을 합의 → 제안을 보여주고 승인을 받는 구조

### Bilevel Autoresearch (2026-03-24)
- **Bilevel 구조**: Inner loop(에이전트가 rules 따르며 작업) + Outer loop(rules 자체를 개선) = 이 스킬
- **LLM blind spot**: 에이전트가 스스로 rules를 개선하면 blind spot 유지. Hindsight 피드백이 blind spot을 깨는 외부 mechanism
- **Level 1.5 vs Level 2**: 문구 다듬기(1.5)보다 구조/방향 변경(2)이 효과적 → 단순 수정보다 삭제/추가/구조 변경 제안
- **Validate-and-revert**: 변경 전 백업, 변경 후 검증 → 사용자 승인 구조로 구현

## 반드시 유지할 것

1. **5가지 Grading Criteria** — Effectiveness, Conciseness, Coherence, Relevance, Specificity. 이것이 스킬의 핵심 평가 프레임워크
2. **Hindsight graceful degradation** — env 없으면 정적 분석만. 두 경우 모두 동작해야 함
3. **사용자 승인 필수** — 절대 자동으로 rules를 변경하지 않음
4. **구체적 제안** — 파일 경로, 라인, 변경 내용을 명시. "개선하세요"는 금지
5. **150 directive 제한 체크** — 사용자의 명시적 요구사항
6. **서브에이전트 없음** — 경량 스킬 원칙

## 수정 시 제약

1. **grading criteria를 제거하지 않는다** — 추가는 가능하지만 기존 5개는 리서치 기반 설계
2. **Hindsight를 필수 의존성으로 만들지 않는다** — 정적 분석만으로도 가치를 제공해야 함
3. **자동 적용 기능을 추가하지 않는다** — 사용자 승인은 safety mechanism
4. **서브에이전트를 추가하지 않는다** — 경량 유지
5. **description에 트리거 문구를 넣지 않는다**

## Hindsight 연동 상세

- `agent-personalization` mental model을 우선 조회 (즉시 응답, 토큰 절약)
- mental model이 없으면 reflect로 fall back
- Hindsight 데이터는 "이 규칙이 실제로 작동하는가?"를 판단하는 외부 증거로만 사용
- Hindsight 데이터만으로 규칙을 추가/삭제 결정하지 않음 — 항상 사용자에게 제안

## 사용자 피드백 이력 (2026-03-30)

- CLAUDE.md/rules를 분석하고 개선하는 전용 스킬이 없었음 → 이 스킬을 만든 이유
- compound-engineering에도 이런 스킬이 없음을 확인
- Hindsight의 mental model을 활용하되, 토큰 비용을 최소화해야 함 (mental model 우선, reflect는 fall back)
- Anthropic harness design 글과 bilevel autoresearch 논문에서 설계 원칙 도출
- 기존 rules에서 중복 제거, 충돌 감지, 사문화 규칙 감지, 누락 규칙 추가가 핵심 요구사항
- "에이전트가 자기 규칙을 자기가 평가하면 blind spot이 유지된다" — Hindsight가 외부 평가자 역할
