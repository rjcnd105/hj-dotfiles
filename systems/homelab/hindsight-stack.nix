# hindsight RAG 스택 — 4 컨테이너 + 공유 네트워크/볼륨
#
# hindsight (API) ← hindsight-db (TimescaleDB) + tei-embed (bge-m3) + tei-rerank (bge-reranker-v2-m3)
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
    tei = "ghcr.io/huggingface/text-embeddings-inference:cpu-latest";
  };
in
{
  virtualisation.oci-containers.backend = "docker";

  # hindsight 전용 bridge network — 컨테이너 간 이름 해석
  systemd.services.init-hindsight-network = {
    description = "hindsight docker bridge network 생성";
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
      ${pkgs.docker}/bin/docker network inspect hindsight >/dev/null 2>&1 || \
      ${pkgs.docker}/bin/docker network create hindsight --driver bridge
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

    # ── TEI Embedding (bge-m3, CPU) ──────────────────────────
    tei-embed = {
      image = images.tei;
      cmd = [
        "--model-id"
        "BAAI/bge-m3"
        "--port"
        "80"
      ];
      volumes = [ "hf_cache:/data" ];
      ports = [ "127.0.0.1:8001:80" ];
      extraOptions = [ "--network=hindsight" ];
    };

    # ── TEI Reranker (bge-reranker-v2-m3, CPU) ───────────────
    tei-rerank = {
      image = images.tei;
      cmd = [
        "--model-id"
        "BAAI/bge-reranker-v2-m3"
        "--port"
        "80"
      ];
      volumes = [ "hf_cache:/data" ];
      ports = [ "127.0.0.1:8002:80" ];
      extraOptions = [ "--network=hindsight" ];
    };

    # ── Hindsight API ────────────────────────────────────────
    hindsight = {
      image = images.hindsight;
      dependsOn = [
        "hindsight-db"
        "tei-embed"
        "tei-rerank"
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

        # Embedding + Reranker → TEI (로컬 CPU)
        HINDSIGHT_API_EMBEDDINGS_PROVIDER = "tei";
        HINDSIGHT_API_EMBEDDINGS_TEI_URL = "http://tei-embed:80";
        HINDSIGHT_API_RERANKER_PROVIDER = "tei";
        HINDSIGHT_API_RERANKER_TEI_URL = "http://tei-rerank:80";

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
      ];
    };
  };

  # 전 컨테이너가 network 생성 후에 시작
  systemd.services.docker-hindsight-db.after = [ "init-hindsight-network.service" ];
  systemd.services.docker-hindsight-db.requires = [ "init-hindsight-network.service" ];
  systemd.services.docker-tei-embed.after = [ "init-hindsight-network.service" ];
  systemd.services.docker-tei-embed.requires = [ "init-hindsight-network.service" ];

  # TEI reranker는 embed 이후 시작 (동시 모델 로딩 방지 → peak RAM 절감)
  systemd.services.docker-tei-rerank.after = [
    "init-hindsight-network.service"
    "docker-tei-embed.service"
  ];
  systemd.services.docker-tei-rerank.requires = [ "init-hindsight-network.service" ];

  systemd.services.docker-hindsight.after = [ "init-hindsight-network.service" ];
  systemd.services.docker-hindsight.requires = [ "init-hindsight-network.service" ];
}
