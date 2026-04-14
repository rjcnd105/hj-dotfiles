---
git-sha: c1e3b32e0f6ad7b1fafa0bc869134e6c4d6c516b
date: 2026-04-14
status: brainstorm-complete
next-step: implementation-plan
---

# VPS → Homelab 마이그레이션 요구사항

VPS에서 운영 중인 hindsight RAG 스택을 homelab (NixOS minipc, AMD HX 370)으로 이전하고, arcane 같은 imperative 도구를 제거하고 NixOS 선언형으로 재구성한다.

## 배경 & 동기

사용자 우선순위(북극성):

1. **VPS 비용 + 업체 lock-in 탈출** — 업체 바꿀 때마다의 번거로움을 없애고, 하드웨어/호스트가 바뀌어도 선언형 설정 재적용만으로 재구축 가능해야 함
2. **NixOS 선언형·이식성** — `arcane` 같은 imperative Docker UI 대신 `configuration.nix` 자체가 소스 오브 트루스
3. **AI 추론 비용 점진 감소** — 추론 비용 작은 것(embedding) 부터 하나씩 로컬화. LLM 본체는 당분간 외부 API 유지

## Scope

### 포함 (Phase 1 — 이번 마이그레이션)

- VPS 측 `sync/services/docker-compose.yml` 전체 스택을 homelab으로 이전
- **arcane 완전 제거** (NixOS `virtualisation.oci-containers`가 대체)
- **Caddy 제거** (Cloudflare Tunnel이 TLS + 라우팅 흡수)
- hindsight `0.5.0` → `0.5.1-slim` 전환 (대시보드 9999 포트 제거, API만)
- **TEI 로컬 embedding** 도입 (BAAI/bge-m3)
- **TEI 로컬 reranker** 도입 (BAAI/bge-reranker-v2-m3) — Jina API 토큰 소진으로 Phase 2에서 Phase 1로 앞당김
- 기존 TimescaleDB 데이터 volume 이전 (tar 복사)
- `deopjib.site` DNS 전환 (VPS → CF Tunnel → homelab)
- `arcane.deopjib.site` 서브도메인 삭제
- NixOS iGPU(Radeon 890M) Vulkan/ROCm 활성화

### 제외 (Phase 2 이후)

- LiteLLM proxy / Ollama / Open WebUI (범용 AI 스택 확장)
- LLM 로컬화 (reflect/retain/main 전부 외부 API 유지; Gemma-4-31b는 iGPU VRAM 부족으로 로컬 불가)
- Cloudflare Access OAuth proxy (PR #922) — 지금은 API-key로 충분
- **외부 SSH 뒷구멍 신규 구축** — **불필요**. 가정 ISP 유동 공인 IP + 기존 iptime DDNS + 공유기 비표준 포트 포워딩으로 이미 확보됨. homelab NixOS에 `services.openssh.enable = true` + pubkey-only + `services.fail2ban`만 설정하면 완성

## 목표 아키텍처

```
homelab (NixOS, AMD HX 370, Radeon 890M)
│
├─ services.cloudflared (Cloudflare Tunnel)
│    └─ hindsight.deopjib.site → hindsight:8888  (API only)
│
├─ virtualisation.oci-containers.containers
│    ├─ hindsight        (ghcr.io/vectorize-io/hindsight:0.5.1-slim)
│    │     ├─ EMBEDDINGS_PROVIDER=tei → tei-embed:80
│    │     ├─ RERANKER_PROVIDER=tei → tei-rerank:80 (Cohere-compatible path)
│    │     ├─ LLM: OpenRouter(Gemma-4-31b), Groq(gpt-oss-20b)
│    │     ├─ DB: postgresql://hindsight-db:5432
│    │     └─ TENANT: ApiKeyTenantExtension
│    │
│    ├─ hindsight-db     (timescale/timescaledb-ha:pg18)
│    │     └─ volume: hindsight-db-data (VPS 볼륨 tar 복사로 이전)
│    │
│    ├─ tei-embed        (ghcr.io/huggingface/text-embeddings-inference:cpu-latest)
│    │     ├─ model: BAAI/bge-m3
│    │     └─ CPU 추론 (iGPU는 Phase 2 LLM용으로 남겨둠)
│    │
│    └─ tei-rerank       (ghcr.io/huggingface/text-embeddings-inference:cpu-latest)
│          ├─ model: BAAI/bge-reranker-v2-m3
│          └─ CPU 추론 (0.568B, 12C/24T HX 370에서 실용적)
│
└─ (제거됨) arcane, caddy, arcane.deopjib.site
```

**공유 볼륨 패턴** (Phase 2+ 확장 고려):
- `hf_cache:/data` — tei-embed, tei-rerank, 향후 ComfyUI 등이 공유하는 HuggingFace 모델 캐시
- `hindsight-db-data` — TimescaleDB 전용

**제거되는 VPS 쪽 구성 요소**:
- `arcane` 서비스 + `arcane-data` 볼륨
- `caddy` 서비스 + `caddy-data`, `caddy-config` 볼륨
- `Caddyfile`의 `arcane.deopjib.site` 및 `hindsight:9999` 라우팅
- mise-based 배포 자동화 (comin GitOps로 대체)

## 주요 결정 (16개 체크리스트)

| # | 결정 | 근거/메모 |
|---|---|---|
| 1 | VPS 전체 스택 → homelab 이전 | 비용 + lock-in |
| 2 | 노출 레이어: Cloudflare Tunnel 단독 | 공인 IP/CGNAT 무관, NixOS `services.cloudflared` 공식 모듈 |
| 3 | arcane 완전 제거 | NixOS 선언형이 "Docker 관리 UI" 역할 흡수 |
| 4 | Caddy 제거 | CF Tunnel이 TLS/라우팅 흡수 |
| 5 | `arcane.deopjib.site` 삭제, `hindsight.deopjib.site`만 유지 | |
| 6 | hindsight 이미지: `0.5.1-slim` | 대시보드 제거, 외부 embedding/reranker로 분리 가능 |
| 7 | hindsight-db: `timescale/timescaledb-ha:pg18` 그대로 | pg_textsearch 확장이 이미지 내 번들, nixpkgs 이식 회피 |
| 8 | DB 이전: volume tar 복사 | 공식 dump/restore 가이드 없음, volume 복사가 안전 |
| 9 | NixOS 구성: `virtualisation.oci-containers` 선언형 | arion은 Phase 2 이후 고려 |
| 10 | Embedding: TEI 로컬 + BAAI/bge-m3, **CPU 추론** | iGPU는 Phase 2 LLM에 양보. 0.5B 모델 CPU로 충분 |
| 11 | Reranker: TEI 로컬 + **BAAI/bge-reranker-v2-m3, CPU 추론** | Jina 토큰 소진으로 Phase 1 편입. 한국어 벤치 2위(0.81), Apache 2.0, TEI 실질 작동(공식 명시 없지만 XLM-RoBERTa 아키텍처라 구동) |
| 12 | LLM: 외부 API 유지 (OpenRouter, Groq) | 31B 모델 iGPU 불가, reflect(20B)는 Phase 3 실험 |
| 13 | iGPU(Radeon 890M) Vulkan 활성화는 Phase 2에서 | Phase 1은 CPU 전용. Phase 2 LLM 도입 시 `hardware.amdgpu` + llama.cpp Vulkan 백엔드 |
| 14 | OAuth proxy 도입 | 보류. 현 API-key로 충분. Phase 2 재검토 |
| 15 | 실행 전략: Dry-run first | ~20분 cutover, 재시작 실패 위험 낮음 |
| 16 | SSH 외부 접근: 신규 구축 불필요 | 기존 iptime DDNS + 공유기 비표준 포트포워딩으로 이미 확보. `services.openssh.enable` + pubkey-only + fail2ban만 설정 |

## 실행 전략 (Dry-run first)

### Step 1 — homelab NixOS 모듈 작성 (VPS 미중단)

- `systems/homelab/`에 신규 모듈 추가:
  - `services.cloudflared` 설정 (CF 대시보드에서 tunnel 생성 + credentials을 sops-nix로 암호화 저장)
  - `virtualisation.oci-containers.containers.{hindsight, hindsight-db, tei-embed, tei-rerank}` 선언
  - 공유 볼륨: `hf_cache` (tei-embed, tei-rerank가 공유)
  - `sharedHome` 재사용 여부 검토
  - (iGPU Vulkan은 Phase 2 LLM 도입 시 활성화)
- secrets: `secrets/homelab/services.yaml` 신설 (`HINDSIGHT_DB_PASSWORD`, `OPENROUTER_API_KEY`, `GROQ_API_KEY`, `HINDSIGHT_API_TENANT_API_KEY`, CF Tunnel credentials) — Jina는 토큰 소진으로 제거

### Step 2 — homelab에서 빈 스택으로 dry-run

- `just darwin-switch` 또는 homelab의 동등 명령으로 적용 (homelab은 NixOS이므로 `nixos-rebuild switch`)
- `hindsight-db` 빈 상태 기동 확인
- hindsight API `/health` 호출 검증
- **tei-embed** `/embed` 호출 검증 (bge-m3 모델 다운로드 완료 확인, 쿼리 50-150ms 기대)
- **tei-rerank** `/rerank` 호출 검증 (bge-reranker-v2-m3 다운로드, 쿼리-문서 쌍 20-60ms 기대)
- hindsight `/v1/recall` 통합 smoke test (빈 DB라 결과 없어도 에러 없어야 함)
- CF Tunnel 임시 서브도메인(예: `hindsight-test.deopjib.site`)으로 외부 도달 가능 확인

### Step 3 — 데이터 컷오버 (다운타임 ~20분)

1. VPS에서 `docker compose down`
2. `docker run --rm -v hindsight-db-data:/src -v $PWD:/dst alpine tar czf /dst/hsdb-$(date +%Y%m%d).tar.gz -C /src .`
3. `scp hsdb-*.tar.gz homelab:~/` 혹은 `rsync`
4. homelab에서 `hindsight-db` 컨테이너 정지, volume 풀기:
   ```
   docker compose -f /var/lib/hindsight/compose.yml stop hindsight-db
   docker run --rm -v hindsight-db-data:/dst -v ~/:/src alpine sh -c 'rm -rf /dst/* && tar xzf /src/hsdb-*.tar.gz -C /dst'
   docker compose -f /var/lib/hindsight/compose.yml start hindsight-db
   ```
5. hindsight 컨테이너 재기동 (새 DB 연결 확인)
6. recall 샘플 쿼리로 데이터 정합성 smoke test

### Step 4 — DNS 컷오버

- Cloudflare에서 `hindsight.deopjib.site` CNAME/Tunnel을 homelab tunnel로 재지정
- TTL 짧게 설정해두기 (60s)
- `arcane.deopjib.site` 레코드 삭제
- 임시 `hindsight-test.deopjib.site` 제거

### Step 5 — VPS 은퇴

- VPS 쪽 `docker compose down -v` (데이터 포함 삭제)
- VPS 호스팅 종료 (혹은 다른 용도 전환)
- `sync/services/docker-compose.yml`에서 arcane/caddy 블록 제거 후 커밋 (VPS 저장소 측)

## 데이터 마이그레이션 세부

- **버전 고정**: homelab TimescaleDB 이미지 태그를 VPS와 **정확히 동일** (`timescale/timescaledb-ha:pg18`)로 유지 — minor version drift 시 확장 호환성 깨질 수 있음
- **확장 목록**: `pgvector`, `pg_textsearch` 모두 이미지 내 번들. 별도 `CREATE EXTENSION` 불필요
- **백업 보존**: VPS 은퇴 전 `hsdb-*.tar.gz`를 별도 외장 디스크에 한 부 더 보관 (최소 1주일)
- **Smoke test 쿼리**:
  - `SELECT count(*) FROM memories;`
  - `SELECT count(*) FROM embeddings;`
  - hindsight `/v1/recall`로 임의 질의 → 기대 결과 반환 확인

## 위험 & 롤백

| 위험 | 확률 | 대응 |
|---|---|---|
| homelab 전원/네트워크 장애 | 중 | 집에 있을 때만 복구 가능. 장기 외출 시 VPS 은퇴 미루기 |
| TEI 모델 다운로드 실패/느림 | 중 | 사전에 `docker pull` + 모델 캐시 워밍 (`hf_cache` volume 사전 채움) |
| **TEI에 `bge-reranker-v2-m3`가 공식 Supported Models 목록에 없음** | 중 | 아키텍처(XLM-RoBERTa cross-encoder)가 호환되어 실질 작동 보고 다수. TEI 업그레이드 시 깨질 경우 Alibaba-NLP/gte-multilingual-reranker-base(공식 명시)로 fallback |
| **CPU 추론 레이턴시** (reranker 누적) | 저 | top-20 rerank ≈ 0.4-1.2초. 후보 수(`RERANKER_MAX_CANDIDATES`) 150→50 조정으로 완화 가능 |
| CF Tunnel 연결 불안정 | 저 | `services.cloudflared` systemd 재시작 정책, comin watchdog |
| volume tar 복사 중 스키마 버전 drift | 저 | 이미지 태그 pin 확인 후 진행 |
| `:0.5.1-slim` 태그 registry에 없음 | 저 | 사전에 `docker manifest inspect` 확인. 없으면 `:latest-slim` 사용 또는 v0.5.0 유지 |

**롤백 경로**: VPS 은퇴 전까지 Step 4 DNS만 되돌리면 즉시 VPS로 복귀. `hsdb-*.tar.gz` 백업 7일 보관으로 데이터 복원 가능.

## 열린 질문 (후속 확인 필요)

1. **homelab RAM 실제 인식값** — dmidecode 재빌드 후 BIOS 인식/iGPU UMA 예약량 확인. 현재 커널 인식 ~16GB이나 실제 ~36GB 설치. BIOS UMA 설정 조정으로 회수 가능 여부 판단. concurrency 튜닝 기준에도 영향

## 해결된 질문 (참고용)

- ✓ **`hindsight:0.5.1-slim` 태그 존재** — OCI Image Index 확인, amd64/arm64 둘 다 지원. 그대로 사용
- ✓ **TEI 연동 env 변수명**:
  - Embedding: `HINDSIGHT_API_EMBEDDINGS_PROVIDER=tei`, `HINDSIGHT_API_EMBEDDINGS_TEI_URL=http://tei-embed:80` (모델은 TEI 서버측 결정)
  - Reranker: `HINDSIGHT_API_RERANKER_PROVIDER=tei`, `HINDSIGHT_API_RERANKER_TEI_URL=http://tei-rerank:80`
- ✓ **comin GitOps 첫 배포 가능** — `services.comin.enable`, `.sops.yaml` homelab creation_rule, `secrets/homelab/` 암호화 secrets 이미 준비됨. `jj git push`만으로 comin auto-apply. 새 secrets은 `sops secrets/homelab/services.yaml` 생성 후 커밋 (.sops.yaml 규칙이 자동으로 homelab age key로 암호화)

## 참조 파일

- `systems/homelab/default.nix` — homelab NixOS 시스템 설정 (수정 대상)
- `homes/homelab/default.nix` — homelab home-manager (영향 없음 예상)
- `sharedHome/development/devops/` — devops 도구 (영향 없음)
- `secrets/homelab/` — secrets 디렉토리 (신규 `services.yaml` 추가 예정)
- `.sops.yaml` — age 암호화 규칙 (homelab creation_rule 이미 준비됨)
- external: `my-backend/vps/sync/services/docker-compose.yml` — VPS 기존 구성 참조
- external: `my-backend/vps/sync/services/Caddyfile` — 기존 라우팅 참조

## Phase 2+ 로드맵

**Phase 2 (마이그레이션 성공 후 수주 내) — 범용 AI 스택 + 모니터링**

llama.cpp 중심 홈랩 AI 패턴 구축 (Ollama 미사용 — 사용자 선호: 선언형·투명성):
- **iGPU Vulkan 활성화** (`hardware.amdgpu.enable`, llama.cpp Vulkan 빌드)
- **`services.llama-cpp` 확장** — 현재 homelab에 이미 활성화된 127.0.0.1:8080 llama.cpp 서버를 확장. 모델/포트/동시성 nix 선언형 관리. llama-server의 OpenAI-호환 엔드포인트(`/v1/chat/completions`) 노출
- **LiteLLM proxy** 도입 — 로컬 llama.cpp + 외부 OpenRouter/Groq를 단일 OpenAI-호환 엔드포인트로 통합. hindsight가 LiteLLM을 바라보게 하면 추후 LLM 로컬화 전환이 config 한 줄
- **Open WebUI** (선택) — 프론트엔드 통합 필요 시. `ai.deopjib.site` CF Tunnel로 노출
- 공유 `hf_cache` volume을 TEI/llama.cpp/기타 HF 기반 서비스에 확장
- Cloudflare Access OAuth proxy 도입 (hindsight PR #922)
- concurrency 튜닝 값을 homelab 사양에 맞게 상향

**모니터링 스택 (Phase 2 동시 구축 — 경량 지향)**:
- **Beszel** (oci-container, hub + agent) — 호스트/컨테이너 리소스(CPU/RAM/디스크/네트워크/Docker stats) + 내장 알림(Discord/Pushover/webhook). SQLite 내장, 메모리 ~100MB. `beszel.deopjib.site` CF Tunnel 노출
- **Dozzle** (oci-container, 선택) — Docker 로그 웹 UI, 필요 시 추가
- 보조 TUI: `btop`, `lazydocker` (shell 빠른 확인용)
- **Prometheus + Grafana는 당분간 도입하지 않음 (영구 생략 가능)** — Beszel로 호스트/컨테이너 레벨은 충분. hindsight/TEI/llama.cpp의 `/metrics` 엔드포인트가 있긴 하지만 **앱 메트릭 시계열 분석·고급 알림이 정말 필요해지는 상황이 오기 전까지는 도입 안 함**. 필요성이 명확해지더라도 그때 상황·선호에 따라 다양한 옵션 재평가 (Beszel로 계속 / Prometheus+Grafana 교체 또는 병행 / 제3 도구 / 외부 SaaS 등) — 지금 확정하지 않음

**Phase 3 (수개월 내, 실험적) — LLM 로컬화**
- 로컬 LLM 모델 선정 (Phase 2 시점의 iGPU 890M 실측 + 한국어 품질 벤치 기반)
- reflect LLM 먼저 로컬화 시도 — LiteLLM 라우팅만 바꿔서 A/B 품질 검증
- 품질 통과 시 retain/consolidation도 로컬로 이관

**Phase 4 (장기)**
- main LLM (현 Gemma-4-31b)은 외부 API 유지 — GPU 업그레이드 또는 클러스터 확장 시 재검토
- 확장 역할: faster-whisper(STT), Piper(TTS), ComfyUI(image gen), Continue.dev(code completion)
- NPU(XDNA2) Linux 드라이버 성숙 시 embedding/reranker를 NPU로 이관 검토 (CPU 여유 확보)
