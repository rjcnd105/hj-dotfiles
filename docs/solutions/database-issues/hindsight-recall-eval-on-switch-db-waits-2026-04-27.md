---
title: Hindsight recall-eval on-switch reports unreachable during DB waits
date: 2026-04-27
status: unresolved
last_verified: 2026-04-27
category: database-issues
module: nix-dots homelab switch automation
problem_type: database_issue
component: database
symptoms:
  - "recall-eval-on-switch completed alert-only with hits=0/10 and recall@5=0.00"
  - "recall-eval reported: hindsight unreachable; see alert for details"
  - "Hindsight /health returned 200 while recall evaluation still failed"
  - "reranker proxy smoke test returned 200"
  - "Hindsight logs showed long DB waits and a stuck batch_retain task in retain.phase2.insert_facts"
root_cause: async_timing
resolution_type: documentation_update
severity: high
related_components:
  - tooling
  - development_workflow
  - hindsight
  - recall-eval
tags:
  - hindsight
  - recall-eval
  - on-switch
  - homelab
  - batch-retain
  - database-waits
  - unresolved-follow-up
---

# Hindsight recall-eval on-switch reports unreachable during DB waits

## Problem

After the homelab deploy for `96853d75726444002fea45386e45460f9c6459f0`, `comin` successfully built and switched the NixOS generation, and the `recall-eval-on-switch.service` credential path problem was fixed. The post-switch recall regression probe now runs, but it reports Hindsight as unreachable even though the Hindsight health endpoint and reranker proxy are healthy.

This is an unresolved follow-up report. Do not treat this document as a completed fix. The evidence points away from deployment, systemd credential loading, and reranker availability, and toward Hindsight/Postgres recall-path contention or a stuck async retain operation.

## Symptoms

- `comin` fetched, built, and switched commit `96853d75726444002fea45386e45460f9c6459f0`.
- `/run/current-system` became `/nix/store/hvc07v8562lhc31cw8qwy754w577pdfn-nixos-system-homelab-26.05.20260422.0726a0e`.
- Main services were active: `hindsight-db.service`, `hindsight.service`, `cloudflared-tunnel-a19003a7-293f-4872-b8a5-1db544878f45.service`, `llama-swap.service`, and `embed-prefix-proxy.service`.
- `systemctl list-units --failed` reported `0 loaded units listed`.
- Hindsight health returned `{"status":"healthy","database":"connected"}`.
- `recall-eval-on-switch.service` completed with systemd `Result=success`, but logged:

  ```text
  mode=on-switch fixtures=10 hits=0/10 recall@5=0.00 p90_latency_ms=0 dead_ids=17 alerts=1
  recall-eval: hindsight unreachable; see alert for details
  ```

- Hindsight logs around the same run showed repeated DB waits:

  ```text
  [DB_WAITS] pid=130 app= wait=LWLock.BufferContent state=active age=1899s query='
              WITH input_data AS (
                  SELECT * FROM unnest(
  ```

- Hindsight also reported a stuck background operation:

  ```text
  [WORKER_TASK] [STUCK?] op=8c6dab08-ac7e-4e8d-8121-51a52a79e31e type=batch_retain op_type=unknown bank=my age=2404s stage=retain.phase2.insert_facts stage_age=1899s
  ```

- The recall requests entered Hindsight, but no successful response was observed before the eval client timed out:

  ```text
  [RECALL ::nix-do] Starting recall for query: Qwen3 reranker 가 Vulkan iGPU 가속을 쓰는 이유와 구성...
  [RECALL ::nix-do] Starting recall for query: hindsight recall hook 이 silent timeout 나는 원인과 현재 상...
  ```

## What Didn't Work

- **Fixing `LoadCredential=` path only solved the fixture-read failure.**
  The previous error was `read fixtures: open /run/credentials/recall-eval-on-switch/fixtures.yaml: no such file or directory`. That is fixed by using `${CREDENTIALS_DIRECTORY}/fixtures.yaml`, but recall itself still failed.

- **`/health` was too shallow.**
  `GET /health` confirmed the API process and database connection, but it did not prove the recall path could get timely DB work done.

- **`systemctl list-units --failed` was too shallow.**
  No failed units remained, but `recall-eval-on-switch` is intentionally alert-only. It exits successfully in `on-switch` mode even when recall metrics alert.

- **Direct reranker smoke did not reproduce the failure.**
  A direct request to `http://127.0.0.1:8091/v1/rerank` returned `200` in `5.67s` with scores. This makes the previous reranker/model-swap class less likely as the primary cause for this run.

## Current Findings

The deploy path is verified:

```text
remote main: 96853d75726444002fea45386e45460f9c6459f0
comin output: nix: switch successfully terminated
current system: /nix/store/hvc07v8562lhc31cw8qwy754w577pdfn-nixos-system-homelab-26.05.20260422.0726a0e
```

The `recall-eval-on-switch` unit now has the expected credential wiring:

```text
ExecStart=/nix/store/...-recall-eval-0.1.0/bin/recall-eval --mode on-switch --fixtures ${CREDENTIALS_DIRECTORY}/fixtures.yaml --state-dir /var/lib/recall-eval
LoadCredential=fixtures.yaml:/run/secrets/recall-eval-fixtures
```

The local reranker path is independently healthy:

```text
POST http://127.0.0.1:8091/v1/rerank -> 200 in 5.67s
```

The qwen reranker process was running with the expected runtime flags:

```text
--model /nix/store/...-qwen3-reranker-0.6b-q8_0.gguf
--reranking
--ctx-size 8192
--batch-size 1024
--ubatch-size 1024
--parallel 8
```

The Hindsight container was configured to use the local reranker proxy:

```text
HINDSIGHT_API_RERANKER_COHERE_BASE_URL=http://127.0.0.1:8091/v1/rerank
HINDSIGHT_API_RERANKER_COHERE_MODEL=qwen3-reranker
```

## Current Hypothesis

The remaining failure is probably inside Hindsight recall execution, not in the Nix switch, systemd credentials, service activation, or basic reranker availability.

The strongest current hypothesis is that recall requests are entering Hindsight but timing out because Hindsight/Postgres is blocked or severely delayed by long-running database work, especially a `batch_retain` operation stuck at `retain.phase2.insert_facts`. The repeated `LWLock.BufferContent` waits suggest buffer/page contention or a long-running insert/query workload affecting shared DB resources.

This root cause is not confirmed. The `root_cause: async_timing` frontmatter value is only the closest available schema value for an unresolved async worker/DB contention report.

## Next Investigation Steps

Start by separating three states:

1. Hindsight process liveness
2. recall read-path latency
3. write-path or background-worker DB contention

Basic service and eval state:

```bash
ssh homelab 'sh -lc '\''
readlink -f /run/current-system
systemctl is-active hindsight-db.service hindsight.service llama-swap.service embed-prefix-proxy.service
systemctl list-units --failed --no-pager
systemctl show recall-eval-on-switch.service -p ActiveState -p SubState -p Result -p ExecMainStatus -p ExecMainCode --value
journalctl -u recall-eval-on-switch.service -b --no-pager -n 120
'\'''
```

Hindsight recall and worker logs:

```bash
ssh homelab 'sh -lc '\''
journalctl -u hindsight.service -b --no-pager | rg "DB_WAITS|STUCK|RECALL|recall|8c6dab08"
'\'''
```

Confirm the known-good reranker class is still ruled out:

```bash
ssh homelab 'sh -s' <<'REMOTE'
python3 - <<'PY'
import json, urllib.request, urllib.error, time
url = "http://127.0.0.1:8091/v1/rerank"
data = json.dumps({
    "model": "qwen3-reranker",
    "query": "hello",
    "documents": ["a " * 2000, "hello world"],
}).encode()
req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"}, method="POST")
t = time.time()
try:
    with urllib.request.urlopen(req, timeout=120) as r:
        print(r.status, round(time.time() - t, 2), r.read(600).decode("utf-8", "replace").replace("\n", " "))
except urllib.error.HTTPError as e:
    print(e.code, round(time.time() - t, 2), e.read(800).decode("utf-8", "replace").replace("\n", " "))
except Exception as e:
    print(type(e).__name__, round(time.time() - t, 2), str(e))
PY
REMOTE
```

Inspect Postgres activity. Adjust the container/user command if the deployed auth path differs:

```bash
ssh homelab 'sh -lc '\''
podman exec hindsight-db psql -U hindsight -d hindsight -c "
select
  now(),
  pid,
  state,
  wait_event_type,
  wait_event,
  age(clock_timestamp(), query_start) as age,
  left(query, 240) as query
from pg_stat_activity
where state <> '\''idle'\''
order by query_start nulls last;
"
'\'''
```

Inspect locks:

```bash
ssh homelab 'sh -lc '\''
podman exec hindsight-db psql -U hindsight -d hindsight -c "
select
  locktype,
  mode,
  granted,
  pid,
  relation::regclass
from pg_locks
order by granted, pid;
"
'\'''
```

Inspect async operations for the stuck `batch_retain` operation. Hindsight docs describe `batch_retain` as the operation type triggered by async retain requests and expose operation status through the operations API. Use the real tenant key from the deployed secret environment, not a hard-coded value:

```bash
ssh homelab 'sh -lc '\''
curl -fsS \
  -H "Authorization: Bearer $HINDSIGHT_API_TENANT_API_KEY" \
  http://127.0.0.1:8888/v1/default/banks/my/operations
'\'''
```

If that shell does not have the tenant key, inspect the rendered secret path or run from the Hindsight service environment instead.

## Likely Fix Areas

Do not start by changing reranker flags again. The direct reranker smoke and process flags make that a lower-probability path for this incident.

More likely areas:

- stuck or slow `batch_retain` operation lifecycle
- retained batch size or chunk batch size causing large DB insert phases
- retain DB concurrency too high for current homelab Postgres/HNSW workload
- recall DB connection budget competing with retain writes
- missing cancellation or timeout for long-running background DB phases
- Postgres vacuum/index/page contention during vector insert/query workload

Configuration knobs worth reviewing after measuring the DB state:

```text
HINDSIGHT_API_RETAIN_MAX_CONCURRENT
HINDSIGHT_API_RETAIN_CHUNK_BATCH_SIZE
HINDSIGHT_API_RECALL_MAX_CONCURRENT
HINDSIGHT_API_RECALL_CONNECTION_BUDGET
HINDSIGHT_API_DB_POOL_MIN_SIZE
HINDSIGHT_API_DB_POOL_MAX_SIZE
```

The local Hindsight reference docs state that recall should normally be fast because embeddings and indexes are precomputed during retention, and list recall search as typically bounded by reranker/vector-search work. In this incident, reranker smoke is healthy but DB waits dominate, so treat it as write-path contention leaking into read-path recall.

## Prevention

- `recall-eval` alerts after a successful switch must not stop at `/health`. `/health` only proves API/DB basic liveness.
- If Hindsight health is OK and reranker proxy smoke is OK, the next triage branch should inspect Postgres waits, DB pool utilization, async operations, and active stuck retain/consolidation work.
- Distinguish read-path timeout from write-path contention. Recall can fail because retain/worker DB phases saturate shared DB resources even when reranker is healthy.
- Add a richer `recall-eval` alert classification so `hindsight unreachable` distinguishes at least:
  - HTTP connection failure
  - recall request timeout
  - non-2xx Hindsight response
  - reranker timeout
  - DB wait or stuck worker detected
- Consider adding a post-switch diagnostic that logs active non-idle Postgres queries when `recall-eval` reports `Unreachable`.
- After the root cause is fixed, update `systems/homelab/recall-eval/README.md` with the triage branch: health OK plus reranker OK means inspect `DB_WAITS`, `async_operations`, and stuck `batch_retain`.

## Related Issues

- [`docs/solutions/performance-issues/hindsight-recall-hook-silent-timeout-2026-04-21.md`](../performance-issues/hindsight-recall-hook-silent-timeout-2026-04-21.md) — same recall timeout symptom family, but solved by llama-swap model residency and reranker latency tuning. Use as a ruled-out class here, not as the primary explanation.
- [`docs/solutions/performance-issues/hindsight-reranker-vulkan-acceleration-2026-04-19.md`](../performance-issues/hindsight-reranker-vulkan-acceleration-2026-04-19.md) — historical reranker performance context. Current incident has a healthy direct reranker smoke.
- [`docs/solutions/tooling-decisions/homelab-podman-quadlet-runtime-migration-2026-04-27.md`](../tooling-decisions/homelab-podman-quadlet-runtime-migration-2026-04-27.md) — current Hindsight service names and Podman/Quadlet runtime boundary.
- [`docs/plans/2026-04-17-002-feat-hindsight-data-migration-cutover-plan.md`](../../plans/2026-04-17-002-feat-hindsight-data-migration-cutover-plan.md) — relevant background on async operations, worker quiescence, and DB cutover checks.
- [`systems/homelab/recall-eval/README.md`](../../../systems/homelab/recall-eval/README.md) — recall regression gate runbook; update after this incident is fixed.
