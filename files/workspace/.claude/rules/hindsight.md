# Hindsight Rules

`HINDSIGHT_BANK_ID`, `HINDSIGHT_BANK_USER`, `HINDSIGHT_API_URL` 중 하나라도 없으면 이 규칙 전체를 무시한다.

## When → Do

- **Hindsight에 retain할 때** → `user:$HINDSIGHT_BANK_USER` 태그 필수. `$HINDSIGHT_TAG_PROJECT`, `$HINDSIGHT_TAG_PROFILE` env가 있으면 해당 태그도 추가. 내용을 요약하지 말고 원본 그대로 전달 — Hindsight가 fact을 추출한다.
- **retain 내용을 구성할 때** → `context` 필드를 항상 구체적으로 설정 (fact 추출 품질에 직접 영향). `timestamp`를 ISO 8601로 설정 (temporal retrieval 활성화). `document_id`는 안정적인 의미 있는 ID 사용 (같은 ID로 retain하면 upsert).
- **`/hindsight` 명령 수신 시** → hindsight 스킬의 arguments(retain, recall, reflect, save, context, setup, status)에 따라 실행.
- **태그로 필터링이 필요한 작업 시** → CLI는 `--tags`를 지원하지 않으므로 REST API(curl)를 사용. 상세는 `hindsight-docs` 스킬 참조.

## Compound → Hindsight 연동

- **`/ce:compound` 완료 후** → 세션의 원본 내용(사용자 요청, 수행한 작업, 피드백, 결정 등)을 `/hindsight record`로 retain한다. compound가 생성한 `docs/solutions/` 파일은 이미 정제된 문서이므로 그것을 넣지 않는다 — 원본 세션 내용을 넣어야 Hindsight가 fact을 풍부하게 추출할 수 있다.

## Gotchas

- retain 직후 같은 턴에서 recall하면 안 됨 — 인덱싱이 비동기로 진행된다
- metadata는 필터링 불가 — 필터링이 필요하면 tags를 사용
- 랜덤 UUID를 document_id로 쓰면 중복 문서가 생긴다
- 코드/git에서 직접 읽을 수 있는 정보, 민감 정보(비밀번호, API 키)는 retain하지 않는다
