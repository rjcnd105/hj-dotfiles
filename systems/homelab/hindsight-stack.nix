# hindsight RAG 스택 — 2 Podman/Quadlet 컨테이너
#
# hindsight (API, host network) ← hindsight-db (TimescaleDB, publish 127.0.0.1:5432)
# Embedding/Reranker는 ai-stack.nix(호스트 systemd)의 llama-swap으로 위임.
# - embedding: openai provider → 127.0.0.1:8091 (prefix-proxy) → :8090 (llama-swap) → harrier
# - reranker:  cohere provider → 127.0.0.1:8090 (llama-swap) → qwen3-reranker
#
# Container bridge 경유 호스트 접근은 환경별 firewall/NAT 경로가 복잡함 →
# hindsight 컨테이너를 host network 모드로 두어 127.0.0.1로 직접 도달하게 단순화.
#
# 비밀 env는 sops.templates."services.env" 경유, 비밀 아닌 env는 environment 맵에 직접.
{
  config,
  ...
}:
let
  servicesEnv = config.sops.templates."services.env".path;
  legacyDbVolumePath = "/var/lib/docker/volumes/hindsight-db-data/_data";

  images = {
    hindsight = "ghcr.io/vectorize-io/hindsight:0.5.2-slim";
    db = "timescale/timescaledb-ha:pg18";
  };
in
{
  system.activationScripts.hindsightDbVolumePath = ''
    mkdir -p ${legacyDbVolumePath}
  '';

  environment.etc = {
    # Keep the existing Docker volume data in place while moving runtime ownership to Podman.
    # Podman uses a named volume backed by the old data path; Docker daemon is not required.
    "containers/systemd/hindsight-db-data.volume".text = ''
      [Volume]
      VolumeName=hindsight-db-data
      Device=${legacyDbVolumePath}
      Type=none
      Options=bind
    '';

    # ── TimescaleDB ──────────────────────────────────────────
    # 호스트 127.0.0.1:5432에 publish. hindsight API가 host network에서 localhost로 접근.
    "containers/systemd/hindsight-db.container".text = ''
      [Unit]
      Description=Hindsight TimescaleDB container
      Requires=hindsight-db-data-volume.service
      After=network-online.target hindsight-db-data-volume.service
      Wants=network-online.target

      [Container]
      ContainerName=hindsight-db
      Image=${images.db}
      Pull=missing
      LogDriver=journald
      EnvironmentFile=${servicesEnv}
      Environment=POSTGRES_USER=hindsight
      Environment=POSTGRES_DB=hindsight
      Volume=hindsight-db-data.volume:/home/postgres/pgdata/data
      PublishPort=127.0.0.1:5432:5432

      [Service]
      Restart=on-failure
      RestartSec=5s
      TimeoutStartSec=0
      TimeoutStopSec=120

      [Install]
      WantedBy=multi-user.target
    '';

    # ── Hindsight API ────────────────────────────────────────
    # host network 모드 — 127.0.0.1:8091(prefix-proxy), :8090(llama-swap), :5432(db) 직결.
    # HINDSIGHT_API_HOST=0.0.0.0 + :8888 listen, firewall로 외부 차단.
    "containers/systemd/hindsight.container".text = ''
      [Unit]
      Description=Hindsight API container
      Requires=hindsight-db.service
      After=network-online.target hindsight-db.service llama-swap.service embed-prefix-proxy.service
      Wants=network-online.target

      [Container]
      ContainerName=hindsight
      Image=${images.hindsight}
      Pull=missing
      LogDriver=journald
      EnvironmentFile=${servicesEnv}
      Environment=HINDSIGHT_API_VECTOR_EXTENSION=pgvector
      Environment=HINDSIGHT_API_TEXT_SEARCH_EXTENSION=pg_textsearch

      Environment=HINDSIGHT_API_LLM_PROVIDER=openrouter
      Environment=HINDSIGHT_API_LLM_MODEL=google/gemma-4-31b-it
      Environment=HINDSIGHT_API_RETAIN_LLM_PROVIDER=openrouter
      Environment=HINDSIGHT_API_RETAIN_LLM_MODEL=google/gemma-4-31b-it
      Environment=HINDSIGHT_API_REFLECT_LLM_PROVIDER=groq
      Environment=HINDSIGHT_API_REFLECT_LLM_MODEL=openai/gpt-oss-20b
      Environment=HINDSIGHT_API_CONSOLIDATION_LLM_PROVIDER=openrouter
      Environment=HINDSIGHT_API_CONSOLIDATION_LLM_MODEL=google/gemma-4-31b-it

      # Embedding → openai provider → 127.0.0.1:8091 (host network)
      Environment=HINDSIGHT_API_EMBEDDINGS_PROVIDER=openai
      Environment=HINDSIGHT_API_EMBEDDINGS_OPENAI_BASE_URL=http://127.0.0.1:8091/v1
      Environment=HINDSIGHT_API_EMBEDDINGS_OPENAI_MODEL=harrier
      Environment=HINDSIGHT_API_EMBEDDINGS_OPENAI_API_KEY=sk-local

      # Reranker → cohere provider → 127.0.0.1:8090 (host network)
      # 0.5.2 CohereCrossEncoder는 base_url을 그대로 rerank_url로 사용 (path append 없음).
      # Azure AI Foundry 호환 분기와 동일 — full endpoint URL 필수.
      Environment=HINDSIGHT_API_RERANKER_PROVIDER=cohere
      Environment=HINDSIGHT_API_RERANKER_COHERE_BASE_URL=http://127.0.0.1:8090/v1/rerank
      Environment=HINDSIGHT_API_RERANKER_COHERE_MODEL=qwen3-reranker
      Environment=HINDSIGHT_API_RERANKER_COHERE_API_KEY=sk-local

      Environment=HINDSIGHT_API_LLM_MAX_CONCURRENT=6
      Environment=HINDSIGHT_API_RETAIN_LLM_MAX_CONCURRENT=3
      Environment=HINDSIGHT_API_CONSOLIDATION_LLM_MAX_CONCURRENT=2
      Environment=HINDSIGHT_API_RECALL_MAX_CONCURRENT=6
      # DB 병렬도 4 → 6 (vector search 단축). LLM concurrent(6)와 대칭.
      Environment=HINDSIGHT_API_RECALL_CONNECTION_BUDGET=6
      Environment=HINDSIGHT_API_MENTAL_MODEL_REFRESH_CONCURRENCY=2

      Environment=HINDSIGHT_API_DB_POOL_MIN_SIZE=2
      Environment=HINDSIGHT_API_DB_POOL_MAX_SIZE=20

      Environment=HINDSIGHT_API_WORKER_MAX_SLOTS=4
      Environment=HINDSIGHT_API_WORKER_CONSOLIDATION_MAX_SLOTS=2

      # Claude Code recall 훅 latency 튜닝 (2026-04-21 실측 fix + llama-swap groups).
      # llama-swap groups.retrieval {swap:false, persistent:true} 이후 embedding
      # warm path 15-175ms 복원. rerank 60 candidates = 3.84-4.37s (실측).
      # `recall.py:153 timeout=10` 하드코딩이 실질 ceiling → 9s 내 진입 필요.
      # MAX_CANDIDATES 60 → 100: 선형 외삽 ~6.8s 예상, 10s budget 여유 ~3s.
      # BUDGET_FIXED_LOW 40 → 100 (default): latency knob 아닌 품질 knob.
      #   pool 1200(=100×4methods×3types) → RRF fusion → top-100 rerank.
      #   각 retrieval method 다양성 확보, RRF 품질 향상. pgvector HNSW 로그 스케일.
      # UMA carve-out 16 GiB 해제 후 상향 검토 — 32 GB 풀파워 시 150 여유.
      Environment=HINDSIGHT_API_RERANKER_MAX_CANDIDATES=100
      Environment=HINDSIGHT_API_RECALL_BUDGET_FIXED_LOW=100
      Environment=HINDSIGHT_API_LAZY_RERANKER=true

      Environment=HINDSIGHT_API_LLM_MAX_RETRIES=5
      Environment=HINDSIGHT_API_SKIP_LLM_VERIFICATION=true

      Environment=HINDSIGHT_API_HOST=0.0.0.0
      Environment=HINDSIGHT_API_PORT=8888
      Environment=HINDSIGHT_API_TENANT_EXTENSION=hindsight_api.extensions.builtin.tenant:ApiKeyTenantExtension

      # host network 모드 — ports publish 무의미(HINDSIGHT_API_HOST=0.0.0.0이 직접 호스트 :8888 listen).
      Network=host

      [Service]
      Restart=on-failure
      RestartSec=5s
      TimeoutStartSec=0
      TimeoutStopSec=120

      [Install]
      WantedBy=multi-user.target
    '';
  };
}
