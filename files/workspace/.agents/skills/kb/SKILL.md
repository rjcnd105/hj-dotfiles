---
name: kb
description: Clippings 종합하는 AI 위키. ingest로 외부 기사→종합 페이지 변환, query로 위키 기반 답변 생성, lint로 위키 건강 점검·스키마 진화 제안.
---

# KB Wiki

Clippings/(외부 기사, 논문) 종합·교차참조 위키 유지. Karpathy LLM Wiki 패턴 기반.

## Preamble

**Vault 경로**: `/Users/hj/Library/Mobile Documents/iCloud~md~obsidian/Documents/Brain`

모든 경로는 이 vault 기준. 다른 레포에서 실행해도 vault 절대 경로 사용.
모든 오퍼레이션 전 `kb/SCHEMA.md` 읽음. SCHEMA.md = 위키 규칙.

## Search: qmd

kb/ 검색에 qmd 사용. 글로벌 설치됨 (`qmd`).

**초기 설정** (collection 미등록 시):
```bash
qmd collection add "kb/" --name kb
qmd embed
```

**검색 명령**:
- `qmd search "keyword" --json -n 10` — BM25 키워드 검색 (빠름)
- `qmd vsearch "자연어 질문" --json -n 10` — 시맨틱 벡터 검색
- `qmd query "질문" --json -n 10` — 하이브리드 + LLM 리랭킹 (최고 품질)

**사용 시점**: INDEX.md는 human-readable 카탈로그로 유지. 실제 페이지 탐색은 qmd 우선 사용. qmd 실패 시 INDEX.md + Grep 폴백.

## Commands

Arguments 파싱→서브커맨드 결정:

| 입력 패턴 | 서브커맨드 |
|-----------|-----------|
| `/kb ingest <path>` | ingest |
| `/kb ingest` (경로 없음) | Clippings/ 미처리 파일 목록 표시, 선택 |
| `/kb query <question>` | query |
| `/kb lint` | lint |
| `/kb rebuild-index` | rebuild-index |
| `/kb crystallize` | crystallize |

## Tools

기계적 스캔·재생성을 바이너리·쉘로 위임하여 Claude 토큰 소비 최소화.

### Binary: `scripts/kbtool-bin` (Go, stdlib-only)

소스: `scripts/kbtool/`. 리빌드: `cd scripts/kbtool && go build -o ../kbtool-bin .`.

| 서브커맨드 | 역할 | Latency |
|-----------|------|---------|
| `kbtool-bin lint` | 단일 JSON 출력: broken wikilinks, frontmatter violations, dead source refs, single/empty source pages, unresolved conflicts, unprocessed clippings, stale 최신 동향, orphan pages, classify-difficult, roadmap | ~20ms hot |
| `kbtool-bin rebuild-index` | INDEX.md 결정론적 재생성 (frontmatter + tags → 도메인 섹션, Health 블록 append, atomic write) | ~20ms hot |

LLM은 JSON 읽기만 수행. 페이지 직접 스캔 금지.

### Shell scripts

- `scripts/unprocessed.sh [--all | -n N]` — `Clippings/` vs `kb/.sources` diff. 기본 첫 20개
- `scripts/rebuild-sources.sh` — kb 페이지 frontmatter의 `kb-sources` 항목을 `kb/.sources`로 집계. 메타 파일(SCHEMA/INDEX/LOG/ROADMAP) 제외

`kb/.sources`는 캐시. 수동 편집 금지 — `rebuild-sources.sh`로 재생성.

## Workflow: ingest

단일 Clipping 읽고 kb/ 페이지 생성/업데이트.

경로 지정 없이 `/kb ingest` 호출 시: `bash scripts/unprocessed.sh` 실행하여 미처리 목록 표시 (기본 20개). 사용자 선택 후 각 파일을 아래 워크플로우로 처리.

1. **Read** — 대상 Clipping 읽음. 빈 본문→LOG.md `skip` 기록 후 종료
2. **Load schema** — `kb/SCHEMA.md` 읽음 (타입 목록, 규칙, frontmatter 스키마)
3. **Load index** — `kb/INDEX.md` 읽음. 없으면 rebuild-index 먼저 실행
4. **Check duplicates** — `grep -Fx "Clippings/$name" kb/.sources` 로 기존 처리 여부 확인. 존재하면 기존 페이지 업데이트 모드 전환. (INDEX.md 전체 grep 금지 — `.sources` 캐시만 사용)
5. **Read related** — qmd로 관련 주제 기존 kb 페이지 검색 (`qmd vsearch "핵심 키워드" --json -n 5`), 찾은 페이지 읽음
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
9. **Freshness check** — 기사 발행일이 6개월 이상 지난 경우, WebSearch로 해당 기술의 최신 동향 확인. 유의미한 업데이트(메이저 버전, breaking change, 새 대안)가 있으면:
   - 9a. 페이지에 `## 최신 동향 (YYYY-MM)` 섹션 추가
   - 9b. 최신 동향이 본문과 모순 → 본문에 supersession 적용 (SCHEMA.md 섹션 7). 최신 동향 append만으로 끝내지 않음
10. **Update search index** — `qmd embed` 실행하여 qmd 검색 인덱스 갱신
11. **Refresh indexes** — rebuild-index workflow 전체 실행 (`scripts/kbtool-bin rebuild-index` + `bash scripts/rebuild-sources.sh`). 둘 다 필요: binary는 INDEX.md 재생성, shell script는 `.sources` 캐시 갱신. sources 갱신 누락 시 다음 ingest의 duplicate check가 이번 항목을 놓쳐 재처리됨
12. **Log** — LOG.md에 `## [날짜] ingest | Clipping 제목` 기록. glossary/freshness 생성 시 해당 내역도 기록

## Workflow: query

kb/ 위키 기반 질문 답변.

1. **Search** — qmd로 관련 페이지 검색: `qmd query "질문" --json -n 10`. qmd 실패 시 INDEX.md + Grep 폴백
2. **Read pages** — 검색 결과 상위 페이지 읽음. 필요시 원본 Clipping 참조
3. **Deep search** — 읽은 페이지에서 추가 관련 페이지 위키링크 발견 시, qmd로 2차 검색하여 확장
4. **Synthesize** — 종합 답변 생성. 출처 명시
5. **Optionally save** — "이 답변 kb 페이지로 저장?" 제안. 승인 시 적절한 타입으로 저장

## Workflow: crystallize

대화/작업 세션에서 범용 기술 지식을 kb/로 추출.

1. **Identify source** — 사용자에게 소스 확인: (a) 현재 세션 대화, (b) Hindsight에서 검색 (`/hindsight recall`), (c) 특정 파일 경로
2. **Read session** — 세션 내용 읽기 (대화 로그, Hindsight 메모리, 또는 파일)
3. **Load schema** — `kb/SCHEMA.md` 읽음
4. **Extract wiki-worthy knowledge** — SCHEMA.md 섹션 5 Hindsight 라우팅 테이블 기준으로 필터:
   - ✅ 추출: 프로젝트 무관 기술 지식, 범용 패턴, 재사용 가능한 해결 방법
   - ❌ 제외: 프로젝트 특정 맥락, 사용자 선호, 세션 특정 상태
5. **Match existing** — qmd로 각 추출 개념 검색 (`qmd vsearch "개념" --json -n 5`). 기존 페이지 읽음
6. **Integrate** — ingest steps 6-7과 동일 (개념 추출, 페이지 생성/업데이트). 소스 형식만 다름:
   ```yaml
   kb-sources:
     - "session:YYYY-MM-DD/주제-설명"
   ```
7. **Glossary + Freshness** — ingest steps 8-9와 동일
8. **Update search index** — `qmd embed` 실행
9. **Refresh indexes** — rebuild-index workflow 전체 실행 (`scripts/kbtool-bin rebuild-index` + `bash scripts/rebuild-sources.sh`). sources 캐시 갱신 필수
10. **Log** — LOG.md에 `## [날짜] crystallize | 세션 주제` 기록

## Workflow: lint

위키 건강 점검·스키마 진화 제안. 기계적 스캔은 전부 `kbtool-bin lint`에 위임.

1. **Rebuild index** — rebuild-index workflow 전체 실행 (INDEX.md + `.sources` 캐시 최신화)
2. **qmd embed** — 검색 인덱스 갱신
3. **Integrity + gap scan** — `scripts/kbtool-bin lint` → 단일 JSON 출력:
   - `broken_wikilinks`, `frontmatter_violations`, `dead_source_refs`
   - `single_source_pages`, `empty_source_pages`
   - `unresolved_conflicts`, `unprocessed_clippings`, `stale_recent_sections`, `orphan_pages` (glossary 제외)
   - `classify_difficult`, `roadmap` (page_count + earliest created)
4. **Schema evolution** — JSON의 `classify_difficult` 검사. 패턴 발견 시 새 타입 제안 (SCHEMA.md 진화 프로토콜, before/after 비교)
5. **Roadmap check** — `roadmap.page_count`와 `kb/ROADMAP.md` milestone 대조. 충족 + `[완료]` 아닐 경우 "진화 제안" 섹션 포함. 승인 시 구현 + milestone 완료 기록. 거부 시 `[연기: 사유]` 기록
6. **Report** — JSON을 한국어 사용자용 리포트로 변환, severity별 그룹화 + 권장 조치 명시

## Workflow: rebuild-index

kb/ 스캔→INDEX.md + `.sources` 캐시 재생성. **LLM 개입 없음** — 바이너리·쉘·qmd 3연속 호출.

1. `scripts/kbtool-bin rebuild-index` — end-to-end 수행:
   - `kb/*.md` Glob (SCHEMA/INDEX/LOG/ROADMAP 제외)
   - frontmatter(`kb-type`, `created`, `tags`) + 첫 문단 파싱
   - 태그→도메인 섹션 그룹핑 (Nix/Container, Elixir/Phoenix, CSS, Frontend/JavaScript, Database, AI/LLM, Glossary, Health/Science), 섹션 내 `created` 내림차순
   - Health 블록 append (총 페이지, 단일 출처, 미해결 논쟁, 최신 동향 만료, 고아 페이지)
   - INDEX.md atomic 덮어쓰기 (tmp + rename)
2. `bash scripts/rebuild-sources.sh` — `.sources` 캐시 갱신. ingest duplicate check의 단일 진실원천
3. `qmd embed` — 검색 인덱스 갱신

섹션 매핑 변경: `scripts/kbtool/rebuild.go`의 `sectionRules` 편집 후 바이너리 리빌드.

## Subagent 위임

추론 부하 낮은 단계는 sonnet 서브에이전트에 위임하여 속도·비용 최적화.

| 단계 | 모델 | 이유 |
|------|------|------|
| Read related (5번) | **sonnet** | 검색+읽기, 판단 불필요 |
| Glossary check (8번) | **sonnet** | 용어 존재 확인+간결한 정의 생성 |
| Extract concepts (6번) | opus (기본) | 핵심 판단: 개념 추출·분류 |
| Write pages (7번) | opus (기본) | 종합 작성, 교차참조 |
| Freshness check (9번) | opus (기본) | 웹 검색+판단+반영 |

서브에이전트 스폰 시 `model: "sonnet"` 파라미터 명시.

## Rules

- SCHEMA.md 매 오퍼레이션 시작 시 필수 읽기
- Clippings/ 외 파일 ingest 금지
- Dev/ 노트 수정 금지 (위키링크 참조만)
- ingest 중 타입 제안 금지 (lint에서만)
- 위키링크 Obsidian 짧은 형식: `[[파일명]]` (경로 prefix 금지). kb 페이지명은 vault 전체(특히 Clippings/)에서 유일 (SCHEMA §6)
- 페이지 생성 시 obsidian-markdown 스킬 frontmatter/위키링크 규칙 준수
- qmd collection 미등록 시 자동 등록 후 진행
- crystallize는 Hindsight→kb/ 단방향. 프로젝트 특정 지식은 Hindsight에만 저장
