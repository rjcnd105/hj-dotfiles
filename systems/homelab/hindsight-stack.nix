# hindsight RAG 스택 — 2 Podman/Quadlet 컨테이너
#
# hindsight (API, host network) ← hindsight-db (TimescaleDB, publish 127.0.0.1:5432)
# Embedding/Reranker는 ai-stack.nix(호스트 systemd)의 llama-swap으로 위임.
# - embedding: openai provider → 127.0.0.1:8091 (prefix-proxy) → :8090 (llama-swap) → harrier
# - reranker:  cohere provider → 127.0.0.1:8091 (input guard) → :8090 (llama-swap) → qwen3-reranker
#
# Container bridge 경유 호스트 접근은 환경별 firewall/NAT 경로가 복잡함 →
# hindsight 컨테이너를 host network 모드로 두어 127.0.0.1로 직접 도달하게 단순화.
#
# 비밀 env는 sops.templates."services.env" 경유, 비밀 아닌 env는 environment 맵에 직접.
{
  config,
  pkgs,
  ...
}:
let
  servicesEnv = config.sops.templates."services.env".path;
  legacyDbVolumePath = "/var/lib/docker/volumes/hindsight-db-data/_data";
  podmanDnsLifecycleService = "podman-dns-lifecycle.service";

  images = {
    # GHCR does not publish a semantic 0.8.4-slim tag; latest-slim's OCI
    # index digest is pinned here and its image label is 0.8.4-slim.
    hindsight = "ghcr.io/vectorize-io/hindsight:latest-slim@sha256:9873b311f77a3e25813cadd14ccb10d730583aeb9d2c6e2107350e00c7af12bf";
    db = "timescale/timescaledb-ha:pg18";
  };

  applyDbSettings = pkgs.writeShellScript "hindsight-db-apply-settings" ''
    set -eu

    for attempt in $(${pkgs.coreutils}/bin/seq 1 60); do
      if ${pkgs.podman}/bin/podman exec hindsight-db psql -U hindsight -d hindsight -v ON_ERROR_STOP=1 -c 'select 1' >/dev/null 2>&1; then
        break
      fi

      if [ "$attempt" = 60 ]; then
        echo "hindsight-db did not become ready in time" >&2
        exit 1
      fi

      ${pkgs.coreutils}/bin/sleep 1
    done

    ${pkgs.podman}/bin/podman exec hindsight-db psql -U hindsight -d hindsight -v ON_ERROR_STOP=1 \
      -c "ALTER ROLE hindsight IN DATABASE hindsight SET statement_timeout = '120s';"

    ${pkgs.podman}/bin/podman exec hindsight-db psql -U hindsight -d hindsight -v ON_ERROR_STOP=1 \
      -c "SHOW statement_timeout;"
  '';
in
{
  system.activationScripts.hindsightDbVolumePath = ''
    mkdir -p ${legacyDbVolumePath}
  '';

  system.activationScripts.hindsightQuadletRefresh = {
    deps = [
      "etc"
      "specialfs"
    ];
    text = ''
      unit_file=/etc/containers/systemd/hindsight.container
      state_dir=/var/lib/hindsight-stack
      marker=$state_dir/hindsight.container.sha256

      if [ -e "$unit_file" ]; then
        mkdir -p "$state_dir"
        new_hash="$(${pkgs.coreutils}/bin/sha256sum "$unit_file" | ${pkgs.coreutils}/bin/cut -d ' ' -f1)"
        old_hash="$(${pkgs.coreutils}/bin/cat "$marker" 2>/dev/null || true)"

        if [ "$new_hash" != "$old_hash" ]; then
          ${pkgs.systemd}/bin/systemctl daemon-reload || true
          if ${pkgs.systemd}/bin/systemctl is-active --quiet hindsight.service; then
            if ! ${pkgs.podman}/bin/podman image exists ${images.hindsight}; then
              if ! ${pkgs.podman}/bin/podman pull ${images.hindsight}; then
                echo "warning: not restarting hindsight.service; failed to pull ${images.hindsight}" >&2
                exit 0
              fi
            fi

            if ${pkgs.systemd}/bin/systemctl restart hindsight.service; then
              printf '%s\n' "$new_hash" > "$marker"
            else
              echo "warning: failed to restart hindsight.service after Quadlet change" >&2
            fi
          else
            printf '%s\n' "$new_hash" > "$marker"
          fi
        fi
      fi
    '';
  };

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
      Requires=sops-install-secrets.service hindsight-db-data-volume.service
      After=sops-install-secrets.service network-online.target hindsight-db-data-volume.service
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
      Requires=sops-install-secrets.service hindsight-db.service hindsight-db-settings.service
      After=sops-install-secrets.service network-online.target hindsight-db.service hindsight-db-settings.service llama-swap.service embed-prefix-proxy.service
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
      Environment=HINDSIGHT_API_LLM_MODEL=deepseek/deepseek-v4-flash
      Environment=HINDSIGHT_API_RETAIN_LLM_PROVIDER=openrouter
      Environment=HINDSIGHT_API_RETAIN_LLM_MODEL=deepseek/deepseek-v4-flash
      Environment=HINDSIGHT_API_REFLECT_LLM_PROVIDER=groq
      Environment=HINDSIGHT_API_REFLECT_LLM_MODEL=openai/gpt-oss-20b
      Environment=HINDSIGHT_API_CONSOLIDATION_LLM_PROVIDER=openrouter
      Environment=HINDSIGHT_API_CONSOLIDATION_LLM_MODEL=deepseek/deepseek-v4-flash

      # Embedding → openai provider → 127.0.0.1:8091 (host network)
      Environment=HINDSIGHT_API_EMBEDDINGS_PROVIDER=openai
      Environment=HINDSIGHT_API_EMBEDDINGS_OPENAI_BASE_URL=http://127.0.0.1:8091/v1
      Environment=HINDSIGHT_API_EMBEDDINGS_OPENAI_MODEL=harrier
      Environment=HINDSIGHT_API_EMBEDDINGS_OPENAI_API_KEY=sk-local

      # Reranker → cohere provider → 127.0.0.1:8091 (rerank input guard) → :8090 (llama-swap)
      # 0.5.2 CohereCrossEncoder는 base_url을 그대로 rerank_url로 사용 (path append 없음).
      # Azure AI Foundry 호환 분기와 동일 — full endpoint URL 필수.
      Environment=HINDSIGHT_API_RERANKER_PROVIDER=cohere
      Environment=HINDSIGHT_API_RERANKER_COHERE_BASE_URL=http://127.0.0.1:8091/v1/rerank
      Environment=HINDSIGHT_API_RERANKER_COHERE_MODEL=qwen3-reranker
      Environment=HINDSIGHT_API_RERANKER_COHERE_API_KEY=sk-local

      Environment=HINDSIGHT_API_LLM_MAX_CONCURRENT=6
      Environment=HINDSIGHT_API_RETAIN_LLM_MAX_CONCURRENT=2
      Environment=HINDSIGHT_API_CONSOLIDATION_LLM_MAX_CONCURRENT=2
      Environment=HINDSIGHT_API_RECALL_MAX_CONCURRENT=4
      Environment=HINDSIGHT_API_ENABLE_AUTO_CONSOLIDATION=false
      # homelab의 pgvector/HNSW workload는 retain write phase와 recall read path가
      # 같은 Postgres pool을 공유한다. Retain은 느려도 되지만 recall은 interactive
      # path라서 DB fan-out을 default 근처로 유지한다.
      Environment=HINDSIGHT_API_RECALL_CONNECTION_BUDGET=4
      Environment=HINDSIGHT_API_MENTAL_MODEL_REFRESH_CONCURRENCY=2

      Environment=HINDSIGHT_API_DB_POOL_MIN_SIZE=2
      Environment=HINDSIGHT_API_DB_POOL_MAX_SIZE=20
      # v0.8 applies this on every asyncpg pool connection. The role-level
      # setting below is only a fallback; old app sessions already proved they
      # can run past it and burn a core indefinitely.
      Environment=HINDSIGHT_API_DB_STATEMENT_TIMEOUT=120
      Environment=HINDSIGHT_API_WORKER_ID=homelab

      # 2026-07-02: v0.8.4 still allowed consolidation recall/vector SELECTs to
      # burn a core past statement cancellation. Leave no shared worker slot,
      # because shared capacity can claim consolidation even with reservation 0.
      Environment=HINDSIGHT_API_WORKER_MAX_SLOTS=1
      Environment=HINDSIGHT_API_WORKER_RETAIN_MAX_SLOTS=1
      Environment=HINDSIGHT_API_WORKER_CONSOLIDATION_MAX_SLOTS=0
      Environment=HINDSIGHT_API_RETAIN_MAX_CONCURRENT=1
      Environment=HINDSIGHT_API_RETAIN_CHUNK_BATCH_SIZE=25

      # Claude Code recall 훅 latency 튜닝.
      # 2026-05-15 실측: cap=100 warm recall은 server 7.3s/client 8.3s로
      # `recall.py` 10s timeout에 너무 가깝다. cap=60은 2026-04-21 실측에서
      # rerank 3.84-4.37s, client 4.72-5.52s로 훅 예산 안에 안정적으로 들어왔다.
      # BUDGET_FIXED_LOW=100은 retrieval breadth/품질 knob로 유지하고, latency는
      # 최종 rerank candidate cap만 줄여 제어한다.
      Environment=HINDSIGHT_API_RERANKER_MAX_CANDIDATES=60
      Environment=HINDSIGHT_API_RECALL_BUDGET_FIXED_LOW=100

      Environment=HINDSIGHT_API_LLM_MAX_RETRIES=3
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

  # Quadlet owns these generated units; NixOS contributes only lifecycle drop-ins.
  systemd.services.hindsight-db = {
    overrideStrategy = "asDropin";
    requires = [ podmanDnsLifecycleService ];
    after = [ podmanDnsLifecycleService ];
    partOf = [ podmanDnsLifecycleService ];
  };

  systemd.services.hindsight = {
    overrideStrategy = "asDropin";
    requires = [ podmanDnsLifecycleService ];
    after = [ podmanDnsLifecycleService ];
    partOf = [ podmanDnsLifecycleService ];
  };

  systemd.services.hindsight-db-settings = {
    description = "Apply Hindsight Postgres role settings";
    requires = [ "hindsight-db.service" ];
    after = [ "hindsight-db.service" ];
    before = [ "hindsight.service" ];
    wantedBy = [ "multi-user.target" ];
    restartTriggers = [ applyDbSettings ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = "90s";
      ExecStart = applyDbSettings;
    };
  };
}
