---
name: kb
description: Clippings 종합하는 AI 위키. ingest로 외부 기사→종합 페이지 변환, query로 위키 기반 답변 생성, lint로 위키 건강 점검·스키마 진화 제안.
---

# KB Wiki

Clippings/(외부 기사, 논문) 종합·교차참조 위키 유지. Karpathy LLM Wiki 패턴 기반.

## Preamble

**Vault 경로**: `/Users/hj/Library/Mobile Documents/iCloud~md~obsidian/Documents/Brain`
**Skill 경로**: `/Users/hj/dot/nix-dots/files/workspace/.agents/skills/kb`

vault content 경로는 이 vault 기준. helper/script 경로는 skill 경로 기준. 다른 레포에서 실행해도 두 절대 경로를 구분해서 사용.
모든 오퍼레이션 전 `kb/SCHEMA.md` 읽음. SCHEMA.md = 위키 규칙.

## Search: qmd

kb/ 검색에 qmd 사용. 글로벌 설치됨 (`qmd`).

**초기 설정** (collection 미등록 시):
```bash
cd "/Users/hj/Library/Mobile Documents/iCloud~md~obsidian/Documents/Brain"
qmd collection add "kb/" --name kb
qmd update
qmd embed
```

**검색 명령**:
- `qmd search "keyword" --json -n 10` — BM25 키워드 검색 (빠름)
- `qmd vsearch "자연어 질문" --json -n 10` — 시맨틱 벡터 검색
- `qmd query "질문" --json -n 10` — 하이브리드 + LLM 리랭킹 (최고 품질)

**사용 시점**: INDEX.md는 human-readable 카탈로그로 유지. 실제 페이지 탐색은 qmd 우선 사용. qmd 실패 시 INDEX.md + Grep 폴백.

**파일 변경 후 인덱스 갱신**: `qmd embed`만 실행하면 새/수정 파일 discovery가 누락될 수 있다. KB 파일을 쓴 뒤에는 항상 `qmd update && qmd embed` 순서로 실행한다.

## Commands

Arguments 파싱→서브커맨드 결정:

| 입력 패턴 | 서브커맨드 |
|-----------|-----------|
| `/kb ingest <path>` | ingest |
| `/kb ingest` (경로 없음) | Clippings/ 미처리 파일 목록 표시, 선택 |
| `/kb query <question>` | query (기본 read-only) |
| `/kb query <question + 보강/작성/수정/저장 intent>` | query로 context를 찾은 뒤 maintenance/write workflow로 전환 |
| `/kb lint` | lint |
| `/kb rebuild-index` | rebuild-index |
| `/kb crystallize` | crystallize |

## Tools

기계적 스캔·재생성은 Go tool에 위임하고, 미처리 목록 표시는 shell helper로 처리하여 Claude 토큰 소비 최소화.

### Go tool: `scripts/kbtool/` (stdlib-only)

현재 실행 기준은 바이너리가 아니라 Go source다. skill 디렉터리 기준으로 `cd "/Users/hj/dot/nix-dots/files/workspace/.agents/skills/kb/scripts/kbtool" && go run . <subcommand>`를 사용한다.

| 서브커맨드 | 역할 |
|-----------|------|
| `go run . context [-mode query|ingest|crystallize] [-n 4] [-min-score 20] <query-or-path>` | Context Injection 후보 JSON 출력. 관련 kb 페이지를 파일명·본문·태그 기반으로 ranking하되, 기존 KB는 결론을 정하는 근거가 아니라 참고 자료(recall aid)로만 사용 |
| `go run . lint` | 단일 JSON 출력: broken wikilinks, frontmatter violations, dead source refs, single/empty source pages, unresolved conflicts, unprocessed clippings, stale 최신 동향, orphan pages, classify-difficult, roadmap |
| `go run . rebuild-index` | INDEX.md 결정론적 재생성 (frontmatter + tags → 도메인 섹션, Health 블록 append, atomic write) |
| `go run . rebuild-sources` | kb 페이지 frontmatter의 `kb-sources` 항목을 `kb/.sources`로 집계 |

LLM은 JSON 읽기만 수행. 페이지 직접 스캔 금지.

### Shell scripts

- `scripts/unprocessed.sh [--all | -n N]` — `Clippings/` vs `kb/.sources` diff. 기본 첫 20개

`kb/.sources`는 캐시. 수동 편집 금지 — `cd "/Users/hj/dot/nix-dots/files/workspace/.agents/skills/kb/scripts/kbtool" && go run . rebuild-sources`로 재생성.

## Workflow: ingest

단일 Clipping 읽고 kb/ 페이지 생성/업데이트.

경로 지정 없이 `/kb ingest` 호출 시: `bash "/Users/hj/dot/nix-dots/files/workspace/.agents/skills/kb/scripts/unprocessed.sh"` 실행하여 미처리 목록 표시 (기본 20개). 사용자 선택 후 각 파일을 아래 워크플로우로 처리.

1. **Read** — 대상 Clipping 읽음. 빈 본문→LOG.md `skip` 기록 후 종료
2. **Load schema** — `kb/SCHEMA.md` 읽음 (타입 목록, 규칙, frontmatter 스키마)
3. **Load index** — `kb/INDEX.md` 읽음. 없으면 rebuild-index 먼저 실행
4. **Check duplicates** — `grep -Fx "Clippings/$name" kb/.sources` 로 기존 처리 여부 확인. 존재하면 기존 페이지 업데이트 모드 전환. (INDEX.md 전체 grep 금지 — `.sources` 캐시만 사용)
5. **Auto-context / Read related** — 먼저 `cd "/Users/hj/dot/nix-dots/files/workspace/.agents/skills/kb/scripts/kbtool" && go run . context -mode ingest -n 4 -min-score 20 "<Clipping path 또는 핵심 키워드>"` 실행. 후보 JSON은 참고 자료 후보일 뿐이며 새 출처의 주장을 기존 KB 프레임에 끼워 맞추지 않는다. 상위 1-4개 중 실제 관련성이 분명한 페이지만 읽고, 부족하면 qmd로 확장 검색 (`qmd vsearch "핵심 키워드" --json -n 5`)
6. **Extract concepts** — 기사에서 개념/기술/패턴을 추출. 각 개념에 대해:
   - 기존 topic 페이지 있음→새 정보를 기존 페이지에 통합 (출처 추가, 내용 보강)
     - 6a. 새 출처 주장과 기존 내용 비교
     - 6b. 모순 발견 → `[!warning] 논쟁` callout (SCHEMA.md 섹션 7)
     - 6c. 갱신 발견 → `[!info] 갱신` + 본문 수정 + `modified` 갱신
     - 6d. `kb-contradictions` frontmatter 업데이트
   - 기존 없음 + 충분한 내용→새 topic 페이지 생성
   - 기존 없음 + 내용 부족→관련 상위 개념 페이지의 하위 섹션으로
   - 분류 어려움→가장 가까운 방식 처리, LOG.md `classify-difficult` 기록
   - 하나의 기사가 여러 페이지에 기여 가능
7. **Write pages** — 개념별 페이지 생성/업데이트. 출처를 인라인 참조 (예: "(출처: [[Clipping명]])"). 위키링크 `[[파일명]]` 형식
   - 7b. 두 번째 corroborating source 도착 시, hedging 톤 → 확정 톤 전환 (SCHEMA.md Source Strength)
8. **Glossary check** — 작성한 페이지에 비전문가가 이해하기 어려운 전문 용어/개념이 등장하면 (예: MVCC, CRDT, OLAP, Raft, AST 등), 해당 개념의 glossary 페이지가 kb/에 있는지 확인. 없으면 간결한 설명 페이지 생성:
   - `tags`는 블록 형식으로 `- kb` + `- glossary` 포함
   - **`kb-sources` 필드는 통째로 생략**. Obsidian Properties UI가 빈 inline 배열(`[]`)을 제대로 렌더 못 함
9. **Freshness check** — 기사 발행일이 6개월 이상 지난 경우, library/framework/API 문서는 Context7 MCP를 우선 사용하고, MCP가 없으면 `ctx7 library <name> <query>` 후 `ctx7 docs <libraryId> <query>`를 사용한다. 일반 뉴스/웹 동향처럼 문서형 corpus가 아닌 경우에만 WebSearch로 확인한다. 유의미한 업데이트(메이저 버전, breaking change, 새 대안)가 있으면:
   - 9a. 페이지에 `## 최신 동향 (YYYY-MM)` 섹션 추가
   - 9b. 최신 동향이 본문과 모순 → 본문에 supersession 적용 (SCHEMA.md 섹션 7). 최신 동향 append만으로 끝내지 않음
10. **Refresh indexes** — rebuild-index workflow 전체 실행 (`cd "/Users/hj/dot/nix-dots/files/workspace/.agents/skills/kb/scripts/kbtool" && go run . rebuild-index` + `cd "/Users/hj/dot/nix-dots/files/workspace/.agents/skills/kb/scripts/kbtool" && go run . rebuild-sources`). 둘 다 필요: `rebuild-index`는 INDEX.md 재생성, `rebuild-sources`는 `.sources` 캐시 갱신. sources 갱신 누락 시 다음 ingest의 duplicate check가 이번 항목을 놓쳐 재처리됨
11. **Log** — LOG.md에 `## [날짜] ingest | Clipping 제목` 기록. glossary/freshness 생성 시 해당 내역도 기록
12. **Update search index** — vault에서 `qmd update && qmd embed` 실행하여 모든 페이지/generated/log 변경 이후 qmd 검색 인덱스 갱신

## Workflow: query

kb/ 위키 기반 질문 답변.

기본은 read-only다. 단, 사용자 질문에 "보강", "작성", "수정", "저장", "반영" 같은 corpus mutation intent가 명확하면 query는 context discovery 단계로만 사용하고, 이후 write/maintenance workflow로 전환한다.

1. **Auto-context** — `cd "/Users/hj/dot/nix-dots/files/workspace/.agents/skills/kb/scripts/kbtool" && go run . context -mode query -n 4 -min-score 20 "<question>"` 실행. 기존 KB 후보는 결론을 정하는 근거가 아니라 recall aid다. 상위 1-4개 중 질문과 직접 관련된 페이지만 먼저 읽고, 사용자 질문·최신/1차 근거와 충돌하면 사용자 질문·최신/1차 근거를 우선한다
2. **Search** — Auto-context가 부족하거나 질문이 넓으면 qmd로 확장 검색: `qmd query "질문" --json -n 10`. qmd 실패 시 INDEX.md + Grep 폴백
3. **Read pages** — 검색 결과 상위 페이지 읽음. 필요시 원본 Clipping 참조
4. **Deep search** — 읽은 페이지에서 추가 관련 페이지 위키링크 발견 시, `go run . context` 또는 qmd로 2차 검색하여 확장
5. **Synthesize** — 종합 답변 생성. 출처 명시. 기존 KB 내용은 참고 자료로 사용하고, 답변의 결론은 현재 질문과 확인된 근거에 맞춰 다시 판단
6. **Optionally save** — read-only query였다면 "이 답변 kb 페이지로 저장?" 제안. 이미 write intent가 명확했던 경우에는 묻지 않고 해당 범위 안에서 저장/수정 후 검증한다

## Workflow: crystallize

대화/작업 세션에서 범용 기술 지식을 kb/로 추출.

1. **Identify source** — 사용자에게 소스 확인: (a) 현재 세션 대화, (b) Hindsight에서 검색 (`/hindsight recall`), (c) 특정 파일 경로. 사용자가 "지금 조사한 인사이트를 KB에 작성"처럼 현재 세션을 명시하면 추가 확인 없이 현재 세션을 source로 사용한다
2. **Read session** — 세션 내용 읽기 (대화 로그, Hindsight 메모리, 또는 파일)
3. **Load schema** — `kb/SCHEMA.md` 읽음
4. **Extract wiki-worthy knowledge** — SCHEMA.md 섹션 5 Hindsight 라우팅 테이블 기준으로 필터:
   - ✅ 추출: 프로젝트 무관 기술 지식, 범용 패턴, 재사용 가능한 해결 방법
   - ❌ 제외: 프로젝트 특정 맥락, 사용자 선호, 세션 특정 상태
5. **Match existing / Auto-context** — 각 추출 개념마다 `cd "/Users/hj/dot/nix-dots/files/workspace/.agents/skills/kb/scripts/kbtool" && go run . context -mode crystallize -n 4 -min-score 20 "<개념>"` 실행 후 상위 1-4개 중 직접 관련된 후보만 읽음. 기존 KB는 참고 자료이며, 세션 지식을 기존 페이지에 억지로 맞추지 않는다. 필요하면 qmd로 확장 (`qmd vsearch "개념" --json -n 5`)
6. **Integrate** — ingest steps 6-7과 동일 (개념 추출, 페이지 생성/업데이트). 소스 형식만 다름:
   ```yaml
   kb-sources:
     - "session:YYYY-MM-DD/주제-설명"
   ```
7. **Glossary + Freshness** — ingest steps 8-9와 동일
8. **Refresh indexes** — rebuild-index workflow 전체 실행 (`cd "/Users/hj/dot/nix-dots/files/workspace/.agents/skills/kb/scripts/kbtool" && go run . rebuild-index` + `cd "/Users/hj/dot/nix-dots/files/workspace/.agents/skills/kb/scripts/kbtool" && go run . rebuild-sources`). sources 캐시 갱신 필수
9. **Log** — LOG.md에 `## [날짜] crystallize | 세션 주제` 기록
10. **Update search index** — vault에서 `qmd update && qmd embed` 실행

## Workflow: lint

위키 건강 점검·스키마 진화 제안. 기계적 스캔은 전부 `cd "/Users/hj/dot/nix-dots/files/workspace/.agents/skills/kb/scripts/kbtool" && go run . lint`에 위임.

1. **Rebuild index** — rebuild-index workflow 전체 실행 (INDEX.md + `.sources` 캐시 최신화)
2. **qmd update && qmd embed** — 검색 인덱스 갱신
3. **Integrity + gap scan** — `cd "/Users/hj/dot/nix-dots/files/workspace/.agents/skills/kb/scripts/kbtool" && go run . lint` → 단일 JSON 출력:
   - `broken_wikilinks`, `frontmatter_violations`, `dead_source_refs`
   - `single_source_pages`, `empty_source_pages`
   - `unresolved_conflicts`, `unprocessed_clippings`, `stale_recent_sections`, `orphan_pages` (glossary 제외)
   - `classify_difficult`, `roadmap` (page_count + earliest created)
4. **Schema evolution** — JSON의 `classify_difficult` 검사. 패턴 발견 시 새 타입 제안 (SCHEMA.md 진화 프로토콜, before/after 비교)
5. **Roadmap check** — `roadmap.page_count`와 `kb/ROADMAP.md` milestone 대조. 충족 + `[완료]` 아닐 경우 "진화 제안" 섹션 포함. 승인 시 구현 + milestone 완료 기록. 거부 시 `[연기: 사유]` 기록
6. **Report** — JSON을 한국어 사용자용 리포트로 변환, severity별 그룹화 + 권장 조치 명시

## Workflow: rebuild-index

kb/ 스캔→INDEX.md + `.sources` 캐시 재생성. **LLM 개입 없음** — Go tool·qmd 호출.

1. `cd "/Users/hj/dot/nix-dots/files/workspace/.agents/skills/kb/scripts/kbtool" && go run . rebuild-index` — end-to-end 수행:
   - `kb/*.md` Glob (SCHEMA/INDEX/LOG/ROADMAP 제외)
   - frontmatter(`kb-type`, `created`, `tags`) + 첫 문단 파싱
   - 태그→도메인 섹션 그룹핑 (Nix/Container, Elixir/Phoenix, CSS, Frontend/JavaScript, Database, AI/LLM, Glossary, Health/Science), 섹션 내 `created` 내림차순
   - Health 블록 append (총 페이지, 단일 출처, 미해결 논쟁, 최신 동향 만료, 고아 페이지)
   - INDEX.md atomic 덮어쓰기 (tmp + rename). INDEX.md는 navigation page이므로 `publish: true` 유지
2. `cd "/Users/hj/dot/nix-dots/files/workspace/.agents/skills/kb/scripts/kbtool" && go run . rebuild-sources` — `.sources` 캐시 갱신. ingest duplicate check의 단일 진실원천
3. `qmd update && qmd embed` — 검색 인덱스 갱신

섹션 매핑 변경: `scripts/kbtool/rebuild.go`의 `sectionRules` 편집 후 `cd "/Users/hj/dot/nix-dots/files/workspace/.agents/skills/kb/scripts/kbtool" && go run . rebuild-index`로 검증.

## Subagent 위임

Codex delegation/model policy는 repo AGENTS.md를 따른다. KB-specific default는 main thread에서 SCHEMA/context/source 판단을 유지하는 것이다. 사용자가 delegation/subagent를 명시한 경우에만 bounded task를 위임하고, 독립 shell read/search는 `multi_tool_use.parallel`로 병렬화한다.

## Rules

- SCHEMA.md 매 오퍼레이션 시작 시 필수 읽기
- Clippings/ 외 파일 ingest 금지
- Dev/ 노트 수정 금지 (위키링크 참조만)
- ingest 중 타입 제안 금지 (lint에서만)
- 위키링크 Obsidian 짧은 형식: `[[파일명]]` (경로 prefix 금지). kb 페이지명은 vault 전체(특히 Clippings/)에서 유일 (SCHEMA §6)
- 페이지 생성 시 obsidian-markdown 스킬 frontmatter/위키링크 규칙 준수
- qmd collection 미등록 시 자동 등록 후 진행
- crystallize는 Hindsight→kb/ 단방향. 프로젝트 특정 지식은 Hindsight에만 저장
