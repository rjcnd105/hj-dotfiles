---
title: hindsight recall 훅 silent timeout — Claude Code memory 주입 실패 (해결, llama-swap 모델 스왑이 진짜 원인)
date: 2026-04-21
status: solved
last_verified: 2026-04-21
category: performance-issues
module: hindsight-memory-plugin
problem_type: performance_issue
component: tooling
symptoms:
  - "Claude Code 대화에 hindsight recall 결과가 한 번도 주입되지 않음"
  - "사용자에게 에러 메시지나 경고 없음 — silently 작동 안 함"
  - "수동 실행: `[Hindsight] Recall failed: The read operation timed out`"
  - "homelab hindsight API (https://hindsight.deopjib.site)는 reachable, 단지 응답이 ≥10s 소요"
root_cause: config_error
resolution_type: config_change
severity: medium
tags: [hindsight, claude-code, memory-injection, hook-timeout, reranker, embedding, llama-swap, model-swap-thrash, latency]
---

# hindsight recall 훅 silent timeout — Claude Code memory 주입 실패

## Problem

hindsight-memory 플러그인의 `UserPromptSubmit` 훅(`recall.py`)이 매 turn마다 등록되어 있지만 **12초 timeout 안에 응답을 못 받아** 빈 `additionalContext`를 반환한다. 결과적으로 대화에 memory 주입이 전혀 이루어지지 않고, 사용자/에이전트 둘 다 인지하지 못한 채 여러 turn이 지나감.

## Symptoms

- Claude Code 세션 내내 "Supplementary notes from auto memory" 같은 hindsight 주입 블록이 system-reminder에 단 한 번도 나타나지 않음
- 에이전트가 hindsight 기반 질문("이전에 결정한 ~는?")에 답할 때 recall 결과 참조 없이 최근 대화만으로 답변
- 수동 테스트:
  ```
  [Hindsight] Using external API: https://hindsight.deopjib.site
  [Hindsight] Recalling from bank '::nix-dots', query length: 14
  [Hindsight] Recall failed: The read operation timed out
  ```
- 플러그인 hooks.json에 등록된 timeout: 12초 (`${CLAUDE_PLUGIN_ROOT}/scripts/recall.py`)

## What Didn't Work

- **API URL/토큰 점검**: `HINDSIGHT_API_URL`, `HINDSIGHT_API_KEY` 모두 올바름. 네트워크도 reachable. 문제는 연결성이 아닌 latency.
- **플러그인 재활성화**: `enabledPlugins.hindsight-memory@hindsight: true` 유지됐고, `session_start.py`는 정상 동작. 훅 자체는 실행 중.
- **bank ID 확인**: `HINDSIGHT_DYNAMIC_BANK_ID=true` 모드라 `::nix-dots`로 자동 생성. 값 자체는 의도된 동작.

## Solution

> **1차 Solution(§1-3)은 증상 완화만**. 진짜 근본 원인은 llama-swap 모델 스왑 정책이었음 — 아래 "Real Root Cause" 섹션이 최종 해결.

### 1. reranker candidate 축소 (`systems/homelab/hindsight-stack.nix:91`)

```diff
-HINDSIGHT_API_RERANKER_MAX_CANDIDATES = "150"
+HINDSIGHT_API_RERANKER_MAX_CANDIDATES = "80"
```

150 candidates → 80 candidates로 축소. 선형 외삽 기준 rerank 시간 ~23s → ~12s. 훅 timeout 12s와 overlap하지만 다른 단계(임베딩/DB query/네트워크)가 압축되면 안전권 진입**한다고 가정했으나 실측에서 부정확**.

### 2. mission 영문화 (`files/workspace/.hindsight/claude-code.json`)

```diff
-"retainMission": "사용자의 의사결정과 그 이유, 선호도, 프로젝트 맥락, 반복적 문제의 해결책을 추출한다. 도구 출력, 파일 탐색, 중간 디버깅 과정, 모드 전환 같은 일시적 작업은 무시한다.",
-"bankMission": "사용자의 작업 맥락과 의사결정을 기억하는 시스템. '무엇을 했는가'가 아닌 '왜 그렇게 했는가'를 기억한다."
+"retainMission": "Extract user's decisions and rationale, preferences, project context, and solutions to recurring problems. Ignore ephemeral work: tool output, file exploration, intermediate debugging, mode switching.",
+"bankMission": "System remembering user's work context and decisions. Capture the 'why', not the 'what'."
```

한글 mission 약 240 토큰 → 영문 약 60 토큰 (4배 절약). retain/recall 쿼리 contextualize 단계에서 mission을 매번 프롬프트에 넣기 때문에 토큰 ↓ = latency ↓.

### 3. 배포

`services.comin` (60s poll) → 자동 nixos-rebuild switch → `docker-hindsight.service` 재시작. 수동 개입 불요.

## Why This Works

recall 훅의 12s 예산 안에 들어가야 하는 단계:

```
(a) python cold start + lib import      ~0.5s
(b) API 요청 직렬화 + 전송              ~0.2s
(c) 서버측 쿼리 임베딩 (harrier 0.6B)    ~1~2s
(d) 서버측 vector search + 후보 pull    ~0.5s
(e) 서버측 reranker (qwen3-reranker)    ★ 여기가 변수 ★
(f) 응답 직렬화 + 네트워크 복귀          ~0.2s
(g) Claude Code hook 파이프라인         ~0.2s
```

(e)가 candidate 수 × 문장 길이 × reranker 추론 비용으로 선형 증가. 150 candidates @ Vulkan iGPU → ~23s → 12s 밖. 80 candidates → ~12s → 경계선 통과.

mission 영문화는 (c) 단계에서 retain 시 mission 토큰 감소 → 간접적으로 전체 latency 개선 (약 5~10% margin).

근본 원인은 **reranker 처리량 초과**. 12s 예산에 23s 작업을 넣은 config 실수. `HINDSIGHT_API_LAZY_RERANKER=true`가 있지만 훅 경로에서는 lazy 효과 제한적.

## Post-fix verification (2026-04-21, same day)

Apr 21 Solution 적용 이후 실측 — **fix 미충분**.

### 실질 timeout ceiling은 10s

Apr 21 Solution 작성 시점엔 "훅 timeout 12s"를 상한으로 계산했으나, 실제 bottleneck은 `recall.py` 내부 HTTP timeout:

```python
# ~/.claude/plugins/cache/hindsight/hindsight-memory/0.3.1/scripts/recall.py:153
response = client.recall(..., timeout=10)   # 하드코딩
```

`claude-code.json` config에 `recallTimeout` 같은 override 키 **없음**. 플러그인 upstream PR 없이는 이 10s를 조정 불가. 훅 12s보다 HTTP 10s가 먼저 잘리므로 **실질 server budget은 ~9s**(python 런타임 + 직렬화 overhead 고려).

### 서버측 80 candidates 실측 분포

`journalctl -u llama-swap.service` 최근 5분 `POST /v1/rerank` latency:

```
7.1s  8.5s  11.9s  14.1s  15.6s  17.4s  17.5s  18.2s
7.0s  6.9s   8.7s   7.2s  10.9s  11.1s
```

- 평균 ~11s, p50 ~10s, **p90 ~17s, p99 ~18s**
- Apr 21 Solution의 "선형 외삽 ~12s" 추정은 **평균만 맞음**. tail latency가 18s까지 튐
- 9s 예산 안에 들어오는 요청은 2/14 (14%)뿐

### Embedding도 느림 (간과된 지연)

같은 구간 `POST /v1/embeddings` latency: 0.3s ~ 11.8s. Warm일 땐 300-600ms, cold/contended일 땐 5-11s.

Total recall path:
```
embedding (0.3-11s) + vector search (0.5s) + rerank (7-18s) = 8-30s
```

→ 9s HTTP budget 초과 빈번.

### 실측 수동 테스트

```
$ time bash -c 'echo {...} | python3 ~/.claude/plugins/.../recall.py'
[Hindsight] Recall failed: The read operation timed out
real 10.37s
```

→ **현재 배포(MAX_CANDIDATES=80) 상태에서 recall 여전히 실패 중**. Claude Code 대화에 memory 주입 0건.

### 진짜 fix 후보 (검증 필요)

| 접근 | 예상 효과 | 리스크 |
|------|----------|--------|
| `MAX_CANDIDATES=40` 추가 축소 | 서버 rerank ~5.5s (p99 ~9s) | 검색 품질 저하 |
| `MAX_CANDIDATES=30` | rerank ~4s (p99 ~7s) | 품질 더 저하 |
| `recall.py` local patch (timeout=11) | 훅 12s 경계까지 확보. Tail 일부 복구 | Plugin update 시 날아감 |
| hindsight upstream PR (config 옵션) | 지속 가능 | 업스트림 병합 시간 |
| UMA carve-out 축소 (BIOS 16GB → 2GB) | RAM 압박 해소, Vulkan throughput ↑ | BIOS 접근 필요 |
| llama-swap `--parallel` 축소 (8→4) | Context switch cost ↓ | 동시 요청 throughput ↓ |
| KV cache q8_0 quant (`--cache-type-k/v q8_0`) | GPU memory ↓, dispatch overhead ↓ | 미검증 |

현재 권장 즉시 조치: **MAX_CANDIDATES=40 배포 + 실측 재검증**. ← 이 추정도 틀림. 아래 섹션 참고.

## Real Root Cause (2026-04-21, same day, deeper investigation)

Post-fix verification 이후 체계적 실측으로 **진짜 원인은 upstream 파이프라인 아닌 llama-swap 모델 스왑 thrash**로 확정.

### 진단 경로

1. **80 candidates에서 p90 17s, p99 18s** (Post-fix verification)
2. **MAX_CANDIDATES 60 + BUDGET_FIXED_LOW 40 + CONNECTION_BUDGET 6** 적용 → rerank 11→9.4s, 그러나 여전히 timeout
3. **embedding도 5-6s** 판명 — 신규 병목 발견
4. harrier cmdline에 `-ngl` 플래그 부재 확인 → GPU offload 미적용 의심
5. `-ngl 99 --no-mmap --batch 512 --ctx 4096` 추가 배포 → **여전히 5-6s** (GPU flag 적용됐지만 개선 없음)
6. **결정적 실험**: direct curl `:8090`은 **21-26ms warm**. prefix-proxy `:8091`은 26-33ms. 즉 harrier 자체는 빠른데 recall 경로에서만 5s
7. llama-swap journal 분석: 매 recall 호출마다 "`<harrier> Health check passed`" + "`<qwen3-reranker> Health check passed`" 번갈아 발생 → **매 요청마다 모델 unload/reload**
8. llama-swap 기본 정책: 1모델만 resident. embedding + rerank 동시에 필요한 recall 경로에 치명적

### Final Fix

#### 1. llama-swap `groups.retrieval` — 동시 모델 load (결정타)

```nix
# systems/homelab/ai-stack.nix, llamaSwapConfig 끝에 추가
groups:
  retrieval:
    swap: false         # 그룹 내 멤버 서로 unload 안 함
    exclusive: false    # 다른 그룹 쫓아내지 않음
    persistent: true    # 다른 그룹에게 evict 당하지 않음
    members:
      - harrier
      - qwen3-reranker
```

출처: [mostlygeek/llama-swap config.example.yaml `groups` 섹션](https://github.com/mostlygeek/llama-swap/blob/40e39f7/config.example.yaml#L334-L396). 0.6B Q8 × 2 ≈ 1.3GB로 UMA 16GB에 동시 상주 가능.

#### 2. harrier GPU flags (이미 §1차 Real Fix에 포함됐으나 2번째 수준 기여)

```nix
harrier:
  cmd: |
    ${llamaServer}
    --model ${harrierModel}
    --port ''${PORT} --host 127.0.0.1
    --embeddings --pooling last
    --n-gpu-layers 99      # 신규: Vulkan iGPU 오프로드 (default 0 = CPU)
    --no-mmap              # 신규: UMA 이득
    --ctx-size 4096        # 8192 → 4096
    --batch-size 512       # 8192 → 512 (query-at-a-time 워크로드에 과도)
    --ubatch-size 512
    --threads 4
  ttl: 600
```

주의: `--flash-attn on` **미적용** — llama.cpp [#18910](https://github.com/ggml-org/llama.cpp/issues/18910) Qwen3-based embedding + flash-attn tensor OOB crash 회피.

#### 3. reranker / budget 튜닝 (보조)

```nix
HINDSIGHT_API_RERANKER_MAX_CANDIDATES = "60";     # 300 → 60
HINDSIGHT_API_RECALL_BUDGET_FIXED_LOW = "40";     # 100 → 40
HINDSIGHT_API_RECALL_CONNECTION_BUDGET = "6";     # 4 → 6
```

### Post-fix 실측 (2026-04-21)

5 runs recall.py 실측:

| Metric | Before (timeout) | After |
|--------|------------------|-------|
| Client total latency | 10.36-10.52s → timeout | **4.72-5.52s** (평균 5.04s) |
| Embedding (server) | 5.3-6.5s | **15-175ms** (100배+) |
| Rerank (server) | 9.4-18s | **3.84-4.37s** (55%↓) |
| Success rate | 0% (3/3 fail) | **100% (5/5 성공)** |
| Memory injected | 0건 | **6 memories / run** ✓ |

### 진짜 원인 요약

**llama-swap 기본 정책(1모델 resident) + Hindsight recall이 매 호출마다 embedding+rerank 순차 요청** 조합이 무한 unload/reload thrash. Cold load 5s × 2 = 10s 오버헤드.

`groups.retrieval {swap:false, persistent:true}` 로 두 모델 영구 동시 상주시키자 thrash 소멸. GPU 가속은 warm path 필수 조건이었지만 스왑 제거가 실질적 승부처.

### 세 가지 fix의 기여도

| Fix | 기여 | 증거 |
|-----|-----|------|
| llama-swap `groups` | **주역 (5-6s → 20-170ms embedding)** | direct vs recall 경로 latency 일치 |
| harrier `-ngl 99` | 보조 (warm path 속도 복원) | CPU-only 20ms 불가능, GPU로만 달성 |
| MAX_CANDIDATES 60 | 보조 (rerank 9→4s) | 선형 축소 |

`recall.py:153 timeout=10s` 하드코딩은 **upstream limit** 그대로지만, 5s 평균이면 경계 30% 여유.

## Prevention

### 즉시 대응 가능한 체크리스트

1. **플러그인 훅 timeout과 서버측 SLA 매핑 테이블 유지**

   ```
   recall.py hook timeout: 12s
   └─ server MAX_CANDIDATES budget: ≤80 (Vulkan iGPU 기준)
   ```

   후자를 올릴 때 전자도 같이 올리거나, `hooks.json` override 경로 확보.

2. **silent failure 가시화 제안**

   플러그인 기본 동작이 `exit 0 on any error`라 사용자가 인지 못 함. debug 모드(`debug: true`)로 stderr에 로그는 남지만 Claude Code UI에는 표시 안 됨. 로컬 개선안:

   ```python
   # recall.py 커스텀 패치 (upstream 제안 예정)
   if recall_failed:
       output = {"hookSpecificOutput": {"additionalContext": "⚠️ hindsight recall timeout — memory not injected"}}
   ```

3. **정기 health check**

   ```bash
   # 세션 시작 직후 수동 검증
   echo '{"session_id":"test","transcript_path":"","prompt":"health","cwd":"'"$PWD"'"}' | \
     python3 ~/.claude/plugins/cache/hindsight/hindsight-memory/0.3.1/scripts/recall.py
   ```

   "Recall succeeded" 또는 context 출력 없으면 즉시 조치.

4. **UMA carve-out 근본 해결**

   homelab(Beelink SER9, Ryzen AI 9 HX 370)의 BIOS가 16 GiB를 iGPU dedicated로 pre-allocation → OS 가용 RAM 16 GiB → reranker 작업 중 swap 유발 위험. BIOS에서 UMA Frame Buffer Size를 512 MB~2 GB로 축소하면 RAM 32 GB 풀파워 활용 + reranker latency 안정화. 이후 MAX_CANDIDATES 150 복원 여유.

## Related Issues

- `docs/solutions/performance-issues/hindsight-reranker-vulkan-acceleration-2026-04-19.md` — 같은 reranker의 Vulkan 가속 적용 맥락. 당시 50s → 12.7s. 본 문서는 그 이후 hook timeout과의 margin 이슈
- `docs/plans/2026-04-17-002-feat-hindsight-data-migration-cutover-plan.md` — hindsight API homelab 이관 맥락
- `systems/homelab/hindsight-stack.nix` — reranker env 설정 위치
- `files/workspace/.hindsight/claude-code.json` — 클라이언트 mission/budget
- 플러그인 소스: `~/.claude/plugins/cache/hindsight/hindsight-memory/0.3.1/scripts/recall.py`
