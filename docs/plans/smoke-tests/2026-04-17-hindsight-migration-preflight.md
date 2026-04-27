# Hindsight 데이터 마이그레이션 Pre-flight 실측

**Plan**: [docs/plans/2026-04-17-002-feat-hindsight-data-migration-cutover-plan.md](../2026-04-17-002-feat-hindsight-data-migration-cutover-plan.md)
**실측 시작**: 2026-04-17

## 1. Homelab 측 (완료)

### hindsight-admin CLI 존재 + 버전

- 경로: `/app/api/.venv/bin/hindsight-admin` (hindsight 0.5.2-slim 컨테이너 내장)
- 지원 명령: `backup`, `restore`, `run-db-migration`, `decommission-worker` — plan Unit 3 시나리오 전부 커버

### DB 테이블 스키마

- 현재 상태: **빈 DB** — 15개 테이블 생성됨(`alembic_version`, `async_operations`, `audit_log`, `banks`, `chunks`, `directives`, `documents`, `entities`, `entity_cooccurrences`, `file_storage`, `memory_links`, `memory_units`, `mental_models`, `unit_entities`, `webhooks`)
- **Plan 내 테이블명 보정**: Plan의 `memories`/`embeddings` 참조는 실제 스키마와 불일치. 올바른 테이블명은 `memory_units` (embedding 컬럼 포함 단일 테이블).

### `memory_units` 주요 컬럼 (재임베딩 스크립트 설계 근거)

| 컬럼 | 타입 | 비고 |
|---|---|---|
| `id` | `uuid` | PK, `gen_random_uuid()` |
| `bank_id` | `text` | not null |
| `text` | `text` | not null — **재임베딩 원문 source** |
| `embedding` | `vector(1024)` | nullable — 재임베딩 대상 컬럼 |
| `event_date`, `occurred_start`, `occurred_end`, `mentioned_at` | `timestamptz` | memory 고유 시간축 (보존 대상) |
| `fact_type` | `text` | `'world'` 기본, `'experience'` 등 |
| `created_at`, `updated_at` | `timestamptz` | `not null default now()` |
| `metadata` | `jsonb` | `{}` 기본 |
| `tags` | `varchar[]` | `{}` 기본 |

### `chunks` 주요 컬럼

- `(chunk_id PK, document_id FK, bank_id, chunk_index, chunk_text, created_at, content_hash)` — embedding 없음
- `memory_units.chunk_id` → `chunks.chunk_id` FK (ON DELETE CASCADE)

### 재임베딩 SQL 골격 (Unit 3 B 전략)

```sql
-- UPDATE 문: embedding만 갱신, created_at·updated_at·event_date·bank_id 등 불변
-- (단, trigger가 updated_at을 자동 갱신하는지 Unit 3에서 확인 필요)
UPDATE memory_units
SET embedding = :new_vector::vector(1024)
WHERE id = :memory_id;
```

- 사용자 요구(원본 timestamp 유지)가 스키마 차원에서 자연히 충족됨 — embedding 컬럼 외 다른 필드 미터치
- `updated_at` 자동 갱신 트리거 존재 여부는 Unit 3 실행 직전 `\d+ memory_units`로 재확인

### 0.5.0 → 0.5.2 Schema migration 평가

- 릴리즈 노트(v0.5.1, v0.5.2) 약 80 PR 훑어본 결과, DB schema 관련 PR 제목 **없음**. 대부분 openclaw/opencode 클라이언트, retain/recall 알고리즘, CLI 개선, 문서 업데이트
- 결론: `hindsight-admin run-db-migration`은 **no-op 또는 minor**일 가능성 높음. 단, alembic이 실제 migration 파일 diff를 내놓는지 Unit 3 실행 시 output으로 최종 확인

### 확인 명령 (재현용)

```bash
ssh homelab "podman exec hindsight which hindsight-admin"
ssh homelab "podman exec hindsight hindsight-admin --help"
ssh homelab "podman exec hindsight-db psql -U hindsight -d hindsight -c '\dt'"
ssh homelab "podman exec hindsight-db psql -U hindsight -d hindsight -c '\d memory_units'"
```

## 2. VPS 측 (완료 — 2026-04-17)

접속 경로: sops-decrypt된 `vps.enc.yaml`에서 host/port/user/docker_ssh 추출, 임시 key 파일 생성 후 단일 ssh 세션. 값은 쉘 변수에만 유지, 출력에 비노출.

### 실측 결과

| 항목 | 값 | 비고 |
|---|---|---|
| `hindsight-admin` CLI | 있음 (`/app/api/.venv/bin/hindsight-admin`) | VPS 0.5.0에도 내장 확인 |
| 지원 명령 | backup / restore / run-db-migration / decommission-worker | plan Unit 3 전 시나리오 커버 |
| memory_units rows | **3,740** | 재임베딩 대상 |
| chunks rows | 2,231 | text 원문 저장소 |
| banks rows | 3 | |
| documents rows | 150 | |
| entities rows | 2,844 | |
| async_operations status | completed 356 / failed 65 / **pending·processing = 0** | worker quiescent — cutover 타이밍 자유 |
| memory_units 주요 columns | id·bank_id·text·embedding(vector)·event_date·created_at·updated_at | timestamp 보존 가능 |
| **updated_at auto-trigger** | **없음** (`pg_trigger` 0 rows) | 재임베딩 UPDATE가 `updated_at` 건드리지 않음 — 제약 자연 충족 |
| Backup zip 크기 (dry-run) | **19MB** / 199,307 rows across 8 tables | 압축률 높음 (logical backup) |
| Volume 크기 (참고) | 1.033GB | logical backup과 무관 |

### Extension 버전 비교

| Extension | VPS 0.5.0 | Homelab 0.5.2 | 판정 |
|---|---|---|---|
| pg_textsearch | 1.0.0 | 1.0.0 | 동일 |
| pg_trgm | 1.6 | — (homelab에서 미확인, timescale 기본 포함 추정) | 무관 (logical backup) |
| timescaledb | 2.26.1 | 2.26.3 | minor drift, backward compatible |
| timescaledb_toolkit | 1.22.0 | 1.22.0 | 동일 |
| vector | 0.8.2 | 0.8.2 | 동일 |

logical backup은 행 단위 copy이므로 extension 버전 drift는 **restore 성공과 무관**. 선행 플랜 P0-4 리스크 해소.

### 다운타임 재산정

| 구간 | 예상 시간 |
|---|---|
| Write 차단 시작 (플러그인·스킬 일시 중지) | 즉시 |
| `hindsight-admin backup` 생성 | 수 초 (19MB) |
| scp VPS → Mac → homelab | 1-2분 (19MB × 2 hops, 가정 대역폭 30+Mbps) |
| `hindsight-admin restore --yes` | 수 초 ~ 수십 초 |
| `hindsight-admin run-db-migration` | 0.5.0→0.5.2 application 중심 변경이라 no-op 예상 |
| 재임베딩 (3,740 memory × harrier ~50-150ms/건) | **5-10분** (배치 API 호출 시 단축 가능) |
| **총 체감 다운타임** | **≈ 5-15분** (당초 30분 placeholder 대비 축소) |

### 재확인 명령 (기록용 — 실전 Unit 3에서 재사용)

접속은 sops-decrypt된 자격증명을 1회 shell 변수 로드 후 단일 ssh 세션으로 수행. 개별 커맨드는 다음 blob(REMOTE_SCRIPT)에 포함:
- `podman exec hindsight hindsight-admin backup /tmp/hsdb-$(date +%Y%m%d).zip`
- `podman cp hindsight:/tmp/hsdb-*.zip ~/` → Mac 경유 scp
- homelab에서 `podman exec hindsight hindsight-admin restore /tmp/hsdb-*.zip --yes`
- `podman exec hindsight hindsight-admin run-db-migration`
- `systemctl restart hindsight.service`

## 3. 남은 블로커 요약

- [x] VPS 접속 경로 확보 (sops decrypt + 임시 key 단일 세션)
- [x] Homelab 측 pre-flight 완료
- [x] VPS 측 pre-flight 완료
- [x] Unit 2 임베딩 전략 결정: **B (재임베딩, 원본 timestamp 유지)**
- [ ] 재임베딩 스크립트 설계/실행 상태 확인 (Unit 3 하위 step 또는 별도 분기 플랜)
- [x] Unit 4 CF Tunnel ingress 전환 (구현됨; runtime active, recall smoke는 rerank input guard 배포 후 재검증 필요)
- **2026-04-27 상태:** manual `boot` activation 뒤 homelab은 `26.05.20260422.0726a0e`로 부팅 성공. `/run/current-system/activate` 이후 `/run/secrets/rendered/services.env`와 `/run/secrets/cloudflared-credentials`가 생성됐고, `hindsight-db.service`, `hindsight.service`, `cloudflared-tunnel-a19003a7-293f-4872-b8a5-1db544878f45.service`, `llama-swap.service`, `embed-prefix-proxy.service`는 active. `systemctl list-units --failed`는 empty, `curl http://127.0.0.1:8888/health`는 200. 남은 blocker는 recall smoke 중 llama.cpp `/v1/rerank` 400이며, 원인은 긴 DB candidate text가 reranker input limit을 넘는 케이스로 판단. Live qwen reranker는 `--ctx-size 2048 --parallel 8` 때문에 per-sequence context가 256 tokens라 384-character repeated-token doc부터 400을 재현했다. `embed-prefix-proxy` rerank input guard와 qwen reranker context/batch 상향 배포 후 재확인 필요.

## 4. Unit 3 재임베딩 스크립트 설계 힌트

- Source: `SELECT id, text FROM memory_units WHERE embedding IS NOT NULL` (3,740 건)
- harrier 호출 경로: homelab `http://127.0.0.1:8091/v1/embeddings` (prefix-proxy) — **batching 지원 확인 후 batch로**. 단건 호출 시 3,740 × 50-150ms, batch 32건씩이면 실제 로드 시간 대폭 감소
- Update: `UPDATE memory_units SET embedding = $2::vector(1024) WHERE id = $1` (updated_at 자동 갱신 없음 확정)
- 체크포인트: 배치마다 progress 로그 + 실패 row id 수집 → 재시도
- 언어 선택: Python + `psycopg[binary]` + `httpx` 또는 기존 `embed-prefix-proxy` 재활용 (FastAPI 코드 참조)
