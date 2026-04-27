---
title: "feat: homelab llama-swap 기반 embedding/reranker 전환"
type: feat
status: blocked
date: 2026-04-17
---

# feat: homelab llama-swap 기반 embedding/reranker 전환

**Current state (2026-04-27):** Code exists in `systems/homelab/ai-stack.nix`, `systems/homelab/embed-prefix-proxy/`, `systems/homelab/hindsight-stack.nix`, and `systems/homelab/default.nix`. Manual `boot` activation of comin generation 48 succeeded; homelab now boots `/nix/store/ayysplqir7dqh4mirlblsb5ilabybj91-nixos-system-homelab-26.05.20260422.0726a0e` (`26.05.20260422.0726a0e`). After `/run/current-system/activate`, `hindsight-db.service`, `hindsight.service`, `cloudflared-tunnel-a19003a7-293f-4872-b8a5-1db544878f45.service`, `llama-swap.service`, and `embed-prefix-proxy.service` are active, `systemctl list-units --failed` is empty, `/run/secrets/rendered/services.env` and `/run/secrets/cloudflared-credentials` exist, and `curl http://127.0.0.1:8888/health` returns 200. Remaining Unit 6 blocker: Hindsight recall still hits llama.cpp `/v1/rerank` 400 on long candidate text. Follow-up fix: route rerank through `embed-prefix-proxy`, cap each `documents[]` string before forwarding to llama-swap, and raise qwen reranker context/batch because live `--ctx-size 2048 --parallel 8` exposes only 256 tokens per rerank sequence.

## Overview

현재 TEI 컨테이너 2개(bge-m3 embedding, bge-reranker-v2-m3 reranking)가 homelab에서 ~8GB 메모리를 점유하여 OOM/kswapd livelock의 주 원인. 이를 llama-swap + llama.cpp 기반으로 전환하여 **~1.3GB로 축소(84% 절감)**. 모델은 Harrier 0.6B Q8_0 (embedding) + Qwen3-Reranker 0.6B Q8_0 (reranking). Harrier는 `Instruct: ...\nQuery: ...` 형태의 task prefix가 필요하므로 FastAPI 프록시에서 주입. 배포 전 로컬 스모크 테스트로 Qwen3-Reranker GGUF의 알려진 score 버그(garbage `~1e-23` 출력)를 검증.

## Problem Frame

VPS→homelab 마이그레이션 Phase A에서 hindsight-stack의 TEI 2개 모델이 동시 초기화 중 OOM 발생 → 시스템 다운 (2026-04-16 `57115ca`로 일시 비활성화). 근본 원인:

- TEI는 양자화 미지원 → bge-m3 FP32 ~3.5-4.5GB, bge-reranker-v2-m3 동량
- 16GB RAM에서 TEI 2개 + Docker + 기타 서비스 = 여유 부족
- Harrier 같은 SOTA embedding 모델을 사용하고 싶지만 TEI에서는 양자화 불가

해법: GGUF Q8_0 양자화 + llama-swap으로 모델 time-multiplex.

## Requirements Trace

- R1. 현재 TEI 기반 embedding/reranking을 llama-swap + llama.cpp로 대체
- R2. Harrier embedding에 필수인 Instruct prefix 자동 주입
- R3. Hindsight와의 wire format 호환 유지 (embedding = OpenAI, rerank = Cohere 포맷)
- R4. 배포 전 로컬 스모크 테스트로 모델 동작 검증 (Qwen3-Reranker score 버그 회피)
- R5. 기존 hindsight-stack 다른 컨테이너(hindsight-db, hindsight API) 영향 최소화
- R6. NixOS 선언형 구성 유지 (services.llama-cpp 스타일)

## Scope Boundaries

- LLM 서빙(`services.llama-cpp` 기본 포트 8080)은 이 플랜 범위 밖. 기존대로 유지.
- hindsight의 LLM provider(openrouter/groq) 변경 없음.
- GPU(ROCm gfx1150) 가속은 플랜 밖. CPU 모드로 시작.
- 6개 이종 모델 아키텍처 전체가 아니라, embedding + reranking만 이번 범위.

### Deferred to Separate Tasks

- 기존 embedding 데이터 re-embed: bge-m3(1024차원) → harrier(1024차원)으로 차원은 같지만 embedding 공간이 다름. hindsight DB 초기화 또는 별도 백필 작업은 이 플랜 이후 처리.
- Beszel 등 경량 모니터링 연동: 별도 플랜.
- 나머지 4개 모델(LLM 2개 + 기타 2개) 통합: 후속 플랜.

## Context & Research

### Relevant Code and Patterns

- `systems/homelab/default.nix` — 현재 `services.llama-cpp` 설정, Docker 활성화, zramSwap, earlyoom
- `systems/homelab/hindsight-stack.nix` — 현재 4 컨테이너 oci-containers 선언 패턴
- `systems/homelab/sops.nix` — `sops.templates."services.env"` 렌더링 패턴
- `systems/homelab/cloudflared.nix` — systemd 서비스 연동 패턴
- `.specs/research/homelab-diagnosis-2026-04-16.proposals.*.md` — OOM 근본 원인 분석

### Institutional Learnings

- `docs/solutions/runtime-errors/nixos-kswapd-livelock-zero-swap-2026-04-16.md` — TEI 컨테이너 RSS 3-4GB/개, 동시 기동 시 OOM. 순차 기동 + 메모리 제한이 필수.
- TEI cpu-latest ONNX 우선 시도 → safetensors fallback 동작.
- comin은 force push에 resilient하지 않음 (메모리에 이미 기록).

### External References

- **Harrier OSS v1 0.6B** (`microsoft/harrier-oss-v1-0.6b`)
  - Query prefix 필수: `Instruct: {task}\nQuery: {text}` (literal `\n`)
  - Document는 prefix 없이 plain text
  - 1024-dim, last-token pooling, L2 normalization, 94개 언어
  - GGUF Q8_0: ~639MB (`SuperPauly/harrier-oss-v1-0.6b-gguf`)
  - 라이센스: MIT
- **Qwen3-Reranker 0.6B** (`Qwen/Qwen3-Reranker-0.6B`)
  - 표준 cross-encoder, llama.cpp `--reranking --pooling rank` 동작
  - GGUF Q8_0: ~639MB (`ggml-org/Qwen3-Reranker-0.6B-Q8_0-GGUF`)
  - 다국어 100+, Apache 2.0
  - **알려진 버그**: 일부 GGUF 변환이 `cls.output.weight` 텐서 누락 → `~1e-23` 쓰레기 score ([llama.cpp#16407](https://github.com/ggml-org/llama.cpp/issues/16407))
- **llama-swap** (`mostlygeek/llama-swap`)
  - YAML 기반 모델 라우팅, `/v1/embeddings`/`/v1/rerank` 자동 라우팅
  - TTL/matrix로 메모리 관리, zero idle memory 가능
  - NixOS 모듈 없음 → systemd 서비스로 래핑 or Docker 사용
- **llama.cpp `/v1/rerank`**: Cohere wire format과 호환 (`{"model","query","documents"}` → `{"results":[{"index","relevance_score"}]}`)
- **Hindsight provider**
  - Embedding: `openai` provider + `HINDSIGHT_API_EMBEDDINGS_OPENAI_BASE_URL`로 OpenAI 호환 endpoint 연결
  - Reranking: `cohere` provider + `HINDSIGHT_API_RERANKER_COHERE_BASE_URL`로 Cohere 호환 endpoint 연결 → llama.cpp `/v1/rerank`에 직접 호환 (adapter 불필요)

## Key Technical Decisions

- **llama-swap 배포 방식: systemd 서비스 + 바이너리** — NixOS 공식 모듈 없음. Docker보다 투명하고 선언형 CLAUDE.md 원칙에 부합. `services.llama-cpp`(LLM용)와 분리 운영.
- **embedding prefix 주입: FastAPI 프록시** — llama.cpp는 embedding prefix 미지원([llama.cpp#16787](https://github.com/ggml-org/llama.cpp/discussions/16787) 0개 댓글). Hindsight 소스 패치는 업스트림 변경 리스크. 30줄 내외 Python 프록시가 가장 단순.
- **rerank는 동일 proxy를 경유** — Cohere ↔ llama.cpp wire format은 그대로 유지하되, unbounded DB candidate text가 llama.cpp per-document limit을 넘지 않도록 `documents[]` 문자열을 1000 chars로 cap. qwen reranker는 `--ctx-size 8192 --parallel 8`로 sequence당 1024-token window를 확보.
- **양자화: Q8_0** — 0.6B 모델에서 Q8_0은 품질 손실 최소화. Q4보다 작은 용량 차이(~260MB) 대비 신뢰성 우선.
- **모델 저장 경로: `/var/lib/llama-models/`** — 시스템 전역 읽기전용. sops 비밀 아님이라 평문 OK.
- **배포 전 로컬 테스트 필수** — Qwen3-Reranker GGUF score 버그 회피. macOS workspace에서 llama.cpp로 직접 테스트 후 배포.
- **기존 TEI 컨테이너 완전 제거** — hindsight-stack.nix에서 `tei-embed`/`tei-rerank` 삭제. 순차 기동 로직도 불필요해짐.

## Open Questions

### Resolved During Planning

- **Jina Reranker v3 GGUF 사용 가능?**: 불가. Hanxiao 포크 + projector.safetensors + Python wrapper 필요. 표준 llama.cpp 미지원. Qwen3-Reranker로 대체.
- **Harrier prefix 처리 방식?**: FastAPI 프록시로 `Instruct: Given a query, retrieve relevant passages that answer the query\nQuery: {input}` 주입. 사용자 결정.
- **Hindsight rerank provider ↔ llama.cpp 호환?**: `cohere` provider + custom base_url로 직접 호환. adapter 불필요.
- **Document embedding에도 prefix?**: Harrier 문서는 prefix 없이 encoding. 프록시는 document용 endpoint와 query용 endpoint를 구분해야 함.

### Deferred to Implementation

- **Harrier prefix 정확 문구**: Microsoft 문서의 기본 `Instruct: Given a query, retrieve relevant passages that answer the query\nQuery: ` 사용. hindsight recall 품질이 낮으면 task description 튜닝.
- **llama-swap TTL 값**: 초기 600초(10분) 기본값. 실측 후 조정.
- **프록시 배포 형태**: systemd + Python venv vs Docker. 구현 시 단순한 쪽 선택 (nix `python3.withPackages`가 아마 가장 깔끔).
- **Prefix가 document에도 섞여 들어갔을 때 embedding 품질 회복 경로**: 기존 데이터 폐기 후 재인덱싱 vs 백필. 배포 후 품질 비교하며 결정.

## High-Level Technical Design

> *아래는 구현 방향을 보여주는 참고용 스케치. 실제 구현은 변경 가능.*

```
┌──────────────────────────────────────────────────────────────────┐
│ Hindsight API (hindsight-stack.nix)                             │
│   HINDSIGHT_API_EMBEDDINGS_PROVIDER=openai                      │
│   HINDSIGHT_API_EMBEDDINGS_OPENAI_BASE_URL=http://host:8091/v1  │
│   HINDSIGHT_API_RERANKER_PROVIDER=cohere                        │
│   HINDSIGHT_API_RERANKER_COHERE_BASE_URL=http://host:8090       │
└────────┬─────────────────────────────────────────┬───────────────┘
         │ POST /v1/embeddings                      │ POST /rerank
         ▼                                          │
┌─────────────────────────┐                         │
│ embed-prefix-proxy      │                         │
│ :8091 (FastAPI)         │                         │
│  - query면 Instruct+Query prefix 주입             │
│  - document면 그대로 전달                         │
│  - input 필드만 변조, 나머지 passthrough          │
└────────┬────────────────┘                         │
         │ POST /v1/embeddings                      │
         ▼                                          ▼
┌──────────────────────────────────────────────────────────────┐
│ llama-swap :8090                                            │
│   YAML에 harrier / qwen3-reranker 모델 등록                 │
│   request model name → 해당 llama-server 프로세스 자동 기동│
│   ├─ /v1/embeddings → harrier llama-server                 │
│   └─ /v1/rerank     → qwen3-reranker llama-server          │
└──────────┬──────────────────────────────┬────────────────────┘
           │                               │
           ▼                               ▼
  harrier llama-server         qwen3-reranker llama-server
  -m harrier-Q8_0.gguf         -m qwen3-reranker-Q8_0.gguf
  --embedding                  --reranking --pooling rank --embedding
  --pooling last               --ctx-size 4096
  --ctx-size 8192
  (~639MB)                     (~639MB)
```

**핵심 식별**:
- embed-prefix-proxy가 query vs document를 구분하는 방법: Hindsight가 recall 시에는 query로 보내고 retain 시에는 document로 보냄. 둘 다 `/v1/embeddings`로 오므로, 프록시 레벨에서는 **request-level 힌트가 없으면 둘 다 prefix 주입** 또는 **별도 path(`/v1/embeddings/query` vs `/v1/embeddings/document`)로 분리**가 필요. 구현 시 Hindsight 소스 확인 후 결정.
- 단순화: `input` 필드가 짧은 단일 문자열이면 query, 여러 개 또는 길이 임계치 초과면 document로 휴리스틱 적용하는 것도 옵션.

## Output Structure

```
systems/homelab/
├── default.nix              # 수정: ai-stack.nix import 추가
├── hindsight-stack.nix      # 수정: tei-* 컨테이너 제거, Hindsight env 변경
└── ai-stack.nix             # 신규: llama-swap + embed-prefix-proxy

files/workspace/homelab/
└── embed-prefix-proxy/
    ├── main.py              # 신규: FastAPI 프록시 ~30줄
    └── pyproject.toml       # 신규 (또는 requirements.txt)

docs/plans/
└── 2026-04-17-001-feat-homelab-llamaswap-embedding-reranker-plan.md
```

## Implementation Units

- [x] **Unit 1: 로컬 스모크 테스트 (macOS workspace)**

**Goal:** 배포 전 Harrier와 Qwen3-Reranker GGUF가 실제로 동작하고 score가 쓰레기값(`~1e-23`)이 아닌지 확인.

**Requirements:** R4

**Dependencies:** 없음

**Files:**
- 작성: `files/workspace/homelab/embed-prefix-proxy/` 신규 디렉토리 (이후 Unit에서 사용)
- 테스트 결과 기록: 이 플랜의 체크박스 또는 커밋 메시지

**Approach:**
- `llama.cpp` 바이너리 macOS 빌드 사용 (이미 nix로 설치됨)
- HuggingFace에서 GGUF 직접 다운로드 (nix로 관리하지 않음, 임시 테스트용)
- harrier: `llama-server -m harrier-Q8_0.gguf --embedding --pooling last --port 18080`
- qwen3-reranker: `llama-server -m qwen3-reranker-Q8_0.gguf --reranking --pooling rank --embedding --port 18081`
- curl로 각각 테스트:
  - embedding: `Instruct: ...\nQuery: hello` → 1024차원 벡터 확인
  - rerank: query + document 3개 → `relevance_score` 값이 `0.0~1.0` 범위 내 의미있는 값인지 확인 (쓰레기면 `~1e-23` 출력)
- prefix 유무에 따른 similarity 차이 비교 (prefix 있는 쿼리가 관련 document와 더 높은 유사도)

**Execution note:** 배포 전 차단 조건. Qwen3-Reranker score가 쓰레기면 Voodisss 변환본으로 대체 또는 bge-reranker-v2-m3 Q8_0 GGUF로 fallback.

**Patterns to follow:**
- llama.cpp 서버 예제 문서 참조

**Test scenarios:**
- Happy path: harrier Q8_0에 prefix 있는 query 입력 → 1024차원 float 배열 반환
- Happy path: harrier Q8_0에 plain document 입력 → 1024차원 float 배열 반환
- Happy path: qwen3-reranker Q8_0에 query + document 3개 → 의미있는 `relevance_score` 3개 반환, score가 입력 순서대로가 아닌 관련도 순서로 정렬됨
- Edge case: qwen3-reranker score가 모두 `<1e-10` → `cls.output.weight` 누락 버그 히트, Voodisss 변환본 또는 다른 reranker로 대체 결정
- Edge case: harrier에 prefix 없는 query와 prefix 있는 query의 similarity 비교 → prefix 있는 쪽이 관련 document와 유사도 더 높아야 함

**Verification:**
- 두 모델 모두 의미있는 응답 반환
- Qwen3-Reranker score 정상 범위 (`0.0~1.0`)
- Harrier prefix 적용 시 검색 품질 향상 관찰 가능

---

- [x] **Unit 2: FastAPI embedding prefix proxy 작성**

**Goal:** Hindsight의 `/v1/embeddings` 요청을 받아서 Harrier용 Instruct prefix를 주입하고 llama-swap에 전달.

**Requirements:** R2, R3

**Dependencies:** Unit 1 (prefix 정확한 포맷 확정)

**Files:**
- 작성: `files/workspace/homelab/embed-prefix-proxy/main.py`
- 작성: `files/workspace/homelab/embed-prefix-proxy/pyproject.toml` (또는 `requirements.txt`)

**Approach:**
- FastAPI + httpx 비동기 프록시
- 환경변수로 설정: `UPSTREAM_URL`, `QUERY_PREFIX`, `DEFAULT_MODE` (query|document)
- Endpoint 분리:
  - `POST /v1/embeddings` — 기본 mode는 환경변수로. query mode면 prefix 주입, document mode면 passthrough.
  - 또는 `POST /v1/embeddings/query` + `POST /v1/embeddings/document` 둘 다 제공. Hindsight가 어느 path를 호출하는지 구현 시 확인.
- `input` 필드 처리: string이든 list이든 모두 처리
- 응답은 llama-swap에서 받은 그대로 passthrough

**Execution note:** 테스트 먼저 — Unit 1의 curl 결과를 pytest 케이스로 고정.

**Patterns to follow:**
- Hindsight `openai` provider가 실제로 어떤 URL/path/body를 보내는지 Unit 1 단계에서 mitmproxy 또는 httpbin으로 캡처하여 확인

**Test scenarios:**
- Happy path: string input + query mode → `Instruct: ...\nQuery: {input}` 으로 변조되어 upstream 호출, 응답 그대로 반환
- Happy path: list input + document mode → 각 item passthrough, 응답 그대로 반환
- Edge case: 빈 input → 400 또는 upstream으로 그대로 전달 (upstream 에러 응답 패스)
- Edge case: input이 너무 긴 문자열 → prefix만 추가하고 그대로 전달 (truncation은 upstream이 처리)
- Error path: upstream 연결 실패 → 502 반환 (Hindsight가 재시도 가능하도록)
- Integration: 실제 llama-swap → harrier 경로로 end-to-end 요청 시 1024차원 벡터 반환

**Verification:**
- pytest 전 케이스 통과
- curl로 직접 프록시 호출 시 prefix 주입된 request가 upstream에 도달함을 로그로 확인

---

- [x] **Unit 3: ai-stack.nix — llama-swap + 프록시 NixOS 모듈 작성**

**Goal:** llama-swap 바이너리 + Harrier/Qwen3-Reranker 모델 파일 + embed-prefix-proxy를 systemd 서비스로 선언.

**Requirements:** R1, R6

**Dependencies:** Unit 2

**Files:**
- 작성: `systems/homelab/ai-stack.nix`

**Approach:**
- llama-swap은 nixpkgs에 없을 가능성 높음 → `buildGoModule` 또는 `fetchurl`로 릴리스 바이너리 사용
- 모델 파일은 `fetchurl` + SHA256 pinning으로 `/nix/store`에 저장 or 런타임에 `/var/lib/llama-models/`로 다운로드 (초회 1회, 이후 캐시)
  - 전자가 더 선언형이지만 nix-darwin 빌드 타임에 큰 파일(~1.3GB) 다운로드 필요
  - 후자는 실용적. `systemd.services.llama-swap-prepare`가 기동 전에 모델 있는지 확인 + 없으면 curl
- `services.llama-swap` 유사 인터페이스:
  - `enable`
  - `host`, `port` (기본 127.0.0.1:8090)
  - `models` — 모델 목록 + 경로 + flags
- llama-swap config YAML은 `pkgs.writeText`로 생성 → `/etc/llama-swap/config.yaml`
- llama-swap systemd unit:
  - `ExecStart = "${llama-swap}/bin/llama-swap --config /etc/llama-swap/config.yaml --listen 127.0.0.1:8090"`
  - `After = network.target llama-swap-prepare.service`
- embed-prefix-proxy systemd unit:
  - `python3.withPackages (ps: [ ps.fastapi ps.httpx ps.uvicorn ])`
  - `ExecStart = "${python}/bin/uvicorn main:app --host 127.0.0.1 --port 8091"`
  - WorkingDirectory에 `files/workspace/homelab/embed-prefix-proxy/` 복사
  - 환경변수: `UPSTREAM_URL=http://127.0.0.1:8090/v1/embeddings`, `QUERY_PREFIX="Instruct: Given a query, retrieve relevant passages that answer the query\nQuery: "`

**Execution note:** systemd unit 작성 후 `nixos-rebuild dry-build`로 평가만 먼저 확인.

**Patterns to follow:**
- `systems/homelab/cloudflared.nix` — systemd unit 작성 패턴
- `systems/homelab/default.nix`의 `services.earlyoom` 스타일 — 기존 서비스 선언 패턴

**Test scenarios:**
- Test expectation: none — 이 unit은 인프라 선언만 수행. 실제 동작 검증은 Unit 6에서 배포 후 smoke test.
- 단, `just build_hj-workspace`로 빌드 성공 + 평가 에러 없음 확인 필요

**Verification:**
- `just build_hj-workspace` 성공
- `nixos-rebuild dry-build --flake .#workspace_hj` 평가 성공 (macOS에서는 dry-build 불가할 수 있으니 eval만)
- 생성된 YAML이 올바른 llama-swap 스키마인지 `pkgs.writeText` 출력물로 확인

---

- [x] **Unit 4: hindsight-stack.nix 수정 — TEI 제거 + env 변경**

**Goal:** TEI 두 컨테이너 제거, Hindsight API의 embedding/reranker provider를 새 stack으로 전환.

**Requirements:** R1, R3, R5

**Dependencies:** Unit 3

**Files:**
- 수정: `systems/homelab/hindsight-stack.nix`

**Approach:**
- `tei-embed`, `tei-rerank` 컨테이너 선언 삭제
- 순차 기동 로직 삭제 (`docker-tei-rerank.after`)
- hindsight API 컨테이너의 env 변경:
  - `HINDSIGHT_API_EMBEDDINGS_PROVIDER=openai`
  - `HINDSIGHT_API_EMBEDDINGS_OPENAI_BASE_URL=http://host.docker.internal:8091/v1` (컨테이너 → 호스트)
  - `HINDSIGHT_API_EMBEDDINGS_OPENAI_API_KEY=dummy` (llama.cpp가 무시)
  - `HINDSIGHT_API_EMBEDDINGS_OPENAI_MODEL=harrier`
  - `HINDSIGHT_API_RERANKER_PROVIDER=cohere`
  - `HINDSIGHT_API_RERANKER_COHERE_BASE_URL=http://host.docker.internal:8090`
  - `HINDSIGHT_API_RERANKER_COHERE_API_KEY=dummy`
  - `HINDSIGHT_API_RERANKER_COHERE_MODEL=qwen3-reranker`
  - 기존 TEI 관련 env 전부 삭제
- `dependsOn`에서 `tei-embed`, `tei-rerank` 제거
- Docker 컨테이너에서 호스트 서비스 접근: `--add-host=host.docker.internal:host-gateway` 또는 호스트 IP `192.168.0.5` 직접 사용

**Execution note:** 이 unit 적용 시 기존 embedding 데이터(bge-m3로 만든 것)는 Harrier 공간과 호환 안 됨. Unit 6 smoke test 후 별도 작업으로 hindsight DB reset 필요.

**Patterns to follow:**
- 기존 `hindsight` 컨테이너 env 선언 스타일 유지
- sops 비밀(`servicesEnv`)은 건드리지 않음

**Test scenarios:**
- Test expectation: none — 인프라 선언 변경만. 동작 검증은 Unit 6.
- 빌드 평가 에러 없음 확인

**Verification:**
- `just build_hj-workspace` 성공
- hindsight-stack.nix에 `tei-` 식별자 더 이상 없음

---

- [x] **Unit 5: systems/homelab/default.nix — ai-stack 통합**

**Goal:** `ai-stack.nix`를 homelab 시스템에 import하고 기존 `services.llama-cpp` 블록과의 포트 충돌 방지.

**Requirements:** R6

**Dependencies:** Unit 3, Unit 4

**Files:**
- 수정: `systems/homelab/default.nix`

**Approach:**
- `imports` 배열에 `./ai-stack.nix` 추가
- `services.llama-cpp` 블록 검토:
  - 기존 포트 8080은 LLM 전용으로 유지 (범위 밖)
  - llama-swap은 8090, 프록시는 8091 사용
  - 충돌 없음
- firewall 변경 없음 (모두 127.0.0.1 바인딩, hindsight 컨테이너에서만 접근)

**Execution note:** none

**Patterns to follow:**
- 기존 `imports` 배열 스타일

**Test scenarios:**
- Test expectation: none — 순수 import 변경.
- 빌드 평가 에러 없음

**Verification:**
- `just build_hj-workspace` 성공

---

- [ ] **Unit 6: 배포 + smoke test (blocked pending rerank input guard deployment)**

**Goal:** homelab에 적용 후 embedding, reranking, hindsight recall이 실제로 동작하는지 확인.

**Requirements:** R1, R2, R3, R4, R5

**Dependencies:** Unit 1~5 전부

**Files:**
- 변경 없음 (검증만)

**Approach:**
- 커밋 → push → comin이 자동 적용 (또는 homelab SSH로 `darwin-rebuild switch` 수동)
- 적용 후 homelab에서 순차 검증:
  1. `systemctl status llama-swap embed-prefix-proxy` — active 확인
  2. `curl http://127.0.0.1:8091/v1/embeddings -d '{"model":"harrier","input":"hello world"}'` → 1024차원 벡터
  3. `curl http://127.0.0.1:8091/v1/rerank -d '{"model":"qwen3-reranker","query":"cat","documents":["a cat on the mat","the weather is nice"]}'` → score 의미있는 값
  4. Hindsight recall 호출 → 에러 없이 결과 반환
  5. `free -h` — 메모리 사용량 확인, 모델 로드 직후 ~1.3GB 증가 예상
  6. 5분 idle 후 다시 `free -h` — llama-swap TTL 동작 확인
- 실패 시 롤백: `57115ca` 직전 커밋으로 되돌리거나 이 플랜의 커밋만 revert

**Execution note:** homelab이 다시 OOM으로 다운될 가능성 — Unit 1에서 검증한 수치를 토대로 예상치 대비 실측 차이 크면 즉시 rollback.

**Patterns to follow:**
- `.specs/research/homelab-diagnosis-2026-04-16.proposals.*.md`의 복구 절차

**Test scenarios:**
- Happy path: smoke test 1-4 전부 통과
- Happy path: hindsight retain + recall 왕복 → 저장한 내용이 retrieval됨
- Edge case: llama-swap idle 후 첫 요청 → cold start 대기 감수 (TTL로 언로드된 상태)
- Error path: 프록시가 llama-swap 연결 실패 → Hindsight 로그에 502/timeout 확인되어야 함 (무응답이면 버그)
- Integration: Hindsight API recall이 embedding + rerank 파이프라인 전체를 한 요청에 사용 → 정상 응답

**Verification:**
- homelab SSH 유지
- 메모리 사용량 예상 범위 (~1.3GB 증가)
- Hindsight recall 품질 육안 확인 (bge-m3 대비 heuristic 비교)

## System-Wide Impact

- **Interaction graph:** Hindsight API → embed-prefix-proxy → llama-swap → llama-server(harrier | qwen3-reranker).
- **Error propagation:** upstream 실패 시 2xx 가 아닌 응답을 Hindsight가 받아야 함. 프록시는 httpx 예외를 HTTP 502로 변환.
- **State lifecycle risks:** 모델 파일 로컬 캐시(`/var/lib/llama-models/`)가 손상되면 llama-swap 기동 실패 → prepare 서비스가 재다운로드.
- **API surface parity:** Hindsight env 외부에서 보이는 인터페이스는 유지. hindsight-stack 다른 컨테이너 변경 없음.
- **Integration coverage:** Hindsight의 retain/recall 전체 플로우를 한 번은 실제로 돌려봐야 함 (mock으로는 불충분).
- **Unchanged invariants:** `services.llama-cpp`(LLM 포트 8080), hindsight-db, cloudflared, sops 템플릿 변경 없음.

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| Qwen3-Reranker GGUF score 버그로 쓰레기값 출력 | Unit 1에서 사전 테스트. 히트 시 Voodisss 변환본 or bge-reranker-v2-m3 Q8_0로 fallback |
| Harrier prefix 포맷 잘못되어 "완전 작동 안 함" 재발 | Unit 1에서 Microsoft 공식 문서 포맷대로 검증. prefix 유무로 similarity 비교 |
| llama-swap nixpkgs 부재로 패키징 복잡 | `fetchurl` + 릴리스 바이너리 사용. 최소한의 derivation |
| 모델 다운로드 실패로 시스템 기동 실패 | `systemd.services.llama-swap-prepare`를 `Before`로 두고, 실패 시 llama-swap 기동 안 함 (다른 서비스 영향 X) |
| 기존 bge-m3 embedding 데이터와 Harrier 공간 불일치 → recall 품질 저하 | Deferred to Separate Tasks로 명시. 이 플랜 이후 별도 re-embed 작업 |
| Docker 컨테이너에서 호스트 서비스 접근 실패 | `host.docker.internal` 대신 고정 IP `192.168.0.5` 사용 (default.nix에 선언됨) |
| llama-swap이 두 모델을 동시에 메모리 올리면 여전히 OOM 가능 | YAML의 `matrix` 옵션으로 동시 로드 금지. embedding과 rerank 각각 필요 시점에만 로드 |

## Documentation / Operational Notes

- 이 플랜 완료 후 `docs/solutions/` 에 경량 기록 (`ce-light-compound`):
  - TEI의 양자화 미지원 한계
  - Harrier prefix 필수 요구사항 + llama.cpp 미지원 → 프록시 해법
  - Qwen3-Reranker GGUF 버그 회피 절차
  - llama-swap + Cohere wire format 직접 호환 발견
- `systems/homelab/ai-stack.nix`는 후속 플랜(LLM, TTS, STT, Vision 등)의 확장 지점. 구조 설계 시 확장 고려.
- 새 env 변수(`HINDSIGHT_API_EMBEDDINGS_OPENAI_*`, `HINDSIGHT_API_RERANKER_COHERE_*`) 는 sops 비밀 아님. 평문 env.
- memory 업데이트: `project_homelab_migration_status.md`에 Phase A 완결 상태 반영.

## Sources & References

- [Microsoft Harrier OSS v1](https://huggingface.co/microsoft/harrier-oss-v1-0.6b)
- [SuperPauly Harrier GGUF](https://huggingface.co/SuperPauly/harrier-oss-v1-0.6b-gguf)
- [Qwen3-Reranker 0.6B](https://huggingface.co/Qwen/Qwen3-Reranker-0.6B)
- [ggml-org Qwen3-Reranker Q8_0 GGUF](https://huggingface.co/ggml-org/Qwen3-Reranker-0.6B-Q8_0-GGUF)
- [llama.cpp rerank score bug #16407](https://github.com/ggml-org/llama.cpp/issues/16407)
- [llama.cpp embedding prefix discussion #16787](https://github.com/ggml-org/llama.cpp/discussions/16787)
- [Voodisss Qwen3-Reranker working GGUF (fallback)](https://huggingface.co/Voodisss/Qwen3-Reranker-0.6B-GGUF-llama_cpp)
- [llama-swap](https://github.com/mostlygeek/llama-swap)
- [Hindsight docs (local skill)](~/.claude/skills/hindsight-docs/)
- 관련 메모리: `feedback_ai_stack_llamacpp_over_ollama.md`, `project_homelab_migration_status.md`, `docs/solutions/runtime-errors/nixos-kswapd-livelock-zero-swap-2026-04-16.md`
- 관련 코드: `systems/homelab/default.nix`, `systems/homelab/hindsight-stack.nix`, `systems/homelab/cloudflared.nix`
