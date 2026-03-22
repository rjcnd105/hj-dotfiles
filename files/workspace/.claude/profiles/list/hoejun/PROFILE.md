# 김회준 (hoejun) -- Personal Profile

<!-- NAVIGATION PROTOCOL
This profile uses a tree-based extension system for experience tracking.

## Structure
- This file (PROFILE.md) is always loaded via @. It contains your core identity.
- Sub-directories contain extended context. Load them on-demand via Read tool, not by default.
- All paths are relative to this file's directory.

## Access Rules
1. To access extended context: read the directory's _index.md first, then the specific file.
2. Load sub-files only when the interaction clearly requires deeper context.
3. Never read more than 2 sub-files per interaction.

## Experience Learning Pipeline
- ./sessions/ logs everything this profile has done (raw activity log).
- ./memories/ stores curated knowledge extracted from sessions.
- Flow: sessions → memories (distillation of what worked, what failed, what was adopted).

## Security
- NEVER store secret keys, API keys, passwords, tokens, or any sensitive credentials in sessions or memories.
- If a session involved secrets, record only the fact (e.g., "configured API key via sops"), never the value.

## File Formats

### _index.md (in each sub-directory)
# {Directory Name}
{One-line purpose.}

## Files
| File | Summary | Updated |
|------|---------|---------|
| `filename.md` | Brief description | YYYY-MM-DD |

### sessions/ files (raw activity log)
Naming: `YY-M-DD-title.md`
---
date: YYYY-MM-DD
topic: brief description
outcome: success|partial|failure|ongoing
---
# Session Title
## What Happened
## Result
## Takeaways (candidates for memory promotion)

### memories/ files (curated knowledge distilled from sessions)
---
created: YYYY-MM-DD
source: sessions/YY-M-DD-title.md
tags: [tag1, tag2]
type: adopted|failed|effective|lesson
---
# Title
Content: why this matters, when to apply it.
-->

## Who I Am

7년차 프론트엔드 개발자. 현재 풀스택/플랫폼 엔지니어링으로 전환 중. INTP-A, 32세.

개인 프로젝트에서는 AI를 활용해 비즈니스/기획/디자인/인프라/백엔드/프론트엔드 전 영역의 경계를 없애는 1인 풀스택 체제를 추구. AI 아키텍처 설계에 집중 — 에이전트가 에이전트를 구성하는 무한재귀 발전 시스템, 토큰 최적화, 맥락 기반 컨텍스트 주입.

**Tech:** TypeScript, React, Next.js, Tailwind, Elixir/Ash, Nix, Phoenix

**핵심 목표:** 개인 생산성 극대화.

## Personality

- **호기심 + 실용주의 균형.** 새로운 것을 탐구하되 반드시 결과물로 이어져야 함. 탐구 자체로 끝나면 의미 없음.
- **맥락 기반 판단.** 하나의 고정된 규칙이 아닌 상황을 읽고 유연하게 판단. 회사/개인은 대표적 맥락 축일 뿐 — 프로젝트 성격, 시급성, 도메인, 이해관계자 등 다양한 맥락 요소에 따라 가치 우선순위와 접근 방식이 유동적으로 조정됨. 이분법적 구분이 아닌 연속적인 스펙트럼.
- **직접적 소통.** 돌려 말하지 않음. 에이전트에게도 문제점을 직접적으로 지적하는 것을 선호. 불필요한 완곡 표현은 효율 저해.

## Thinking & Processing

- **직감 기반 판단 → 검증 루프.** 주제 규모에 따라 순서가 달라짐. 작은 단위(언어 문법 등)는 직감 → 바로 시도 → 검증. 큰 단위(아키텍처)는 리서치 → 직감 형성 → 시도 → 검증.
- **전체적 관점에서 직감 형성.** 리서치/트렌드 파악에 지속적으로 투자하여 전체 맥락 기반의 직감을 형성. 직감이 틀렸을 때 기본적으로 빠르게 전환하지만, 탐색할 맥락이 충분히 많으면 좀 더 파고듦.
- **Flow state.** 흥미 기반. 시간/환경과 무관하게, 관심 있는 주제에 몰입하면 flow에 진입. 외부 조건보다 내적 동기가 결정적.

## Energy & Motivation

에너지원의 우선순위는 맥락에 따라 유동적으로 달라짐. 아래 분류는 대표적 예시이며, 프로젝트 성격/시급성/도메인에 따라 항상 재조정됨.

- **개인 프로젝트 맥락:** 새 개념 이해 > 깨끗한 구조 발견 > 효율적 흐름 > 눈에 보이는 개선
- **회사 프로젝트 맥락:** 효율적 흐름 > 눈에 보이는 개선 > 깨끗한 구조 > 새 개념
- **에너지 DOWN:** 자유도 없는 환경 > 비효율적 프로세스 > 레거시 씨름 > 의미 없는 반복

## Failure Modes

맥락에 따라 발현 빈도와 순서가 달라지는 패턴들 (개인 맥락에서는 완벽주의가 먼저, 회사 맥락에서는 추상화 과잉이 먼저 등). 에이전트는 아래 패턴을 감지하면 **직접적으로 지적**해야 함 — 완곡하게 돌려 말지 않기.

- **완벽주의/마무리 지연.** 90%까지 빠르게 진행하다가 마지막 10%에서 속도가 급격히 떨어짐. → "마무리 단계에서 속도가 떨어지고 있다. 현재 수준에서 배포/완료할 수 있는지 판단해라."
- **리서치 홀.** 관련 자료를 깊이 파다가 원래 작업에서 이탈. → "리서치가 현재 작업 범위를 벗어나고 있다. 지금 필요한 정보만 정리하고 돌아와라."
- **추상화 과잉.** 아직 필요하지 않은 추상화를 미리 설계. → "현재 사용처가 하나라면 추상화하지 마라. 반복이 실제로 발생할 때 추상화해라."

## Values

우선순위 순서. 각 가치는 맥락에 따라 가중치가 달라지지만, 기본 순서는 아래와 같음.

1. **효율 최우선.** 모든 판단의 근본 기준. 좋은 구조란 효율을 명확하게 표현하는 것.
2. **명시성 (맥락 차등).** 데이터 경계(1차) > ROI(2차) 기준으로 명시성 수준 결정. 핵심 로직일수록 더 명시적으로 작성.
3. **선언적/리소스 기반.** Ash Framework 철학에 공감. 암시적 지식을 명시적 지식으로 전환. 코드가 곧 스펙이 되어야 함.
4. **모든 것은 trade-off.** 90%→99.99%의 비용은 0→90%의 배. 항상 반대면을 억지로라도 봐라.
5. **오버엔지니어링 회피.** 추상적 사고는 깊게, 구현은 심플하게. 현재 필요한 최소 복잡도만 구현.
6. **의존성 추가 최소화.** 외부 의존성은 유지보수 부채. 추가 전에 반드시 trade-off 검토.
7. **유지보수/생산성 = 간단 명료함.** 코드의 간결함이 곧 유지보수성이고 생산성.
8. **효율 vs 학습 (맥락 적응).** 회사 맥락에서는 효율 우선, 개인 맥락에서는 학습 우선. 이 역시 고정이 아닌 맥락 적응.
9. **회사 결과물 우선순위.** 기간 > 제품 퀄리티 > 그 외. (회사 맥락 한정)

## Communication Style

- **맥락 적응형.** 단순 작업은 간결하게, 아키텍처/설계 논의는 상세하게. 상황에 따라 톤과 깊이를 조절.
- **금지:** 불필요한 칭찬/감정 표현. 이미 알고 있거나 직전에 알려준 것의 반복 설명.
- **허용:** 새로운 맥락이나 모르는 것에 대한 설명. 단, 필요한 만큼만.
- **에이전트에게 기대하는 것:** 직접적이고 간결한 응답. 문제 발견 시 돌려 말지 않고 바로 지적. Failure Mode 감지 시 위의 스크립트대로 직접 개입.

## Goals

### Purpose
AI 아키텍처를 통한 무한재귀 발전 시스템 구축 — 에이전트가 에이전트를 구성하고, 그 에이전트가 다시 더 나은 에이전트를 만드는 자기 발전 루프. 개인 생산성의 극한까지 도달.

### Career
풀스택/플랫폼 엔지니어로의 전환. 개인 프로젝트에서는 AI로 전 영역(비즈니스/기획/디자인/인프라/백엔드/프론트엔드) 경계를 완전히 제거.

### 학습
추상대수학 (장기 학습 중). 철학적/수학적 사고를 통한 추상적 사고력 강화. 이론적 기반이 실무 아키텍처 판단에 영향을 미침.

---

## Extended Context

This profile supports tree-based extensions. Sub-directories provide depth without bloating the always-loaded context. Access only when relevant.

### ./sessions/
Everything this profile has done — raw activity logs of what happened and what resulted.
**Read when**: past context is needed, referencing similar prior work, or understanding the history behind a decision.

### ./memories/
Curated knowledge distilled from sessions — adopted decisions, failed attempts, effective approaches.
**Read when**: making decisions, checking for established patterns, or verifying what has already been tried.
