# AI inference stack — llama-swap + embed-prefix-proxy
#
# TEI 2-컨테이너(≈8GB)를 Q8_0 GGUF 2-모델(≈1.3GB)로 교체.
# llama-swap이 /v1/embeddings, /v1/rerank 경로별로 모델 스왑.
# embed-prefix-proxy가 Harrier instruct prefix 주입 후 llama-swap에 forward.
# rerank는 동일 proxy가 document 길이를 cap한 뒤 llama-swap에 forward.
#
# 토폴로지:
#   Hindsight API ─ openai provider ─→ :8091 (prefix-proxy) ─→ :8090 (llama-swap) ─→ harrier
#   Hindsight API ─ cohere provider ─→ :8091 (input guard) ─→ :8090 (llama-swap) ─→ qwen3-reranker
{
  pkgs,
  ...
}:
let
  # GGUF 모델 — SHA256 pinned, /nix/store 영구 캐시
  harrierModel = pkgs.fetchurl {
    url = "https://huggingface.co/SuperPauly/harrier-oss-v1-0.6b-gguf/resolve/main/harrier-oss-v1-0.6B-Q8_0.gguf";
    sha256 = "1c2hda54lb0xgvgacqfgl9gqnimwf588bjkh265lp0gnffyr4w7r";
  };
  qwen3RerankerModel = pkgs.fetchurl {
    url = "https://huggingface.co/ggml-org/Qwen3-Reranker-0.6B-Q8_0-GGUF/resolve/main/qwen3-reranker-0.6b-q8_0.gguf";
    sha256 = "0j4s88iyma5q5mx8y2wqmbqyz5r7qd0nc31ivjncbkgvwjf9gj92";
  };

  # Vulkan 백엔드 포함 llama.cpp — Radeon 890M (RDNA 3.5, gfx1150) iGPU 가속.
  # Mesa RADV 경로 (AMDVLK/ROCm 대비 APU에서 우수).
  llamaCppVulkan = pkgs.llama-cpp.override { vulkanSupport = true; };
  llamaServer = "${llamaCppVulkan}/bin/llama-server";

  waitForRetrievalModels = pkgs.writeShellScript "llama-swap-wait-for-retrieval-models" ''
    set -eu

    url=http://127.0.0.1:8090/running

    for attempt in $(${pkgs.coreutils}/bin/seq 1 600); do
      if running="$(${pkgs.curl}/bin/curl -fsS --max-time 2 "$url" 2>/dev/null)"; then
        if printf '%s' "$running" | ${pkgs.jq}/bin/jq -e '
          ([.running[]? | select((.model == "harrier" or .model == "qwen3-reranker") and .state == "ready")] | length) == 2
        ' >/dev/null; then
          exit 0
        fi
      fi

      ${pkgs.coreutils}/bin/sleep 1
    done

    echo "llama-swap retrieval models did not become ready in time; leaving service running" >&2
    ${pkgs.curl}/bin/curl -fsS --max-time 2 "$url" >&2 || true
    exit 0
  '';

  # llama-swap 라우팅 설정.
  # ${PORT} = llama-swap이 backend에 할당한 동적 포트.
  # hooks.on_startup.preload가 두 retrieval 모델을 startup에 올리고,
  # ttl=0은 이후 idle unload 없이 resident 상태를 유지한다.
  # groups.retrieval: 두 모델 동시 load 허용 (swap 비활성화).
  #   기본 정책은 1모델만 resident → recall 호출마다 embed/rerank 번갈아 unload+reload
  #   (cold load 5s × 2 = 10s 오버헤드).
  llamaSwapConfig = pkgs.writeText "llama-swap-config.yaml" ''
    healthCheckTimeout: 600

    models:
      harrier:
        cmd: |
          ${llamaServer}
          --model ${harrierModel}
          --port ''${PORT}
          --host 127.0.0.1
          --embeddings
          --pooling last
          --n-gpu-layers 99
          --flash-attn off
          --no-mmap
          --ctx-size 4096
          --batch-size 512
          --ubatch-size 512
          --threads 4
          --no-warmup
        proxy: http://127.0.0.1:''${PORT}
        ttl: 0

      qwen3-reranker:
        cmd: |
          ${llamaServer}
          --model ${qwen3RerankerModel}
          --port ''${PORT}
          --host 127.0.0.1
          --reranking
          --n-gpu-layers 99
          --flash-attn on
          --ctx-size 8192
          --batch-size 1024
          --ubatch-size 1024
          --parallel 8
          --no-mmap
          --threads 4
          --no-warmup
        proxy: http://127.0.0.1:''${PORT}
        ttl: 0

    groups:
      retrieval:
        swap: false
        exclusive: false
        persistent: true
        members:
          - harrier
          - qwen3-reranker

    hooks:
      on_startup:
        preload:
          - harrier
          - qwen3-reranker
  '';

  # FastAPI 런타임 — httpx + uvicorn
  proxyPython = pkgs.python313.withPackages (
    ps: with ps; [
      fastapi
      httpx
      uvicorn
    ]
  );

  # embed-prefix-proxy 소스 (main.py, test_main.py) — /nix/store로 복사
  proxySrc = ./embed-prefix-proxy;
in
{
  # ── Vulkan userspace for Radeon 890M (RDNA 3.5) ────────
  # hardware.graphics = Mesa radv + vulkan-loader 포함. amdvlk는 추가 X (radv와 ICD 충돌).
  # kernel params: amdgpu가 GTT 통해 시스템 RAM을 iGPU에 매핑 — dedicated VRAM(512MB) 제약 완화.
  # ttm.pages_limit는 ulong이라 -1 사용 시 systemd-modules-load가 amdgpu 로드 중 EINVAL로 실패.
  # 참고: kernel params 변경은 다음 부팅부터 적용. userspace는 즉시 반영.
  hardware.graphics.enable = true;
  # amdgpu stage-2 강제 로드. udev auto-match 관측 실패 (lspci -k에 "Kernel modules: amdgpu"는
  # 나오지만 "Kernel driver in use:"가 비어 device unbind 상태). initrd 대신 kernelModules로
  # 두는 이유: headless 서버라 Early KMS 불필요, initrd 실패 시 SSH 이전에 hang = 원격 브릭 위험.
  # stage-2 로드는 실패해도 multi-user.target 도달 → SSH 생존 → rollback 가능.
  # 검증: 재부팅 후 `lspci -k | grep -A2 VGA` "driver in use: amdgpu", `vulkaninfo --summary`.
  boot.kernelModules = [ "amdgpu" ];
  boot.kernelParams = [
    "amdgpu.gttsize=-1"
  ];
  environment.systemPackages = [ pkgs.vulkan-tools ];

  # ── llama-swap ─────────────────────────────────────────
  # 0.0.0.0:8090 listen — Hindsight 컨테이너가 host network에서 127.0.0.1로 접근.
  # 외부(LAN 이상) 노출은 networking.firewall 기본 거부 정책으로 차단됨.
  systemd.services.llama-swap = {
    description = "llama-swap — model router for llama.cpp";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    environment = {
      # Keep Mesa/RADV shader cache stable across DynamicUser restarts. Without this,
      # cold Vulkan startup can outlive systemd readiness checks and trigger a loop.
      XDG_CACHE_HOME = "/var/cache/llama-swap";
      MESA_SHADER_CACHE_DIR = "/var/cache/llama-swap/mesa-shader-cache";
    };

    serviceConfig = {
      ExecStart = "${pkgs.llama-swap}/bin/llama-swap --config ${llamaSwapConfig} --listen 0.0.0.0:8090";
      ExecStartPost = "${waitForRetrievalModels}";
      Restart = "always";
      RestartSec = "5s";
      TimeoutStartSec = "720s";
      CacheDirectory = "llama-swap";

      DynamicUser = true;
      # Vulkan 접근: DynamicUser의 임시 UID가 /dev/dri/renderD128에 접근하려면
      # render 그룹이 필요. video는 amdgpu device 조작용. PrivateDevices=false 유지(기본).
      SupplementaryGroups = [
        "render"
        "video"
      ];
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
  };

  # ── embed-prefix-proxy ─────────────────────────────────
  # 0.0.0.0:8091 listen — 동일하게 Hindsight 접근 허용.
  # firewall로 외부 차단.
  systemd.services.embed-prefix-proxy = {
    description = "FastAPI proxy — injects Harrier instruct prefix";
    after = [
      "network.target"
      "llama-swap.service"
    ];
    wantedBy = [ "multi-user.target" ];

    environment = {
      UPSTREAM_URL = "http://127.0.0.1:8090";
      QUERY_PREFIX = "Instruct: Given a query, retrieve relevant passages that answer the query\nQuery: ";
      RERANK_DOCUMENT_MAX_CHARS = "1000";
      TIMEOUT_SECONDS = "60";
    };

    serviceConfig = {
      ExecStart = "${proxyPython}/bin/uvicorn main:app --host 0.0.0.0 --port 8091";
      WorkingDirectory = "${proxySrc}";
      Restart = "always";
      RestartSec = "5s";

      DynamicUser = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
  };
}
