---
name: hindsight
description: >-
  Hindsight 장기 기억 시스템을 직접 조작한다.
  `/hindsight retain <내용>` — 지식을 장기 기억에 저장.
  `/hindsight recall <질문>` — 과거 기억을 검색.
  `/hindsight reflect <질문>` — 기억 기반 추론/분석.
  `/hindsight save` — 현재 세션의 경험(성공/실패/피드백)을 장기 기억에 저장.
  `/hindsight record <내용>` — 주어진 내용을 save 규격(태그, document_id, context 등)으로 장기 기억에 저장. 세션 분석 생략.
  `/hindsight context <주제>` — 관련 과거 기억을 불러와 작업 맥락으로 사용.
  `/hindsight setup` — bank mission 설정 (재귀 발전 최적화, 최초 1회).
  `/hindsight status` — bank 상태 확인.
  사용자가 "/hindsight", "hindsight에 저장", "hindsight에서 찾아", "hindsight 검색",
  "장기 기억에 저장", "장기 기억 검색", "세션 저장", "과거 기억 참고", "이전 경험" 등을 말할 때 사용.
  반드시 arguments(retain/recall/reflect/save/record/context/setup/status)로 동작을 결정한다.
  arguments 없이 호출되면 사용법을 안내한다.
---

# Hindsight

Hindsight 장기 기억 시스템의 직접 인터페이스.

## 전제조건

`HINDSIGHT_BANK_ID`, `HINDSIGHT_BANK_USER`, `HINDSIGHT_API_URL`, `HINDSIGHT_API_KEY` 환경변수가 모두 필요하다.
하나라도 없으면 사용자에게 알리고 종료.

## 명령어

| 명령 | 설명 |
|------|------|
| `/hindsight retain <내용>` | 내용을 장기 기억에 저장 |
| `/hindsight recall <질문>` | 과거 기억에서 관련 fact 검색 |
| `/hindsight reflect <질문>` | 기억 기반 추론 — Hindsight가 답변을 생성 |
| `/hindsight save` | 현재 세션의 경험을 장기 기억에 저장 |
| `/hindsight record <내용>` | 주어진 내용을 save 규격으로 장기 기억에 저장 |
| `/hindsight context <주제>` | 관련 과거 기억을 불러와 작업 맥락으로 주입 |
| `/hindsight setup` | bank mission 설정 — 재귀 발전에 최적화 (최초 1회) |
| `/hindsight status` | bank 통계 확인 |

arguments 없이 호출하면 위 표를 보여준다.

## 재귀 발전 루프

이 스킬의 핵심 가치는 세션 간 재귀적 자기 개선이다.

```
/hindsight context <주제>     ← 과거 경험 로드 (루프 입력)
        │
    작업 수행 (과거 성공/실패 참고)
        │
/hindsight save               ← 세션 경험 저장 (루프 출력)
        │
    Hindsight 자동 처리: fact 추출 → observation 합성
        │
    다음 세션의 context에서 개선된 지식 활용
```

## 실행 절차

### `save`

현재 세션의 원본 내용을 Hindsight에 retain한다. **Claude가 분석/분류하지 않는다** — Hindsight의 fact 추출 LLM이 직접 처리한다.

1. 세션에서 **원본 내용을 수집**한다 (pre-summarization 안티패턴 회피):
   - 사용자의 실제 요청과 발언
   - 수행한 작업의 구체적 내용 (파일 경로, 명령어, 에러 메시지, 코드 변경사항)
   - 사용자의 피드백과 수정 요청 (원문 그대로)
   - 채택/거부된 선택지와 그 맥락

2. 수집한 내용을 **대화 형식으로 구성**한다. 분류하거나 요약하지 않는다:
   ```
   [YYYY-MM-DDTHH:MM:SSZ] user: <사용자 발언 원문>
   [YYYY-MM-DDTHH:MM:SSZ] assistant: <수행한 작업과 결과 구체적 기술>
   [YYYY-MM-DDTHH:MM:SSZ] user: <피드백 원문>
   ...
   ```
   대화가 길면 핵심 상호작용 위주로 선별하되, 선별한 내용은 원문을 유지한다.

3. 태그 구성:
   - `user:$HINDSIGHT_BANK_USER` (필수)
   - `project:$HINDSIGHT_TAG_PROJECT` (env 존재 시)
   - `profile:$HINDSIGHT_TAG_PROFILE` (env 존재 시)
   - `session:<날짜-주제>` — 세션 식별

4. REST API로 retain:
   ```bash
   curl -s -X POST "$HINDSIGHT_API_URL/v1/default/banks/$HINDSIGHT_BANK_ID/memories" \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer $HINDSIGHT_API_KEY" \
     -d '{
       "items": [{
         "content": "<수집한 세션 원본 내용>",
         "context": "claude-code session log: <세션 주제 1줄 요약>. raw conversation with user requests, actions taken, feedback, and decisions.",
         "timestamp": "<세션 시작 시각 ISO 8601>",
         "document_id": "session-<YYYY-MM-DD>-<주제>",
         "tags": [<구성된 태그들>],
         "metadata": {"source": "claude-code", "session_topic": "<주제>"}
       }]
     }'
   ```

5. 결과 보고

### `record <내용>`

주어진 내용을 그대로 Hindsight에 retain한다. `save`와 동일한 규격(태그, document_id, context, metadata)을 적용하되, 세션 수집을 생략한다. 다른 워크플로우(예: compound)의 출력물을 Hindsight에 저장할 때 사용한다.

1. 내용을 **그대로** 사용한다 — 요약하거나 재분석하지 않는다. Hindsight가 fact을 직접 추출한다.

2. 태그 구성 (`save`와 동일):
   - `user:$HINDSIGHT_BANK_USER` (필수)
   - `project:$HINDSIGHT_TAG_PROJECT` (env 존재 시)
   - `profile:$HINDSIGHT_TAG_PROFILE` (env 존재 시)
   - `session:<날짜-주제>` — 세션 식별

3. 내용에서 주제를 파악하여 document_id, context, metadata를 구성한다.

4. REST API로 retain (`save`와 동일한 형식):
   ```bash
   curl -s -X POST "$HINDSIGHT_API_URL/v1/default/banks/$HINDSIGHT_BANK_ID/memories" \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer $HINDSIGHT_API_KEY" \
     -d '{
       "items": [{
         "content": "<주어진 내용 전체>",
         "context": "<내용의 성격과 출처를 구체적으로 기술>",
         "timestamp": "<현재 시각 ISO 8601>",
         "document_id": "<주제-날짜 형식의 안정적 ID>",
         "tags": [<구성된 태그들>],
         "metadata": {"source": "claude-code", "session_topic": "<주제>"}
       }]
     }'
   ```

5. 결과 보고

### `context <주제>`

작업을 시작하기 전에 관련 과거 경험을 불러온다. 재귀 루프의 입력 단계.

1. 주제에 맞는 recall 실행:
   ```bash
   curl -s -X POST "$HINDSIGHT_API_URL/v1/default/banks/$HINDSIGHT_BANK_ID/memories/recall" \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer $HINDSIGHT_API_KEY" \
     -d '{
       "query": "<주제에 대한 자연어 질문>",
       "tags": ["user:'"$HINDSIGHT_BANK_USER"'"],
       "tags_match": "any_strict",
       "max_tokens": 4096
     }'
   ```

2. 이어서 reflect로 패턴 분석:
   ```bash
   curl -s -X POST "$HINDSIGHT_API_URL/v1/default/banks/$HINDSIGHT_BANK_ID/reflect" \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer $HINDSIGHT_API_KEY" \
     -d '{
       "query": "이 주제에 대해 과거에 성공한 접근, 실패한 접근, 사용자 피드백 패턴을 정리해줘: <주제>",
       "tags": ["user:'"$HINDSIGHT_BANK_USER"'"],
       "tags_match": "any_strict"
     }'
   ```

3. recall 결과(구체적 fact)와 reflect 결과(패턴 분석)를 종합하여 보고:
   - 관련 과거 경험 요약
   - 피해야 할 접근 (과거 실패)
   - 효과적이었던 접근 (과거 성공)
   - 사용자 선호/피드백 패턴

4. 이후 작업에서 이 맥락을 참고하여 진행한다.

### `retain <내용>`

1. 환경변수 확인
2. 태그 구성:
   - `user:$HINDSIGHT_BANK_USER` (필수)
   - `project:$HINDSIGHT_TAG_PROJECT` (env 존재 시)
   - `profile:$HINDSIGHT_TAG_PROFILE` (env 존재 시)
   - 사용자가 추가 태그를 지정했으면 포함
3. REST API로 retain 실행:
   ```bash
   curl -s -X POST "$HINDSIGHT_API_URL/v1/default/banks/$HINDSIGHT_BANK_ID/memories" \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer $HINDSIGHT_API_KEY" \
     -d '{
       "items": [{
         "content": "<내용>",
         "context": "<내용의 성격과 출처를 구체적으로 기술>",
         "timestamp": "<현재 시각 ISO 8601>",
         "document_id": "<주제-날짜 형식의 안정적 ID>",
         "tags": [<구성된 태그들>],
         "metadata": {"source": "claude-code"}
       }]
     }'
   ```
4. 응답 확인 후 결과 보고

내용을 요약하지 않는다 — Hindsight가 fact을 직접 추출한다.

### `recall <질문>`

1. 환경변수 확인
2. 검색 의도에 맞게 태그/tags_match 결정:
   - 기본: `user:$HINDSIGHT_BANK_USER` + `tags_match: "any_strict"`
   - 사용자가 "전체 검색", "모든 사용자" 등을 언급하면 태그 없이 검색
3. REST API로 recall 실행:
   ```bash
   curl -s -X POST "$HINDSIGHT_API_URL/v1/default/banks/$HINDSIGHT_BANK_ID/memories/recall" \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer $HINDSIGHT_API_KEY" \
     -d '{
       "query": "<질문>",
       "tags": [<태그들>],
       "tags_match": "<선택된 모드>"
     }'
   ```
4. 결과를 읽기 쉽게 정리하여 보고

### `reflect <질문>`

1. 환경변수 확인
2. recall과 동일한 태그 구성
3. REST API로 reflect 실행:
   ```bash
   curl -s -X POST "$HINDSIGHT_API_URL/v1/default/banks/$HINDSIGHT_BANK_ID/reflect" \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer $HINDSIGHT_API_KEY" \
     -d '{
       "query": "<질문>",
       "tags": [<태그들>],
       "tags_match": "<선택된 모드>"
     }'
   ```
4. Hindsight의 추론 결과를 보고

recall은 raw fact 목록, reflect는 Hindsight가 자체 추론한 답변. "분석해줘", "패턴이 있어?" 같은 추론에는 reflect, 단순 검색에는 recall.

### `setup`

Bank mission을 재귀적 자기 개선에 최적화한다. 최초 1회만 실행하면 된다 — 이미 설정된 bank에 재실행하면 덮어쓴다.

1. 현재 bank 설정 확인:
   ```bash
   curl -s -H "Authorization: Bearer $HINDSIGHT_API_KEY" "$HINDSIGHT_API_URL/v1/default/banks/$HINDSIGHT_BANK_ID" | python3 -m json.tool
   ```

2. 이미 mission이 설정되어 있으면 사용자에게 보여주고, 덮어쓸지 확인한다.

3. Bank mission 설정 (PATCH — 기존 설정의 다른 필드를 보존):
   ```bash
   curl -s -X PATCH "$HINDSIGHT_API_URL/v1/default/banks/$HINDSIGHT_BANK_ID" \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer $HINDSIGHT_API_KEY" \
     -d '{
       "retain_mission": "Extract: technical decisions and trade-offs, successful approaches (what worked and why), failed approaches (what broke and why), user feedback (corrections, preferences, satisfaction signals), adopted decisions among alternatives, error messages and their resolutions, tool usage patterns, and workflow sequences. Ignore: greetings, filler, scheduling logistics, and information already in code or git history.",
       "observations_mission": "Synthesize durable patterns from accumulated facts: recurring success strategies, repeated failure modes, evolving user preferences, behavioral shifts over time, and contradictions with prior knowledge. Focus on actionable patterns that improve future decision-making. Flag when new evidence contradicts established observations.",
       "reflect_mission": "You are a self-improving coding agent reviewing your own accumulated experience. Reference past successes, failures, and user feedback to give grounded recommendations. Be direct about what worked and what did not. When past experience is relevant, cite it specifically rather than giving generic advice.",
       "enable_observations": true,
       "retain_extraction_mode": "verbose"
     }'
   ```

4. 결과 확인 후 보고:
   - 설정된 mission 요약
   - `enable_observations: true` 확인
   - `retain_extraction_mode: verbose` 확인

mission 내용은 위 기본값을 사용하되, 사용자가 커스텀 mission을 제시하면 그것을 사용한다.

### `status`

```bash
hindsight bank stats $HINDSIGHT_BANK_ID
```

bank이 없으면 `hindsight bank create $HINDSIGHT_BANK_ID`로 생성 후 재확인.

## Gotchas

- **retain 직후 recall 금지** — fact 추출과 인덱싱이 비동기. 다음 턴 이후에 recall 가능
- **CLI는 태그 미지원** — retain/recall/reflect는 REST API(curl) 사용. CLI는 `bank stats`, `bank create` 등 관리 명령에만 사용
- **document_id에 랜덤 UUID 금지** — 같은 ID로 retain하면 upsert. `session-2026-03-20-hindsight-setup` 같은 안정적 ID를 사용
- **metadata로 필터링 불가** — 필터링 필요한 값은 tags에
- **save는 세션 끝에 1회** — 같은 세션을 여러 번 save하면 document_id가 같아 이전 것을 덮어쓴다 (의도된 동작)

## 참조

상세 API 문서, 파라미터, 고급 기능(mental models, observation scopes, tag_groups 등)은 `hindsight-docs` 스킬 참조.
