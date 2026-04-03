---
name: rules-audit
description: >-
  CLAUDE.md와 rules/ 파일을 분석하여 중복, 충돌, 사문화된 규칙, 누락된 규칙을 찾고
  구체적인 개선안을 제안하는 스킬. Hindsight 연동 시 과거 사용자 피드백 기반으로
  규칙의 실효성까지 평가한다. 변경은 사용자 승인 후에만 적용한다.
argument-hint: "[optional: scope — global, project, or both]"
---

# Rules Audit

CLAUDE.md와 rules/ 파일을 분석하여 개선안을 제안한다. Hindsight가 설정되어 있으면 과거 피드백 기반으로 규칙의 실효성까지 평가한다.

변경은 사용자 승인 후에만 적용한다.

## Grading Criteria

각 규칙을 5가지 기준으로 평가한다:

| 기준 | 평가 내용 | 가중치 |
|---|---|---|
| **Effectiveness** | 이 규칙이 실제로 에이전트 행동을 개선하는가? 같은 문제가 반복되고 있지 않은가? | 높음 |
| **Conciseness** | 총 directive 수가 150 이하인가? 중복이 있는가? 하나의 규칙이 너무 길지 않은가? | 높음 |
| **Coherence** | 규칙 간 충돌이 없는가? 모순되는 지시가 있지 않은가? | 높음 |
| **Relevance** | 모델이 이미 기본으로 잘 하는 것에 대한 불필요한 scaffolding이 아닌가? | 중간 |
| **Specificity** | 모호한 규칙("좋은 코드를 작성하라") vs 구체적 규칙("Nix에서 longhand/shorthand를 같은 레벨에서 혼용하지 않는다") | 중간 |

근거: Anthropic의 harness design 연구에서 주관적 판단을 구체적 grading criteria로 분해하면 평가가 tractable해진다는 것이 입증되었다. 또한 bilevel autoresearch에서 LLM이 자기 작업을 평가하면 blind spot이 유지되므로, 외부 데이터(Hindsight 피드백)를 평가 근거로 사용한다.

## Workflow

### 1. Scan

분석 대상 파일을 모두 읽는다:

**Global scope** (항상):
- `~/.claude/CLAUDE.md`
- `~/.claude/rules/*.md`

**Project scope** (프로젝트 디렉토리에 있을 때):
- 프로젝트 루트의 `CLAUDE.md`
- 프로젝트의 `.claude/rules/*.md`

scope 인자가 `global`이면 global만, `project`이면 project만, 없거나 `both`이면 둘 다 스캔한다.

각 파일에서:
- 개별 규칙/지침(directive)을 식별하고 카운트한다
- 규칙의 주제/카테고리를 파악한다

### 2. Hindsight Recall (optional)

`HINDSIGHT_API_URL`, `HINDSIGHT_BANK_ID`, `HINDSIGHT_API_TOKEN` 환경변수가 모두 설정되어 있을 때만 실행한다. 없으면 이 단계를 건너뛰고 Step 3으로 진행한다.

```bash
# mental model 조회 (즉시 응답, 토큰 절약)
curl -s "$HINDSIGHT_API_URL/v1/default/banks/$HINDSIGHT_BANK_ID/mental-models/agent-personalization" \
  -H "Authorization: Bearer $HINDSIGHT_API_TOKEN"
```

mental model이 없으면 fall back으로 reflect를 실행한다:

```bash
curl -s -X POST "$HINDSIGHT_API_URL/v1/default/banks/$HINDSIGHT_BANK_ID/reflect" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $HINDSIGHT_API_TOKEN" \
  -d '{
    "query": "사용자가 에이전트에게 반복적으로 준 피드백, 교정, 선호사항을 정리해. 현재 rules에 반영되어야 할 지침 형태로.",
    "tags": ["user:'"$HINDSIGHT_BANK_USER"'"],
    "tags_match": "any_strict"
  }'
```

Hindsight 결과에서 추출할 것:
- rules에 이미 반영된 피드백 (일치 확인)
- rules에 누락된 반복 피드백 (추가 후보)
- rules와 모순되는 피드백 (충돌 후보)

### 3. Evaluate

각 grading criteria로 현재 rules 세트를 평가한다:

**Conciseness 체크:**
- 모든 파일의 총 directive 수를 카운트한다
- 150 초과 시 경고
- 같은 내용을 다른 표현으로 반복하는 중복을 식별한다

**Coherence 체크:**
- 파일 간/파일 내에서 모순되는 지시를 찾는다
- 예: 한 곳에서 "A를 하라"고 하고 다른 곳에서 "A를 하지 말라"

**Effectiveness 체크 (Hindsight 있을 때):**
- Hindsight 피드백에서 반복되는 불만을 식별한다
- 해당 불만에 대응하는 규칙이 있는지 확인한다
- 있는데도 반복되면: 규칙이 비효과적이거나 너무 모호한 것

**Relevance 체크:**
- 모델이 기본으로 잘 하는 일반적인 지침을 식별한다 (예: "버그 없는 코드를 작성하라")
- 이런 규칙은 토큰만 소모하고 행동 변화에 기여하지 않는다

**Specificity 체크:**
- "적절하게", "필요시", "가능하면" 같은 모호한 한정어를 포함한 규칙을 식별한다
- 구체적 행동 지시로 변환 가능한지 평가한다

### 4. Propose

평가 결과를 종합하여 리포트를 작성한다:

```markdown
## Rules Audit Report

**Scope**: [스캔한 파일 목록]
**Total directives**: N / 150 limit
**Hindsight data**: [사용 여부와 데이터 소스]

### Issues Found

#### Duplicates (N)
- `file1:line` ↔ `file2:line` — 중복 내용 설명

#### Conflicts (N)
- `file1:line` vs `file2:line` — 모순 내용 설명

#### Missing (from Hindsight) (N)
- "규칙 내용" — N회 반복 피드백, rules에 미반영

#### Stale / Ineffective (N)
- `file:line` — 규칙이 있지만 같은 문제가 반복되거나, Hindsight에서 관련 데이터 없음

#### Too Vague (N)
- `file:line` "규칙 원문" — 무엇이 모호한지 설명

#### Unnecessary Scaffolding (N)
- `file:line` "규칙 원문" — 모델이 이미 기본으로 잘 하는 것

### Proposed Changes

1. [DELETE] `file:line` — 이유
2. [ADD] `target-file` — 추가할 규칙 내용과 이유
3. [MODIFY] `file:line` — 변경 전 → 변경 후, 이유
4. [REVIEW] `file:line` — 사용자 확인 필요, 질문

적용하시겠습니까? (전체/선택/스킵)
```

### 5. Apply

사용자가 선택한 변경만 적용한다.

적용 전:
- 변경 대상 파일의 현재 내용을 기억한다 (revert 가능하도록)

적용 후:
- 변경 사항 요약을 출력한다
- 총 directive 수가 어떻게 변했는지 보고한다

## Rules

- 사용자 승인 없이 파일을 변경하지 않는다
- 서브에이전트를 스폰하지 않는다
- Hindsight env가 없으면 정적 분석만 수행한다 (graceful degradation)
- 리포트의 모든 제안은 구체적 파일 경로와 라인을 포함해야 한다
- "개선하세요" 같은 모호한 제안을 하지 않는다 — 구체적 변경 내용을 제시한다
- 기존 규칙의 의도를 존중한다 — 삭제 제안 시 왜 불필요한지 근거를 명시한다
