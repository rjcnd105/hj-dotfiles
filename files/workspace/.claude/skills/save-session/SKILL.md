---
name: save-session
description: 프로필의 재귀 발전 루프를 위해 현재 세션을 sessions/에 기록하고, 미래 의사결정을 개선할 지식을 memories/에 증류 저장한다. 세션 로그가 축적될수록 에이전트가 과거 맥락을 참조해 더 나은 판단을 내릴 수 있게 된다. "세션 저장", "save session", "wrap up", "세션 마무리", "기록 남겨", "세션 끝", "작업 정리" 등의 표현이나 /save-session 호출 시 사용. 프로필(@profile/ 등)을 로드한 상태에서 작업을 마무리할 때 적극적으로 사용할 것 — 사용자가 명시적으로 요청하지 않아도, 의미 있는 작업이 끝났다면 세션 저장을 제안할 수 있다.
---

# Save Session

현재 대화 세션을 프로필의 experience learning pipeline에 기록한다.

세션(raw log)이 축적되면 에이전트가 과거 작업 이력을 참조할 수 있고, 그 중 반복적으로 유용한 지식을 memory로 증류하면 매 세션마다 더 나은 의사결정이 가능해진다. 이것이 재귀 발전 루프의 핵심이다.

## 프로필 탐색

프로필은 `.claude/profiles/{name}/` 디렉토리에 위치한다. 디렉토리 구조:

```
.claude/profiles/{name}/
├── PROFILE.md
├── sessions/
│   ├── _index.md
│   └── 26-3-17-some-work.md
└── memories/
    ├── _index.md
    └── some-lesson.md
```

현재 작업 중인 프로필을 찾는 기준:
1. 대화에서 `@profile/` 등으로 명시적으로 로드된 프로필
2. 대화 맥락에서 특정 프로필 디렉토리(`profiles/{name}/`)의 파일을 읽거나 수정한 이력
3. 불분명하면 사용자에게 어떤 프로필에 저장할지 질문

프로필 루트 = `PROFILE.md`가 있는 디렉토리(`profiles/{name}/`). 세션과 memory는 이 디렉토리 아래 `sessions/`, `memories/`에 저장한다.

## Phase 1: 세션 저장

### 1-1. 대화 요약

현재 세션을 분석하여 다음을 파악:
- **무엇을 했는가** — 구체적 결과물 (생성/수정한 파일, 내린 결정, 해결한 문제)
- **결과** — success, partial, failure, ongoing 중 하나
- **Takeaways** — memory로 승격할 후보. 아래 기준 참고

### 1-2. 세션 파일 작성

`sessions/` 디렉토리에 아래 포맷으로 저장:

**파일명**: `YY-M-DD-{title}.md` (title은 kebab-case, 핵심 주제를 담은 짧은 이름)

```markdown
---
date: {YYYY-MM-DD}
topic: {한 줄 요약}
outcome: {success|partial|failure|ongoing}
---

# {Session Title}

## What Happened
{구체적으로 무엇을 했는지. 파일 경로, 결정 사항, 사용한 도구/접근법 포함}

## Result
{결과물 요약. 성공했으면 무엇이 완성되었는지, 실패했으면 왜 실패했는지}

## Takeaways
{memory 승격 후보 목록. 각 항목에 왜 재귀 발전에 유용한지 한 줄 근거}
```

### 1-3. _index.md 갱신

`sessions/_index.md`가 있으면 새 세션 항목을 추가. 없으면 생성:

```markdown
# Sessions
프로필 활동의 raw log.

## Files
| File | Summary | Updated |
|------|---------|---------|
| `{filename}` | {한 줄 요약} | {YYYY-MM-DD} |
```

## Phase 2: Memory 증류

세션의 Takeaways를 검토하여 memory로 승격할 가치가 있는 항목을 선별한다.

### 승격 기준

memory는 **미래 세션의 의사결정을 개선**하는 지식이어야 한다. 구체적으로:

- **adopted**: 시도하고 채택한 패턴/접근법. 왜 효과적이었는지 기록.
- **failed**: 시도했으나 실패한 접근. 왜 실패했고, 대안은 무엇이었는지.
- **effective**: 특정 상황에서 효과적이었던 전략/도구 조합.
- **lesson**: 경험에서 도출한 원칙이나 깨달음.

### 승격하지 않는 것

- 코드/git에서 직접 확인 가능한 사실 (파일 경로, 커밋 내용 등)
- 일회성 작업 세부사항
- 이미 존재하는 memory와 중복되는 내용

### Memory 파일 작성

승격 대상이 있을 때만 `memories/`에 저장:

**파일명**: `{descriptive-name}.md` (내용을 설명하는 이름)

```markdown
---
created: {YYYY-MM-DD}
source: sessions/{session-filename}
tags: [{관련 태그들}]
type: {adopted|failed|effective|lesson}
---

# {Title}

{왜 이것이 중요한지, 언제/어떻게 적용해야 하는지}
```

### _index.md 갱신

`memories/_index.md`가 있으면 항목 추가. 없으면 생성:

```markdown
# Memories
세션에서 증류된 지식 — 채택된 결정, 실패한 시도, 효과적이었던 접근.

## Files
| File | Summary | Updated |
|------|---------|---------|
| `{filename}` | {한 줄 요약} | {YYYY-MM-DD} |
```

## Phase 3: 보고

저장 완료 후 간결하게 보고:
- 저장된 세션 파일 경로
- 승격된 memory 수와 각각의 한 줄 요약 (승격 대상 없으면 "승격 대상 없음")

## 주의사항

- 비밀 키, API 키, 비밀번호, 토큰 등 민감 정보는 절대 기록하지 않는다. 사실만 기록 (예: "sops로 API 키 설정").
- 기존 memory와 중복 확인 — 중복이면 기존 memory를 갱신하거나 스킵.
- 세션 파일명의 날짜는 실제 세션 날짜 기준.
