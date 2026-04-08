---
name: kb
description: Clippings를 종합하는 AI 유지 위키. ingest로 외부 기사를 종합 페이지로 변환하고, query로 위키 기반 답변을 생성하며, lint로 위키 건강을 점검하고 스키마 진화를 제안한다.
---

# KB Wiki

Clippings/(외부 기사, 논문)을 종합·교차참조하는 위키를 유지한다. Karpathy LLM Wiki 패턴 기반.

## Preamble

모든 오퍼레이션 전에 `kb/SCHEMA.md`를 읽는다. SCHEMA.md가 이 위키의 규칙이다.

## Commands

Arguments를 파싱하여 서브커맨드를 결정한다:

| 입력 패턴 | 서브커맨드 |
|-----------|-----------|
| `/kb ingest <path>` | ingest |
| `/kb ingest` (경로 없음) | Clippings/에서 미처리 파일 목록을 보여주고 선택하게 함 |
| `/kb query <question>` | query |
| `/kb lint` | lint |
| `/kb rebuild-index` | rebuild-index |

## Workflow: ingest

단일 Clipping을 읽고, kb/ 페이지를 생성하거나 업데이트한다.

1. **Read** — 대상 Clipping을 읽는다. 빈 본문이면 LOG.md에 `skip` 기록 후 종료
2. **Load schema** — `kb/SCHEMA.md`를 읽는다 (타입 목록, 규칙, frontmatter 스키마)
3. **Load index** — `kb/INDEX.md`를 읽는다. 없으면 rebuild-index를 먼저 실행
4. **Check duplicates** — INDEX.md 내 `kb-sources`에 해당 Clipping 경로가 있는지 검색. 있으면 기존 페이지를 업데이트 모드로 전환
5. **Read related** — INDEX.md에서 관련 주제의 기존 kb 페이지를 찾아 읽는다
6. **Decide type** — SCHEMA.md의 타입 정의를 기준으로 판단:
   - 기존 topic에 통합할 수 있으면 → 해당 topic 업데이트
   - 새 topic을 만들 만큼 독립적이면 → topic 신규 생성
   - 독립적이지 않고 기존 topic도 없으면 → source-summary만 생성
   - 분류가 어려우면 → 가장 가까운 타입으로 분류하고 LOG.md에 `classify-difficult` 기록
7. **Write pages** — Obsidian 마크다운으로 페이지를 생성/업데이트. 위키링크는 `[[파일명]]` 형식
8. **Rebuild index** — kb/ 폴더의 모든 .md 파일(SCHEMA.md, INDEX.md, LOG.md 제외)의 frontmatter를 읽어 INDEX.md를 재생성
9. **Log** — LOG.md에 `## [날짜] ingest | Clipping 제목` 기록

## Workflow: query

kb/ 위키를 기반으로 질문에 답변한다.

1. **Load index** — `kb/INDEX.md`를 읽는다
2. **Find relevant** — 질문과 관련된 kb 페이지를 INDEX.md에서 찾는다
3. **Read pages** — 관련 페이지를 읽는다. 필요하면 원본 Clipping도 참조
4. **Synthesize** — 종합 답변을 생성한다. 출처를 명시한다
5. **Optionally save** — 사용자에게 "이 답변을 kb 페이지로 저장할까요?" 제안. 승인 시 적절한 타입으로 저장

## Workflow: lint

위키 건강을 점검하고 스키마 진화를 제안한다.

1. **Rebuild index** — INDEX.md를 먼저 재생성하여 최신 상태 보장
2. **Check integrity**:
   - 깨진 위키링크 탐지
   - frontmatter 스키마 위반 (필수 필드 누락 등)
   - kb-sources에 명시된 Clipping이 실제로 존재하는지
3. **Gap analysis**:
   - Clippings/ 스캔 → 아직 ingest되지 않은 파일 목록 출력 ("미처리 Clippings N개")
   - 같은 주제의 Clippings가 여러 개인데 topic 페이지가 없는 경우 제안
4. **Schema evolution**:
   - LOG.md에서 `classify-difficult` 이벤트를 수집
   - 패턴이 보이면 새 타입을 제안 (SCHEMA.md 진화 프로토콜에 따라)
   - before/after 비교 포함: "현재 타입에 넣으면 → ... / 새 타입으로 분리하면 → ..."
5. **Report** — 발견 사항을 severity별로 정리하여 출력

## Workflow: rebuild-index

kb/ 폴더를 스캔하여 INDEX.md를 재생성한다.

1. `kb/` 아래 모든 .md 파일을 Glob으로 찾는다 (SCHEMA.md, INDEX.md, LOG.md 제외)
2. 각 파일의 frontmatter에서 `kb-type`, `created`, 파일명을 추출
3. 타입별 섹션으로 그룹핑, 각 섹션 내 created 내림차순
4. INDEX.md 형식: `- [[파일명]] — 한줄 설명` (한줄 설명은 파일 첫 문단에서 추출)
5. INDEX.md를 덮어쓴다

## Rules

- SCHEMA.md를 매 오퍼레이션 시작 시 반드시 읽는다
- Clippings/ 외의 파일을 ingest하지 않는다
- Dev/ 노트를 수정하지 않는다 (위키링크 참조만)
- ingest 중 타입 제안을 하지 않는다 (lint에서만)
- 위키링크는 Obsidian 기본 형식: `[[파일명]]`
- 페이지 생성 시 obsidian-markdown 스킬의 frontmatter/위키링크 규칙을 따른다
