# hindsight RAG 스택 — 2 컨테이너
#
# hindsight (API, host network) ← hindsight-db (TimescaleDB, publish 127.0.0.1:5432)
# Embedding/Reranker는 ai-stack.nix(호스트 systemd)의 llama-swap으로 위임.
# - embedding: openai provider → 127.0.0.1:8091 (prefix-proxy) → :8090 (llama-swap) → harrier
# - reranker:  cohere provider → 127.0.0.1:8090 (llama-swap) → qwen3-reranker
#
# Docker user-defined bridge 경유 호스트 접근은 환경별 iptables 불안정 →
# hindsight 컨테이너를 host network 모드로 두어 127.0.0.1로 직접 도달하게 단순화.
#
# 비밀 env는 sops.templates."services.env" 경유, 비밀 아닌 env는 environment 맵에 직접.
{
  config,
  ...
}:
let
  servicesEnv = config.sops.templates."services.env".path;

  images = {
    hindsight = "ghcr.io/vectorize-io/hindsight:0.5.2-slim";
    db = "timescale/timescaledb-ha:pg18";
  };
in
{
  virtualisation.oci-containers.backend = "docker";

  virtualisation.oci-containers.containers = {

    # ── TimescaleDB ──────────────────────────────────────────
    # 호스트 127.0.0.1:5432에 publish. hindsight API가 host network에서 localhost로 접근.
    hindsight-db = {
      image = images.db;
      environmentFiles = [ servicesEnv ];
      environment = {
        POSTGRES_USER = "hindsight";
        POSTGRES_DB = "hindsight";
      };
      volumes = [ "hindsight-db-data:/home/postgres/pgdata/data" ];
      ports = [ "127.0.0.1:5432:5432" ];
    };

    # ── Hindsight API ────────────────────────────────────────
    # host network 모드 — 127.0.0.1:8091(prefix-proxy), :8090(llama-swap), :5432(db) 직결.
    # HINDSIGHT_API_HOST=0.0.0.0 + :8888 listen, firewall로 외부 차단.
    hindsight = {
      image = images.hindsight;
      dependsOn = [ "hindsight-db" ];
      environmentFiles = [ servicesEnv ];
      environment = {
        HINDSIGHT_API_VECTOR_EXTENSION = "pgvector";
        HINDSIGHT_API_TEXT_SEARCH_EXTENSION = "pg_textsearch";

        HINDSIGHT_API_LLM_PROVIDER = "openrouter";
        HINDSIGHT_API_LLM_MODEL = "google/gemma-4-31b-it";
        HINDSIGHT_API_RETAIN_LLM_PROVIDER = "openrouter";
        HINDSIGHT_API_RETAIN_LLM_MODEL = "google/gemma-4-31b-it";
        HINDSIGHT_API_REFLECT_LLM_PROVIDER = "groq";
        HINDSIGHT_API_REFLECT_LLM_MODEL = "openai/gpt-oss-20b";
        HINDSIGHT_API_CONSOLIDATION_LLM_PROVIDER = "openrouter";
        HINDSIGHT_API_CONSOLIDATION_LLM_MODEL = "google/gemma-4-31b-it";

        # Embedding → openai provider → 127.0.0.1:8091 (host network)
        HINDSIGHT_API_EMBEDDINGS_PROVIDER = "openai";
        HINDSIGHT_API_EMBEDDINGS_OPENAI_BASE_URL = "http://127.0.0.1:8091/v1";
        HINDSIGHT_API_EMBEDDINGS_OPENAI_MODEL = "harrier";
        HINDSIGHT_API_EMBEDDINGS_OPENAI_API_KEY = "sk-local";

        # Reranker → cohere provider → 127.0.0.1:8090 (host network)
        # 0.5.2 CohereCrossEncoder는 base_url을 그대로 rerank_url로 사용 (path append 없음).
        # Azure AI Foundry 호환 분기와 동일 — full endpoint URL 필수.
        HINDSIGHT_API_RERANKER_PROVIDER = "cohere";
        HINDSIGHT_API_RERANKER_COHERE_BASE_URL = "http://127.0.0.1:8090/v1/rerank";
        HINDSIGHT_API_RERANKER_COHERE_MODEL = "qwen3-reranker";
        HINDSIGHT_API_RERANKER_COHERE_API_KEY = "sk-local";

        HINDSIGHT_API_LLM_MAX_CONCURRENT = "6";
        HINDSIGHT_API_RETAIN_LLM_MAX_CONCURRENT = "3";
        HINDSIGHT_API_CONSOLIDATION_LLM_MAX_CONCURRENT = "2";
        HINDSIGHT_API_RECALL_MAX_CONCURRENT = "6";
        HINDSIGHT_API_RECALL_CONNECTION_BUDGET = "4";
        HINDSIGHT_API_MENTAL_MODEL_REFRESH_CONCURRENCY = "2";

        HINDSIGHT_API_DB_POOL_MIN_SIZE = "2";
        HINDSIGHT_API_DB_POOL_MAX_SIZE = "20";

        HINDSIGHT_API_WORKER_MAX_SLOTS = "4";
        HINDSIGHT_API_WORKER_CONSOLIDATION_MAX_SLOTS = "2";

        # Vulkan iGPU(Radeon 890M) 전환 이후 — 60 리랭크 9.3s 실측.
        # 150 선형 외삽 ~23s, 60s 타임아웃 안전권. 품질 원복.
        HINDSIGHT_API_RERANKER_MAX_CANDIDATES = "150";
        HINDSIGHT_API_LAZY_RERANKER = "true";

        HINDSIGHT_API_LLM_MAX_RETRIES = "5";
        HINDSIGHT_API_SKIP_LLM_VERIFICATION = "true";

        HINDSIGHT_API_HOST = "0.0.0.0";
        HINDSIGHT_API_PORT = "8888";
        HINDSIGHT_API_TENANT_EXTENSION = "hindsight_api.extensions.builtin.tenant:ApiKeyTenantExtension";
      };
      # host network 모드 — ports publish 무의미(HINDSIGHT_API_HOST=0.0.0.0이 직접 호스트 :8888 listen).
      extraOptions = [ "--network=host" ];
    };
  };

  # hindsight API는 ai-stack 기동 이후에 시작.
  systemd.services.docker-hindsight.after = [
    "llama-swap.service"
    "embed-prefix-proxy.service"
  ];
}
