# hindsight RAG 스택 — 2 컨테이너 + 공유 네트워크/볼륨
#
# hindsight (API) ← hindsight-db (TimescaleDB)
# Embedding/Reranker는 ai-stack.nix(호스트 systemd)의 llama-swap으로 위임.
# - embedding: openai provider → :8091 (prefix-proxy) → :8090 (llama-swap) → harrier
# - reranker:  cohere provider → :8090 (llama-swap) → qwen3-reranker
#
# 비밀 env는 sops.templates."services.env" 경유, 비밀 아닌 env는 environment 맵에 직접.
{
  config,
  pkgs,
  ...
}:
let
  # sops rendered dotenv 파일 (sops.nix에서 선언)
  servicesEnv = config.sops.templates."services.env".path;

  # 이미지 태그 pinning
  images = {
    hindsight = "ghcr.io/vectorize-io/hindsight:0.5.2-slim";
    db = "timescale/timescaledb-ha:pg18";
  };
in
{
  virtualisation.oci-containers.backend = "docker";

  # hindsight 전용 bridge network — 컨테이너 간 이름 해석.
  # 비정상 종료(OOM, kswapd livelock 등) 후 network endpoint가 stale하게 남아
  # 재시작 시 "endpoint with name X already exists" 오류 발생 → 해당 endpoint만 강제 해제.
  systemd.services.init-hindsight-network = {
    description = "hindsight docker bridge network 생성 + stale endpoint 정리";
    after = [
      "network.target"
      "docker.service"
    ];
    requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      docker=${pkgs.docker}/bin/docker

      # 1. network 생성 (없을 때만)
      $docker network inspect hindsight >/dev/null 2>&1 \
        || $docker network create hindsight --driver bridge

      # 2. stale endpoint 일괄 정리 — endpoint는 남아있는데 실제 컨테이너가 없으면 disconnect
      endpoints=$($docker network inspect hindsight \
        --format '{{range .Containers}}{{println .Name}}{{end}}' 2>/dev/null || true)
      for name in $endpoints; do
        [ -z "$name" ] && continue
        if ! $docker inspect "$name" >/dev/null 2>&1; then
          echo "stale endpoint 해제: $name"
          $docker network disconnect -f hindsight "$name" || true
        fi
      done
    '';
  };

  virtualisation.oci-containers.containers = {

    # ── TimescaleDB ──────────────────────────────────────────
    hindsight-db = {
      image = images.db;
      environmentFiles = [ servicesEnv ];
      environment = {
        POSTGRES_USER = "hindsight";
        POSTGRES_DB = "hindsight";
      };
      volumes = [ "hindsight-db-data:/home/postgres/pgdata/data" ];
      extraOptions = [ "--network=hindsight" ];
    };

    # ── Hindsight API ────────────────────────────────────────
    hindsight = {
      image = images.hindsight;
      dependsOn = [
        "hindsight-db"
      ];
      environmentFiles = [ servicesEnv ];
      environment = {
        # DB
        HINDSIGHT_API_VECTOR_EXTENSION = "pgvector";
        HINDSIGHT_API_TEXT_SEARCH_EXTENSION = "pg_textsearch";

        # LLM providers + models
        HINDSIGHT_API_LLM_PROVIDER = "openrouter";
        HINDSIGHT_API_LLM_MODEL = "google/gemma-4-31b-it";
        HINDSIGHT_API_RETAIN_LLM_PROVIDER = "openrouter";
        HINDSIGHT_API_RETAIN_LLM_MODEL = "google/gemma-4-31b-it";
        HINDSIGHT_API_REFLECT_LLM_PROVIDER = "groq";
        HINDSIGHT_API_REFLECT_LLM_MODEL = "openai/gpt-oss-20b";
        HINDSIGHT_API_CONSOLIDATION_LLM_PROVIDER = "openrouter";
        HINDSIGHT_API_CONSOLIDATION_LLM_MODEL = "google/gemma-4-31b-it";

        # Embedding → openai provider → embed-prefix-proxy (host:8091) → llama-swap → harrier
        HINDSIGHT_API_EMBEDDINGS_PROVIDER = "openai";
        HINDSIGHT_API_EMBEDDINGS_OPENAI_BASE_URL = "http://host.docker.internal:8091/v1";
        HINDSIGHT_API_EMBEDDINGS_OPENAI_MODEL = "harrier";
        # llama.cpp는 API 키 검증 안 함 — 더미 값으로 클라이언트 라이브러리만 통과
        HINDSIGHT_API_EMBEDDINGS_OPENAI_API_KEY = "sk-local";

        # Reranker → cohere provider (직접 호환) → llama-swap (host:8090) → qwen3-reranker
        HINDSIGHT_API_RERANKER_PROVIDER = "cohere";
        HINDSIGHT_API_RERANKER_COHERE_BASE_URL = "http://host.docker.internal:8090";
        HINDSIGHT_API_RERANKER_COHERE_MODEL = "qwen3-reranker";
        HINDSIGHT_API_RERANKER_COHERE_API_KEY = "sk-local";

        # Concurrency (VPS 동일값, 실측 후 상향 예정)
        HINDSIGHT_API_LLM_MAX_CONCURRENT = "6";
        HINDSIGHT_API_RETAIN_LLM_MAX_CONCURRENT = "3";
        HINDSIGHT_API_CONSOLIDATION_LLM_MAX_CONCURRENT = "2";
        HINDSIGHT_API_RECALL_MAX_CONCURRENT = "6";
        HINDSIGHT_API_RECALL_CONNECTION_BUDGET = "4";
        HINDSIGHT_API_MENTAL_MODEL_REFRESH_CONCURRENCY = "2";

        # DB pool
        HINDSIGHT_API_DB_POOL_MIN_SIZE = "2";
        HINDSIGHT_API_DB_POOL_MAX_SIZE = "20";

        # Workers
        HINDSIGHT_API_WORKER_MAX_SLOTS = "4";
        HINDSIGHT_API_WORKER_CONSOLIDATION_MAX_SLOTS = "2";

        # Reranker tuning
        HINDSIGHT_API_RERANKER_MAX_CANDIDATES = "150";
        HINDSIGHT_API_LAZY_RERANKER = "true";

        HINDSIGHT_API_LLM_MAX_RETRIES = "5";
        HINDSIGHT_API_SKIP_LLM_VERIFICATION = "true";

        # Server
        HINDSIGHT_API_HOST = "0.0.0.0";
        HINDSIGHT_API_PORT = "8888";
        HINDSIGHT_API_TENANT_EXTENSION = "hindsight_api.extensions.builtin.tenant:ApiKeyTenantExtension";
      };
      ports = [ "127.0.0.1:8888:8888" ];
      extraOptions = [
        "--network=hindsight"
        # Docker bridge 내부에서 호스트 루프백(ai-stack systemd) 접근용 DNS 별칭
        "--add-host=host.docker.internal:host-gateway"
      ];
    };
  };

  # 전 컨테이너가 network 생성 후에 시작
  systemd.services.docker-hindsight-db.after = [ "init-hindsight-network.service" ];
  systemd.services.docker-hindsight-db.requires = [ "init-hindsight-network.service" ];

  # hindsight API는 ai-stack 기동 이후에 시작 (첫 recall 요청이 llama-swap warm-up을 타지 않도록)
  systemd.services.docker-hindsight.after = [
    "init-hindsight-network.service"
    "llama-swap.service"
    "embed-prefix-proxy.service"
  ];
  systemd.services.docker-hindsight.requires = [ "init-hindsight-network.service" ];
}
