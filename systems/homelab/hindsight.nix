# Hindsight — 코딩 에이전트(Claude Code, Codex, pi)가 공유하는 메모리 서버.
# 공개 노출은 Caddy(loopback) → cloudflared 경유만 허용하고, 인증은 Hindsight API 키다.
# 코딩 에이전트 클라이언트가 Authorization 헤더만 보낼 수 있어 CF Access는 걸지 않는다.
#
# 구성: API 컨테이너(리랭커 hs-rerank-1 내장) + 공유 PostgreSQL(pgvector)
#       + llama.cpp 임베딩(KURE-v3) + 차원 절단 프록시. LLM은 OpenRouter.
#
# 2단계 활성화 (새 sops secret과 소비 서비스를 한 switch에 넣으면 243/CREDENTIALS로 실패):
#   1. enable — secret·DB·임베딩·라우팅만 배포
#   2. server.enable — secret을 읽는 DB 설정 oneshot과 API 컨테이너
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homelab.hindsight;
  domain = "hindsight.deopjib.cc";
  # 앱 레인(loopbackPortBase 18100+, caddy 18099), beszel(18090-18091)과 겹치지 않는 로컬 포트.
  caddyPort = 18092;
  apiPort = 18093;
  embeddingPort = 18094;
  llamaPort = 18095;

  # 태그는 움직일 수 있으므로 digest로 고정한다 (hindsight-api:1.2.1, 멀티 아키텍처 인덱스).
  # slim 이미지는 torch가 없어 hs-rerank-1을 프로세스 안에서 돌리지 못한다.
  image = "ghcr.io/vectorize-io/hindsight-api@sha256:662109ece429871a81e036427fb93fbb09ba9dc4b01d320d356f114c0e1aedd8";

  # KURE-v3는 2,048차원 Matryoshka 모델이다. 1,024차원으로 잘라 쓴다(docs/adr/0001).
  # 차원을 바꾸면 저장된 벡터를 전부 다시 임베딩해야 한다.
  embeddingDimensions = 1024;
  embeddingModel = pkgs.fetchurl {
    url = "https://huggingface.co/mradermacher/KURE-v3-i1-GGUF/resolve/69c6ba8dfa49c8e2c714e849fbb5ea83bc85dafd/KURE-v3.i1-Q4_K_S.gguf";
    hash = "sha256-xrydOEPJo9i7H4kmJChYzVgozvkwCipdQRcy5OY15HU=";
  };

  secretsFile = ../../secrets/homelab/secrets.yaml;
in
{
  options.homelab.hindsight = {
    enable = lib.mkEnableOption "Hindsight memory server prerequisites (secrets, database, embeddings, routing)";
    server.enable = lib.mkEnableOption "Hindsight API container (requires the sops secrets to be deployed first)";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      sops.secrets = {
        HINDSIGHT_DB_PASSWORD.mode = "0400";
        HINDSIGHT_API_KEY.mode = "0400";
        OPENROUTER_API_KEY = {
          sopsFile = secretsFile;
          mode = "0400";
        };
      };

      sops.templates."hindsight.env" = {
        content = ''
          HINDSIGHT_API_DATABASE_URL=postgresql://hindsight:${config.sops.placeholder.HINDSIGHT_DB_PASSWORD}@127.0.0.1:5432/hindsight
          HINDSIGHT_API_TENANT_API_KEY=${config.sops.placeholder.HINDSIGHT_API_KEY}
          HINDSIGHT_API_LLM_API_KEY=${config.sops.placeholder.OPENROUTER_API_KEY}
        '';
        mode = "0400";
      };

      homelab.postgres.enable = true;
      services.postgresql = {
        extensions = ps: [ ps.pgvector ];
        ensureDatabases = [ "hindsight" ];
        ensureUsers = [
          {
            name = "hindsight";
            ensureDBOwnership = true;
          }
        ];
      };

      systemd.services.hindsight-embedding = {
        description = "llama.cpp embedding server for Hindsight (KURE-v3)";
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          ExecStart = lib.escapeShellArgs [
            "${config.services.llama-cpp.package}/bin/llama-server"
            "--model"
            embeddingModel
            "--embeddings"
            "--host"
            "127.0.0.1"
            "--port"
            (toString llamaPort)
            # 슬롯 2개 × 8,192 토큰 (모델 최대 입력 길이).
            "--ctx-size"
            "16384"
            "--parallel"
            "2"
          ];
          DynamicUser = true;
          Restart = "on-failure";
          RestartSec = "5s";
        };
      };

      systemd.services.hindsight-embedding-proxy = {
        description = "Matryoshka truncation proxy in front of the Hindsight embedding server";
        wantedBy = [ "multi-user.target" ];
        after = [ "hindsight-embedding.service" ];
        environment = {
          UPSTREAM = "http://127.0.0.1:${toString llamaPort}";
          LISTEN_PORT = toString embeddingPort;
        };
        serviceConfig = {
          ExecStart = "${pkgs.python3}/bin/python3 ${./hindsight-embedding-proxy.py}";
          DynamicUser = true;
          Restart = "on-failure";
          RestartSec = "5s";
        };
      };

      services.caddy.virtualHosts."http://${domain}:${toString caddyPort}" = {
        extraConfig = ''
          bind 127.0.0.1

          respond /metrics 404
          reverse_proxy 127.0.0.1:${toString apiPort}
        '';
      };

      services.cloudflared.tunnels."a19003a7-293f-4872-b8a5-1db544878f45".ingress.${domain} =
        "http://localhost:${toString caddyPort}";
    })

    (lib.mkIf (cfg.enable && cfg.server.enable) {
      # 확장은 superuser가 미리 만든다. Hindsight는 이미 있는 확장을 건너뛰므로
      # 앱 role은 superuser 권한 없이 자기 DB만 소유한다.
      systemd.services.hindsight-postgres-setup = {
        description = "Create Hindsight PostgreSQL extensions and sync the role password from sops";
        requires = [
          "postgresql.service"
          "sops-install-secrets.service"
        ];
        after = [
          "postgresql.service"
          "postgresql-setup.service"
          "sops-install-secrets.service"
        ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = "postgres";
          LoadCredential = [ "db-password:${config.sops.secrets.HINDSIGHT_DB_PASSWORD.path}" ];
        };
        script = ''
          PG_APP_PASSWORD=$(cat "$CREDENTIALS_DIRECTORY/db-password") \
            ${config.services.postgresql.package}/bin/psql \
            --dbname hindsight --no-psqlrc --quiet \
            --set ON_ERROR_STOP=1 --file - <<'SQL'
          CREATE EXTENSION IF NOT EXISTS vector;
          CREATE EXTENSION IF NOT EXISTS pg_trgm;
          CREATE EXTENSION IF NOT EXISTS btree_gin;
          \getenv pw PG_APP_PASSWORD
          ALTER ROLE hindsight WITH PASSWORD :'pw';
          SQL
        '';
      };

      # host 네트워크: PostgreSQL과 임베딩이 모두 loopback에 있다. API도 loopback에만 바인딩한다.
      virtualisation.quadlet.containers.hindsight = {
        autoStart = true;
        unitConfig = {
          Requires = [
            "hindsight-postgres-setup.service"
            "sops-install-secrets.service"
          ];
          After = [
            "hindsight-postgres-setup.service"
            "hindsight-embedding-proxy.service"
            "sops-install-secrets.service"
            "network-online.target"
          ];
          Wants = [ "network-online.target" ];
        };
        containerConfig = {
          name = "hindsight";
          inherit image;
          pull = "missing";
          logDriver = "journald";
          networks = [ "host" ];
          environmentFiles = [ config.sops.templates."hindsight.env".path ];
          environments = {
            HINDSIGHT_API_HOST = "127.0.0.1";
            HINDSIGHT_API_PORT = toString apiPort;

            HINDSIGHT_API_TENANT_EXTENSION = "hindsight_api.extensions.builtin.tenant:ApiKeyTenantExtension";

            HINDSIGHT_API_LLM_PROVIDER = "openrouter";
            HINDSIGHT_API_LLM_MODEL = "deepseek/deepseek-v4.1-flash";
            # 기동이 OpenRouter 가용성에 묶이지 않게 한다.
            HINDSIGHT_API_SKIP_LLM_VERIFICATION = "true";

            HINDSIGHT_API_EMBEDDINGS_PROVIDER = "openai";
            HINDSIGHT_API_EMBEDDINGS_OPENAI_BASE_URL = "http://127.0.0.1:${toString embeddingPort}/v1";
            HINDSIGHT_API_EMBEDDINGS_OPENAI_MODEL = "KURE-v3";
            HINDSIGHT_API_EMBEDDINGS_OPENAI_API_KEY = "local";
            HINDSIGHT_API_EMBEDDINGS_OPENAI_DIMENSIONS = toString embeddingDimensions;
            HINDSIGHT_API_EMBEDDINGS_QUERY_PREFIX = "query: ";
            HINDSIGHT_API_EMBEDDINGS_PASSAGE_PREFIX = "passage: ";

            # 리랭커는 기본값(local, hindsight-ai/hs-rerank-1)이며 이미지에 들어 있다.

            # 공유 PostgreSQL(max_connections 100)을 앱과 나눠 쓴다. 기본 풀 상한은 100이다.
            HINDSIGHT_API_DB_POOL_MIN_SIZE = "2";
            HINDSIGHT_API_DB_POOL_MAX_SIZE = "10";

            # 최소 구성: 백그라운드 통합(observation 생성)은 끈다. docs/guides/hindsight.md 실험 목록 참고.
            HINDSIGHT_API_ENABLE_AUTO_CONSOLIDATION = "false";
          };
        };
        serviceConfig = {
          Restart = "on-failure";
          RestartSec = "10s";
          # 첫 기동은 약 1GB 이미지를 받는다.
          TimeoutStartSec = 900;
          TimeoutStopSec = 60;
        };
      };
    })
  ];
}
