# recall-eval

Upstream gate + post-switch alert-only probe for the Hindsight recall pipeline.
Origin: `docs/brainstorms/26-04-22-recall-regression-eval-cron-requirements.md`
Plan: `docs/plans/2026-04-22-001-feat-recall-regression-eval-gate-plan.md`

## What it does

Runs 10 fixture queries against the local Hindsight `memories/recall` endpoint,
scores each on recall@5 + p90 latency, tracks alert transitions in a state
file, and posts changes to Telegram.

## Modes

| Mode | Trigger | Exit behavior |
|------|---------|---------------|
| `--mode gate` | `just recall-eval-gate` (manual, before risky change) | exit ≠ 0 on critical → caller blocks switch |
| `--mode on-switch` | `system.activationScripts.recallEvalOnSwitch` after every rebuild | always exit 0 (alert-only, never blocks) |
| `--mode ack-all` | `just recall-eval-ack` after investigation | clears Claude hook surface; Telegram still fires on new transitions |

## Alert thresholds

- **critical** `recall@5 < 0.90`
- **critical** `p90_latency_ms > 9000`
- **critical** `recall_unreachable` — hindsight endpoint network/5xx failure
- **warning** `fixture_liveness` — any expected memory id absent from every fixture's top-10

## Response playbook

1. **Read the Telegram message.** `metric` + `bank` + `actual/threshold` tells you
   the axis and magnitude.
2. **Pull state to workspace** — `just recall-eval-pull-state` copies the latest
   `alert-state.json` and `history.jsonl` tail to `~/.local/state/recall-eval/`.
3. **Triage by metric:**
   - `recall_unreachable` → `ssh homelab systemctl status hindsight.service hindsight-db.service`. Reranker cold-start or DB connect failure are the usual suspects. Check `journalctl -u hindsight.service --since "10 min ago"` and `podman logs hindsight`.
   - `p90_latency_ms` → likely reranker cold-start or CPU-only fallback. Cross-reference `docs/solutions/performance-issues/hindsight-recall-hook-silent-timeout-2026-04-21.md` §4 (timeout tuning) and §5 (reranker selection).
   - `recall@5 < 0.90` → a specific fixture missed. Open `history.jsonl` tail; look at the matching `dead_ids`. If the expected id was deleted (intentional), update `secrets/homelab/recall-eval-fixtures.yaml` and re-encrypt. If the rank dropped (still in corpus), investigate embedding/reranker drift.
   - `fixture_liveness` (warning) → an expected id no longer appears in any top-10. Fixture rot; replace or delete.
4. **After remediation**, run `just recall-eval-gate` to confirm green.
5. **After intentional change that legitimately drops the metric** (e.g., corpus purge), update fixtures + run `just recall-eval-ack` to clear the Claude hook surface.

## Fixture rotation

Fixtures live encrypted at `secrets/homelab/recall-eval-fixtures.yaml`
(sops binary format — whole-file encryption, not per-key).

Edit workflow:
```
sops decrypt --output /tmp/fx-plain.yaml --input-type binary --output-type binary secrets/homelab/recall-eval-fixtures.yaml
$EDITOR /tmp/fx-plain.yaml
sops encrypt --input-type binary --output-type binary --filename-override secrets/homelab/recall-eval-fixtures.yaml /tmp/fx-plain.yaml > secrets/homelab/recall-eval-fixtures.yaml
rm /tmp/fx-plain.yaml
```

**Version bump**: `FixtureSet.Version` in the YAML is a floor integer. Bump it
whenever `expected_memory_ids` semantics change. The `version_hash` in
history.jsonl is a content sha256 — changes automatically on any edit.

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `vendorHash` mismatch on build | `go.mod`/`go.sum` changed | replace `vendorHash` in `systems/homelab/recall-eval.nix` with the `got:` value from the error |
| `HINDSIGHT_API_TENANT_API_KEY not set` | sops.templates not mounted | `systemctl status recall-eval-gate.service` — check `EnvironmentFile=` line and `systemctl cat` for `%N` expansion |
| `fixtures.yaml: no such file or directory` | LoadCredential failed | `systemctl status recall-eval-gate.service`; sops secret may not be decrypted. Check `systemctl status sops-install-secrets.service` |
| alert fires but no Telegram | `TELEGRAM_BOT_TOKEN` / `TELEGRAM_CHAT_ID` empty in sops | `sops secrets/homelab/services.yaml` → set both |
| `recall_unreachable` persists after hindsight restart | dns/network inside container, not eval | tail `podman logs hindsight` for actual error |

## Security notes

- Fixture queries are **never** written to `history.jsonl` (bank content must stay in the bank).
- `StateDirectory=recall-eval` is mode 0700 — only recall-eval's DynamicUser reads it.
- Telegram bot token + chat id are loaded via `EnvironmentFile=` (sops.templates), never as cmdline args.

## Related

- `docs/solutions/performance-issues/hindsight-recall-hook-silent-timeout-2026-04-21.md` — the class of regression this eval is designed to catch.
- `docs/solutions/developer-experience/kbtool-go-migration-2026-04-22.md` — the Go-CLI doctrine this project follows.
