---
title: qwen3-reranker CPU 타임아웃 — NixOS에서 llama.cpp Vulkan iGPU 가속 활성화 (AMD Radeon 890M / RDNA 3.5)
date: 2026-04-19
category: performance-issues
module: homelab
problem_type: performance_issue
component: tooling
symptoms:
  - "Hindsight recall API가 500 반환 — 내부적으로 httpx.ReadTimeout after 60s"
  - "llama-swap proxy: POST /v1/rerank HTTP/1.1 502 -1 1m0s, context canceled"
  - "`llama-server --list-devices`에 BLAS만, Vulkan0 device 없음"
  - "qwen3-reranker 150 docs 리랭크 ~70s (threads=4) / ~58s (threads=12)"
root_cause: incomplete_setup
resolution_type: config_change
severity: medium
related_components:
  - llama-cpp
  - llama-swap
  - hindsight
  - amdgpu
  - mesa
  - systemd
tags:
  - nixos
  - llama-cpp
  - vulkan
  - radv
  - amdgpu
  - hindsight
  - reranker
  - dynamic-user
---

# qwen3-reranker CPU 타임아웃 — NixOS에서 llama.cpp Vulkan iGPU 가속 활성화 (AMD Radeon 890M / RDNA 3.5)

## Problem

NixOS homelab의 Hindsight API recall path가 qwen3-reranker(`/v1/rerank`) 호출에서 일관되게 httpx 60초 타임아웃을 초과. Hindsight Cohere 클라이언트의 timeout이 소스에 60.0s로 하드코딩되어 env 조정 불가. 원인은 `pkgs.llama-cpp` 기본 빌드가 CPU-only BLAS 백엔드만 포함하여, AMD Radeon 890M iGPU (Ryzen AI 9 HX 370, RDNA 3.5 "Strix Point")가 idle인 채로 inference가 CPU에서 수행되던 구조.

## Measured Impact

| 지표 | Before (CPU BLAS) | After (Vulkan iGPU) |
|---|---|---|
| Total recall E2E | ~50s (cold) / 49.8s (warm) @ candidates=60 | 12.9s (cold) / 12.7s (warm) @ candidates=150 |
| Rerank only (llama-swap 로그 실측) | ~42s @ 60 docs | 9.3s @ 60 docs |
| `MAX_CANDIDATES` | 타임아웃 회피 위해 150→60 축소 | 150 (원복, 품질 회복) |
| llama-cpp 백엔드 | `BLAS` (CPU only) | `Vulkan0: AMD Radeon 890M Graphics (RADV STRIX1) (24175 MiB)` |

## Symptoms

- `httpx.ReadTimeout` 정확히 1m 0.00s에 발생
- llama-swap 프록시 로그: `POST /v1/rerank HTTP/1.1 502 -1 "python-httpx/0.28.1" 1m0s` + `context canceled`
- Hindsight API는 caller에게 HTTP 500 `Internal server error` 반환
- `llama-server --list-devices`가 `BLAS: BLAS (0 MiB, 0 MiB free)`만 표시 — Vulkan0 device 없음
- 60 candidates 리랭크 ~42s (실측), 150 candidates 외삽 ~70s (위 타임아웃 확실 초과)

## What Didn't Work

1. **`--threads 4 → 12` (CPU 스레드 증설)**
   llama-cpp이 12 threads로 돌아도 150 docs 리랭크는 70s → 58s, ~15% 개선에 그침. RDNA 3.5 APU의 메모리 대역폭이 bottleneck — CPU 코어 수보다 memory bandwidth 제약이 지배적. 60s 타임아웃 경계를 아슬아슬하게 넘나들어 jitter 한 번이면 실패.

2. **`HINDSIGHT_API_RERANKER_MAX_CANDIDATES 150 → 80 → 60` (candidate 축소)**
   타임아웃은 회피하나 검색 품질 저하. 앱 레벨에서 제약을 거는 bandage로, 근본 원인 미해결. 사용자 feedback 메모리(`feedback_no_excessive_limits`)의 "앱에 과도한 제한 걸지 말고 시스템 레벨로 방어" 원칙에도 역행.

3. **(별개 선행 문제) Cohere base_url에 `/v1/rerank` 경로 생략 — 404**
   Hindsight 0.5.2의 `CohereCrossEncoder`는 `rerank_url = base_url`로 그대로 사용, Azure AI Foundry 호환 분기와 동일하게 path append 안 함. `HINDSIGHT_API_RERANKER_COHERE_BASE_URL`에 full endpoint URL 명시 필요. 0.5.0 → 0.5.2 URL assembly 로직 변경이 무증상 upgrade의 숨은 breaking change였음. (session history: Phase 1 plan에선 jina-reranker-v3-GGUF 평가 시 llama.cpp `/rerank` endpoint를 "unofficial, 통합 비용 과도"로 판정했었으나, 0.5.2 시점엔 native reranker endpoint가 공식 경로로 성숙)

## Solution

네 개의 변경이 맞물림. 모두 `systems/homelab/ai-stack.nix`와 `systems/homelab/hindsight-stack.nix`에.

### 1. `llama-cpp`를 Vulkan 빌드로 override

```nix
# systems/homelab/ai-stack.nix
let
  llamaCppVulkan = pkgs.llama-cpp.override { vulkanSupport = true; };
  llamaServer = "${llamaCppVulkan}/bin/llama-server";
in
{ ... }
```

nixpkgs `llama-cpp` 기본값은 `vulkanSupport ? false`. override로 `GGML_VULKAN=1` cmake flag 활성화 → Mesa RADV 백엔드 포함 바이너리 생성. 바이너리 캐시 미스 → homelab에서 from-scratch 빌드 (~5-10분).

### 2. Userspace Vulkan 활성화 + kernel params

```nix
# systems/homelab/ai-stack.nix
{
  hardware.graphics.enable = true;
  boot.kernelParams = [
    "amdgpu.gttsize=-1"
    "ttm.pages_limit=-1"
  ];
  environment.systemPackages = [ pkgs.vulkan-tools ];
}
```

`hardware.graphics.enable = true` → Mesa (`radv` ICD) + `vulkan-loader` 포함. `amdvlk`는 **추가하지 말 것** — EOL + radv와 ICD 충돌. kernel params는 amdgpu가 GTT를 통해 시스템 RAM 전체를 iGPU에 매핑하도록 제약 해제 (큰 모델 대비). **reboot 전까진 적용 안 됨** — 0.6B Q8(~650 MiB)은 기본 GTT 여유분에 fit하므로 리부팅 없이도 즉시 동작.

### 3. systemd DynamicUser에 GPU 접근권

```nix
# systems/homelab/ai-stack.nix
systemd.services.llama-swap.serviceConfig = {
  DynamicUser = true;
  SupplementaryGroups = [ "render" "video" ];  # 추가
  ProtectSystem = "strict";
  # ...
};
```

`DynamicUser = true`는 매 시작마다 새 임시 UID를 할당. 그 UID는 기본적으로 어떤 그룹에도 속하지 않으므로 `/dev/dri/renderD128`(render 그룹 소유)에 **접근 불가**. 누락 시 Vulkan init이 silent fail → CPU fallback. session history 조사 결과 이 패턴은 homelab 선행 세션에서 논의된 적 없는 신규 발견.

### 4. qwen3-reranker 런타임 flag 교체

```yaml
# before (llamaSwapConfig in ai-stack.nix)
qwen3-reranker:
  cmd: |
    ${llamaServer}
    --model ${qwen3RerankerModel}
    --port ${PORT} --host 127.0.0.1
    --reranking --ctx-size 8192 --threads 12

# after
qwen3-reranker:
  cmd: |
    ${llamaServer}
    --model ${qwen3RerankerModel}
    --port ${PORT} --host 127.0.0.1
    --reranking
    --n-gpu-layers 99
    --flash-attn on
    --ctx-size 2048
    --batch-size 512
    --ubatch-size 512
    --parallel 8
    --no-mmap
    --threads 4
```

- `-ngl 99`: 전체 레이어 GPU 오프로드
- `--flash-attn on`: RDNA 3.5에서 안정적 동작 보고됨. 크래시 시 off 폴백 (llama.cpp #19471에서 일부 모델 조합 assert 사례)
- `--ctx-size 2048`: reranker는 긴 컨텍스트 불필요 — 8192는 KV 캐시 낭비
- `--batch-size 512 --ubatch-size 512`: llama.cpp 기본값과 동일. 명시 이유는 ~200-500 tokens/pair 프리필 batch를 한 번에 처리함을 보장하기 위함. 단일 rerank 요청에서 `/v1/rerank` 핸들러가 pairs를 내부 prefill batch로 묶으므로 `--ubatch-size`가 실제 throughput 결정 knob
- `--parallel 8`: 8개 KV 캐시 슬롯 할당. 단일 요청(60 docs)에서는 llama.cpp 내부 batching이 주 역할이라 ubatch가 더 중요하지만, 여러 recall 동시 요청 시 슬롯 확보 효과
- `--no-mmap`: UMA에서 mmap은 성능 중립(페이지 캐시 재사용 가치 제한적, 커널 재시작 시 무효). 이 환경에선 제거해도 무방 — 관행적으로 유지
- `--threads 4`: full GPU offload 시 CPU는 orchestration만 담당. 12 threads 오버서브스크라이브는 오히려 불필요

### 5. candidates 원복

```nix
# systems/homelab/hindsight-stack.nix
HINDSIGHT_API_RERANKER_MAX_CANDIDATES = "150";  # CPU 때 60으로 축소했던 것 원복
```

Vulkan 헤드룸 확보로 실측 12.7s total recall (candidates=150 + flash-attn on). 60s 타임아웃 여유 충분. 검색 품질 원복.

> **후속 조정 (2026-04-21)**: 150은 Hindsight API `/v1/retain` 60s 예산엔 적합하나, Claude Code `UserPromptSubmit` 훅 timeout(10s, recall.py 하드코딩)엔 과함. 실제 배포는 단계적으로 **80 → 60**으로 축소. 자세한 내용: [`hindsight-recall-hook-silent-timeout-2026-04-21.md`](./hindsight-recall-hook-silent-timeout-2026-04-21.md). 이 문서의 150은 Vulkan 가속 직후의 품질-최대 설정을 기록한 역사적 스냅샷.
>
> **embedding 경로도 Vulkan 오프로드 확장 (2026-04-21)**: 이 문서는 qwen3-reranker만 다루었으나, harrier embedding은 GPU flag 없이 CPU-only로 남아 있었음 (5-6s per request). `-ngl 99 --no-mmap --ctx 4096 --batch 512 --ubatch 512` 추가로 warm path 15-175ms 달성. 동시에 **llama-swap `groups.retrieval {swap:false, persistent:true}`** 설정으로 두 모델 동시 상주 — 모델 스왑 thrash 제거가 실질적 승부처. 자세한 내용은 위 링크의 "Real Root Cause" 섹션.

## Why This Works

- **Radeon 890M은 RDNA 3.5, 12 CU, UMA 공유** — 시스템 RAM을 GTT(Graphics Translation Table)로 iGPU 메모리 공간에 매핑. PCIe 전송 비용 없음. 0.6B Q8 모델(650 MiB)은 22 GiB GTT 가용량에 trivially fit.
- **Mesa RADV가 Strix Point를 1st-class 지원** — `STRIX1` 코드네임 직접 인식. AMDVLK는 Valve가 2025년 LDS/CU-mode 패치로 RADV에 prompt processing +13% 우위 확인 후 사실상 deprecated. ROCm은 gfx1150 공식 명단에 있으나 APU에서 `hipMalloc`이 GTT를 못 잡고 dedicated VRAM(BIOS 예약분, 기본 512 MiB)만 써서 Vulkan 대비 ~60% 느림.
- **DynamicUser + SupplementaryGroups 공식** — systemd `DynamicUser=true`는 임시 UID → 기본 그룹 미할당. `/dev/dri/renderD128`은 `render:video` 그룹 소유, 다른 사용자는 접근 거부. `SupplementaryGroups`로 명시 추가해야 GPU node 열림.
- **작은 모델 dispatch latency 함정** — LLM inference는 per-token GPU dispatch overhead 존재. decode-bound 워크로드(짧은 토큰 생성 반복)에서 모델이 작을수록 compute/dispatch 비율이 악화 → CPU가 이길 수 있음. 다만 reranker는 prefill-dominant(한 번의 forward pass로 쌍당 스코어)라 이 함정에 덜 민감 — 본 fix에서 iGPU가 CPU 대비 명확한 우위.
- **Hindsight 클라이언트 타임아웃 hardcoded** — `cross_encoder.py:613-638`에서 Cohere 경로 `timeout: float = 60.0`으로 고정, env 노출 없음. 근본 해결은 inference를 그 안에 완결시키는 것뿐. candidates 감축은 품질 희생 bandage.

## Prevention

1. **llama.cpp 백엔드 확인 습관**: 빌드/rebuild 후 `llama-server --list-devices` 먼저 실행. `BLAS`만 나오면 CPU-only. `Vulkan0: AMD Radeon ...` 또는 `CUDA0` / `ROCm0` 중 하나는 반드시 있어야 실제 GPU 가속.

2. **NixOS `DynamicUser=true` 서비스가 GPU/ML 워크로드면 기본 보일러플레이트에 `SupplementaryGroups`**:
   ```nix
   systemd.services.<ml-service>.serviceConfig = {
     DynamicUser = true;
     SupplementaryGroups = [ "render" "video" ];  # GPU 접근 시 필수
   };
   ```
   오디오면 `audio`, USB HID면 `input` 추가. 누락 시 권한 거부가 **silent fail** 형태로 나타나 디버깅이 어렵다 (Vulkan init 실패 → CPU fallback → "왜 GPU 안 쓰지?" 미궁).

3. **Hindsight 0.5.2+ Cohere/OpenAI provider base_url은 full endpoint URL**:
   ```nix
   HINDSIGHT_API_RERANKER_COHERE_BASE_URL = "http://127.0.0.1:8090/v1/rerank";  # path 포함
   HINDSIGHT_API_EMBEDDINGS_OPENAI_BASE_URL = "http://127.0.0.1:8091/v1";  # /v1까지
   ```
   Cohere 클라이언트는 `rerank_url = base_url` (Azure AI Foundry 호환 분기 재사용). 0.5.0 → 0.5.2 minor version upgrade인데 client URL assembly 변경된 **숨은 breaking change**.

4. **Decode-bound 작은 모델 + GPU = 반드시 batch 처리**: 짧은 텍스트 생성을 반복하는 워크로드에서 0.6B-1B 파라미터 이하 모델은 per-request dispatch latency가 지배. HTTP 요청을 loop로 여러 번 보내는 대신 server-side batch (한 요청에 N inputs) 사용. Reranker는 prefill-dominant라 덜 민감하나, 원칙은 유효. (llama.cpp [#17026](https://github.com/ggml-org/llama.cpp/issues/17026))

5. **KV cache quantization 여지**: reranker는 generation 없이 prefill+score → `--cache-type-k q8_0 --cache-type-v q8_0`로 KV 메모리 절반, 품질 저하 없음. 현재 fix에선 미적용 (불필요), 더 큰 모델/컨텍스트 사용 시 고려.

## Related Issues

- Plan 및 컨텍스트: `docs/plans/2026-04-17-002-feat-hindsight-data-migration-cutover-plan.md` (Unit 5 smoke test에서 본 문제 노출)
- **Host network 전환 선행 fix**: [`docs/solutions/integration-issues/docker-host-access-host-network-2026-04-17.md`](../integration-issues/docker-host-access-host-network-2026-04-17.md) — Hindsight 컨테이너가 host network로 `127.0.0.1:8090`(llama-swap) 접근. 본 fix는 그 8090 endpoint의 backend를 CPU → Vulkan iGPU로 가속한 직접 downstream.
- **Hook timeout 후속 조정**: [`./hindsight-recall-hook-silent-timeout-2026-04-21.md`](./hindsight-recall-hook-silent-timeout-2026-04-21.md) — 본 fix 이후 Vulkan 기반 150 candidates도 Claude Code 훅 12s 예산엔 초과. MAX_CANDIDATES 80으로 재조정한 기록. 두 문서는 시간순 연속체로 같이 읽을 것.
- **kswapd livelock (별개 문제)**: [`docs/solutions/runtime-errors/nixos-kswapd-livelock-zero-swap-2026-04-16.md`](../runtime-errors/nixos-kswapd-livelock-zero-swap-2026-04-16.md) — TEI 동시 기동 시 zero-swap + UMA reservation 조합으로 RAM 고갈. 본 fix로 rerank 워크로드가 Docker에서 호스트 systemd로 이동했으므로 Docker startup concurrency 계산에서 rerank 슬롯은 제외 가능 (session history).
- Phase 1 brainstorm에서 이미 "TEI는 Vulkan 백엔드 없음 (llama.cpp만)"으로 Vulkan 경로가 **식별되었으나 Phase 1엔 과한 통합 비용으로 연기**되었던 "bridge not taken". 본 fix가 그 연기된 통합을 완결. (session history)

## Sources

- [llama.cpp Discussion #10879 — Vulkan performance reports](https://github.com/ggml-org/llama.cpp/discussions/10879)
- [llama.cpp Issue #17026 — offload threshold for small models](https://github.com/ggml-org/llama.cpp/issues/17026)
- [llama.cpp Issue #19471 — Vulkan flash-attn assert](https://github.com/ggml-org/llama.cpp/issues/19471)
- [lemonade-sdk/llamacpp-rocm #57 — APU ROCm vs Vulkan](https://github.com/lemonade-sdk/llamacpp-rocm/issues/57)
- [Hardware Corner — RADV +13% prompt processing patch](https://www.hardware-corner.net/llama-cpp-amd-radv-vulkan-driver-update/)
- [NixOS Wiki — AMD GPU](https://wiki.nixos.org/wiki/AMD_GPU)
- [LocalScore — Radeon 890M llama.cpp bench](https://www.localscore.ai/accelerator/721)
