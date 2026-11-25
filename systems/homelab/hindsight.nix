# Hindsight: 공개 노출은 Caddy(loopback) → cloudflared 경유만 허용한다.
# API는 코딩 에이전트가 Authorization 헤더만 보낼 수 있어 CF Access를 걸지 않고 API 키로 인증한다.
# Control Plane(hindsight-ui)은 API 키가 컨테이너에만 있어 CF Access 앱이 있어야만 노출한다.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homelab.hindsight;
  domain = "hindsight.deopjib.cc";
  dashboardDomain = "hindsight-ui.deopjib.cc";
  apiPort = 18093;
  embeddingPort = 18094;
  llamaPort = 18095;
  dashboardPort = 18097;
  rerankerPort = 18098;

  hindsightVersion = "1.3.0";
  # slim 전환은 1.3.0 안정화 검증 후 별도 단계로 분리한다.
  image = "ghcr.io/vectorize-io/hindsight-api:${hindsightVersion}@sha256:c054765e9196fb1fe63497be06bcb55256c9024cc9314f951dc59858985ab242";
  dashboardImage = "ghcr.io/vectorize-io/hindsight-control-plane:${hindsightVersion}@sha256:df58ce2597e837f359684cfe0e004aaa93bbb89983f1f1b8bd2cab881b457554";

  # KURE-v3는 2,048차원 Matryoshka 모델이다. 1,024차원으로 잘라 쓴다(docs/adr/0001).
  # 차원을 바꾸면 저장된 벡터를 전부 다시 임베딩해야 한다.
  embeddingDimensions = 1024;
  embeddingModel = pkgs.fetchurl {
    url = "https://huggingface.co/mradermacher/KURE-v3-i1-GGUF/resolve/69c6ba8dfa49c8e2c714e849fbb5ea83bc85dafd/KURE-v3.i1-Q4_K_S.gguf";
    hash = "sha256-xrydOEPJo9i7H4kmJChYzVgozvkwCipdQRcy5OY15HU=";
  };
  rerankerModel = pkgs.fetchurl {
    url = "https://huggingface.co/tykan/KURE-Reranker-nano-GGUF/resolve/96a9b5afa1b21baf5b329628e4a911dfe618e07a/KURE-Reranker-nano.F16.gguf";
    hash = "sha256-qwUcTBYgR7jrJjgJql/A8yCjDx0a5gEHTI4iCdgcm2M=";
  };

  # hindsight-reranker 장애(failed 상태 진입) 시 Telegram 알림을 보낸다.
  # 토큰이 argv/store에 남지 않도록 LoadCredential + curl stdin 설정을 사용한다.
  rerankerNotify = pkgs.writeShellApplication {
    name = "hindsight-reranker-telegram-notify";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.systemd
    ];
    text = ''
      cred_dir="''${CREDENTIALS_DIRECTORY:-}"
      token_file="$cred_dir/telegram-bot-token"
      chat_id_file="$cred_dir/telegram-chat-id"
      [ -r "$token_file" ] && [ -r "$chat_id_file" ] || {
        echo "hindsight-reranker-notify: telegram credentials unreadable" >&2
        exit 0
      }

      status="$(systemctl show -p ActiveState -p SubState -p Result hindsight-reranker.service 2>/dev/null | tr '\n' ' ' || true)"
      logs="$(journalctl -u hindsight-reranker.service -n 5 --no-pager --output=short-iso 2>/dev/null | tail -c 600 || true)"
      text="$(printf '⚠️ homelab hindsight-reranker.service 장애\n상태: %s\nHindsight recall은 RRF fallback으로 동작 중입니다.\n%s' "$status" "$logs")"

      umask 077
      workdir="$(mktemp -d)"
      trap 'rm -rf "$workdir"' EXIT
      printf '%s' "$text" > "$workdir/text"
      tr -d '\n' < "$chat_id_file" > "$workdir/chat"

      printf 'url = "https://api.telegram.org/bot%s/sendMessage"\n' \
        "$(tr -d '\n' < "$token_file")" |
        curl -fsS --config - \
          --connect-timeout 5 --max-time 15 --retry 2 \
          --data-urlencode "chat_id@$workdir/chat" \
          --data-urlencode "text@$workdir/text" \
          -o /dev/null || {
        echo "hindsight-reranker-notify: Telegram send failed" >&2
        exit 0
      }
    '';
  };

  retainInstructions = lib.strings.trim (builtins.readFile ./hindsight-retain-instructions.txt);
  reflectMission = lib.strings.trim (builtins.readFile ./hindsight-reflect-mission.txt);

  secretsFile = ../../secrets/homelab/secrets.yaml;
in
{
  options.homelab.hindsight = {
    enable = lib.mkEnableOption "Hindsight memory server prerequisites (secrets, database, embeddings, reranker, API routing)";
    server.enable = lib.mkEnableOption "Hindsight API container and DB setup (requires sops secrets to be deployed first)";
    dashboard.enable = lib.mkEnableOption "Hindsight Control Plane and dashboard route behind CF Access (requires env template to be deployed first)";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      hardware.graphics.enable = true;

      homelab.reservedLoopbackPorts = [
        apiPort
        embeddingPort
        llamaPort
        rerankerPort
      ];

      homelab.publicRoutes.${domain}.extraConfig = ''
        respond /metrics 404
        reverse_proxy 127.0.0.1:${toString apiPort}
      '';

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
        restartUnits = lib.optional cfg.server.enable "hindsight.service";
      };

      sops.templates."hindsight-control-plane.env" = {
        content = ''
          HINDSIGHT_CP_DATAPLANE_API_KEY=${config.sops.placeholder.HINDSIGHT_API_KEY}
        '';
        mode = "0400";
        restartUnits = lib.optional cfg.dashboard.enable "hindsight-control-plane.service";
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
        environment.XDG_CACHE_HOME = "/var/cache/hindsight-embedding";
        serviceConfig = {
          ExecStart = lib.escapeShellArgs [
            "${config.services.llama-cpp.package}/bin/llama-server"
            "--model"
            embeddingModel
            "--embeddings"
            "--n-gpu-layers"
            "99"
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
          CacheDirectory = "hindsight-embedding";
          SupplementaryGroups = [
            "render"
            "video"
          ];
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

      systemd.services.hindsight-reranker = {
        description = "llama.cpp reranker server for Hindsight (KURE-Reranker-nano)";
        wantedBy = [ "multi-user.target" ];
        onFailure = [ "hindsight-reranker-notify.service" ];
        # RestartSec=5s에서는 기본 10초 창 안에 5회 실패에 도달하지 못해 failed 상태와
        # OnFailure 알림이 영영 발동하지 않는다. 120초 창으로 크래시 루프를 감지한다.
        startLimitIntervalSec = 120;
        startLimitBurst = 5;
        environment.XDG_CACHE_HOME = "/var/cache/hindsight-reranker";
        serviceConfig = {
          ExecStart = lib.escapeShellArgs [
            "${config.services.llama-cpp.package}/bin/llama-server"
            "--model"
            rerankerModel
            "--reranking"
            "--pooling"
            "rank"
            "--n-gpu-layers"
            "99"
            "--host"
            "127.0.0.1"
            "--port"
            (toString rerankerPort)
            # 슬롯 2개 × 8,192 토큰 (ModernBERT 최대 입력 길이). 비인과 인코더는 단일 시퀀스를
            # ubatch로 쪼갤 수 없어 batch/ubatch를 슬롯 길이와 맞춘다.
            "--ctx-size"
            "16384"
            "--batch-size"
            "8192"
            "--ubatch-size"
            "8192"
            "--parallel"
            "2"
          ];
          DynamicUser = true;
          CacheDirectory = "hindsight-reranker";
          SupplementaryGroups = [
            "render"
            "video"
          ];
          Restart = "on-failure";
          RestartSec = "5s";
        };
      };

      systemd.services.hindsight-reranker-notify = {
        description = "Send Telegram alert when hindsight-reranker.service fails";
        requires = [ "sops-install-secrets.service" ];
        after = [
          "sops-install-secrets.service"
          "network-online.target"
        ];
        wants = [ "network-online.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = lib.getExe rerankerNotify;
          DynamicUser = true;
          SupplementaryGroups = [ "systemd-journal" ];
          LoadCredential = [
            "telegram-bot-token:${config.sops.secrets.TELEGRAM_BOT_TOKEN.path}"
            "telegram-chat-id:${config.sops.secrets.TELEGRAM_CHAT_ID.path}"
          ];
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          NoNewPrivileges = true;
        };
      };
    })

    (lib.mkIf cfg.server.enable {
      assertions = [
        {
          assertion = cfg.enable;
          message = "homelab.hindsight.server.enable requires homelab.hindsight.enable.";
        }
      ];

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
            "hindsight-reranker.service"
            "sops-install-secrets.service"
            "network-online.target"
          ];
          Wants = [
            "hindsight-reranker.service"
            "network-online.target"
          ];
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
            HINDSIGHT_API_LLM_MODEL = "deepseek/deepseek-v4.1-flash-1017";
            HINDSIGHT_API_LLM_EXTRA_BODY = builtins.toJSON {
              provider = {
                sort = "price";
                quantizations = [
                  "fp8"
                  "fp16"
                  "bf16"
                ];
              };
            };
            HINDSIGHT_API_SKIP_LLM_VERIFICATION = "true";

            HINDSIGHT_API_EMBEDDINGS_PROVIDER = "openai";
            HINDSIGHT_API_EMBEDDINGS_OPENAI_BASE_URL = "http://127.0.0.1:${toString embeddingPort}/v1";
            HINDSIGHT_API_EMBEDDINGS_OPENAI_MODEL = "KURE-v3";
            HINDSIGHT_API_EMBEDDINGS_OPENAI_API_KEY = "local";
            HINDSIGHT_API_EMBEDDINGS_OPENAI_DIMENSIONS = toString embeddingDimensions;
            HINDSIGHT_API_EMBEDDINGS_QUERY_PREFIX = "query: ";
            HINDSIGHT_API_EMBEDDINGS_PASSAGE_PREFIX = "passage: ";

            # 리랭커는 로컬 llama.cpp(KURE-Reranker-nano, Vulkan)를 Cohere /v1/rerank 호환으로 호출한다.
            # 기본 내장 hs-rerank-1(CPU) 대비 6건 실측에서 서버 리랭킹 평균을 약 14% 단축했고,
            # 장애·지연 시 클라이언트 7초 제한 안에서 RRF로 자동 전환한다(30초 cooldown 후 자동 복구).
            HINDSIGHT_API_RERANKER_PROVIDER = "cohere";
            HINDSIGHT_API_RERANKER_COHERE_BASE_URL = "http://127.0.0.1:${toString rerankerPort}/v1/rerank";
            HINDSIGHT_API_RERANKER_COHERE_API_KEY = "local";
            HINDSIGHT_API_RERANKER_COHERE_MODEL = "KURE-Reranker-nano";
            HINDSIGHT_API_RERANKER_COHERE_MAX_CONCURRENT = "2";
            HINDSIGHT_API_RERANKER_COHERE_TIMEOUT = "5.5";
            HINDSIGHT_API_RERANKER_MAX_RETRIES = "1";
            HINDSIGHT_API_RERANKER_INITIAL_BACKOFF = "0.2";
            HINDSIGHT_API_RERANKER_RETRY_BUDGET = "5.5";
            HINDSIGHT_API_RERANKER_1_PROVIDER = "rrf";
            HINDSIGHT_API_RERANKER_MAX_CANDIDATES_LOW = "80";

            # 공유 PostgreSQL(max_connections 100)을 앱과 나눠 쓴다. 기본 풀 상한은 100이다.
            HINDSIGHT_API_DB_POOL_MIN_SIZE = "2";
            HINDSIGHT_API_DB_POOL_MAX_SIZE = "10";

            HINDSIGHT_API_RETAIN_EXTRACTION_MODE = "custom";
            HINDSIGHT_API_RETAIN_CUSTOM_INSTRUCTIONS = retainInstructions;
            HINDSIGHT_API_RETAIN_CHUNK_SIZE = "12000";
            HINDSIGHT_API_REFLECT_MISSION = reflectMission;

            # v1.3.0부터 기본 활성화된 Knowledge Banks(멀티모달 문서고)는 쓰지 않아 워커·메모리 예산을 막는다.
            HINDSIGHT_API_ENABLE_KB = "false";
            HINDSIGHT_API_ENABLE_AUTO_CONSOLIDATION = "false";
            HINDSIGHT_API_CONSOLIDATION_LLM_PARALLELISM = "1";
            HINDSIGHT_API_RECALL_PREFER_OBSERVATIONS = "true";
            HINDSIGHT_API_OBSERVATIONS_MISSION = "This bank is a lessons log for coding agents. Each fact is already one complete lesson: a failure with its symptom, exact error string, cause and fix, a verified command or setting, a user preference, or a settled decision. Treat every fact as lasting. In this bank ONE FACET means ONE WHOLE LESSON, so never split a fact: a fact that adds something gets exactly ONE entry in new, the fact's own text kept whole, with commands, flags, paths, ports, values and error strings copied exactly; it may be long. Every observation must read alone: name the project, tool, file or setting, and never point to another sentence ('this value', 'the fix is', 'in that case'). Before writing new, look for an existing observation about the same problem or the same setting, even when worded differently: if it already covers the fact, mark repeats; if the fact adds a cause, fix, condition or value to it, mark changes and write text as the full merged lesson, keeping every exact value from both. The same failure, command or setting seen again at a later time is the same lesson, not a separate event: mark repeats. For an earlier fact of this batch, use same_as_fact only when this fact adds nothing. Lessons about different problems stay separate even when they share a tool, project or port.";
          };
        };
        serviceConfig = {
          Restart = "on-failure";
          RestartSec = "10s";
          TimeoutStartSec = 900;
          TimeoutStopSec = 60;
        };
      };
    })

    (lib.mkIf cfg.dashboard.enable {
      assertions = [
        {
          assertion = cfg.enable;
          message = "homelab.hindsight.dashboard.enable requires homelab.hindsight.enable.";
        }
      ];

      homelab.reservedLoopbackPorts = [ dashboardPort ];

      homelab.publicRoutes.${dashboardDomain}.extraConfig = ''
        reverse_proxy 127.0.0.1:${toString dashboardPort}
      '';

      virtualisation.quadlet.containers.hindsight-control-plane = {
        autoStart = true;
        unitConfig = {
          Requires = [ "sops-install-secrets.service" ];
          After = [
            "sops-install-secrets.service"
            "hindsight.service"
            "network-online.target"
          ];
          Wants = [ "network-online.target" ];
        };
        containerConfig = {
          name = "hindsight-control-plane";
          image = dashboardImage;
          pull = "missing";
          logDriver = "journald";
          networks = [ "host" ];
          environmentFiles = [ config.sops.templates."hindsight-control-plane.env".path ];
          environments = {
            HINDSIGHT_CP_HOSTNAME = "127.0.0.1";
            HINDSIGHT_CP_PORT = toString dashboardPort;
            HINDSIGHT_CP_DATAPLANE_API_URL = "http://127.0.0.1:${toString apiPort}";
          };
        };
        serviceConfig = {
          Restart = "on-failure";
          RestartSec = "10s";
          TimeoutStartSec = 600;
        };
      };
    })
  ];
}
