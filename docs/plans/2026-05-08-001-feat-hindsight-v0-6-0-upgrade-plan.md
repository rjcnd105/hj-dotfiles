---
title: feat: Upgrade homelab Hindsight to v0.6.0
type: feat
status: active
date: 2026-05-08
---

# feat: Upgrade homelab Hindsight to v0.6.0

## Summary

Upgrade the homelab Hindsight API image from `0.5.6-slim` to `0.6.0-slim`, keep the existing Podman/Quadlet host envelope intact, and verify the DB migration, recall path, worker queue, and Codex hook-facing recall behavior after deployment.

---

## Problem Frame

The current homelab Hindsight runtime is pinned to `ghcr.io/vectorize-io/hindsight:0.5.6-slim` in `systems/homelab/hindsight-stack.nix`. Upstream `v0.6.0` is a large release: 119 commits, 707 changed files, new Alembic migrations, DB backend abstraction, recall/retain fixes, and Codex/Claude integration changes. The update should therefore be treated as an operational service upgrade, not just a cosmetic tag bump.

---

## Assumptions

*This plan was authored from the user's direct request and local/upstream research without a separate confirmation round. Review these bets before implementation proceeds.*

- The intended update target is the homelab container image tag `0.6.0-slim`, not the local `hindsight` CLI/package installation.
- The existing Postgres-backed homelab topology should stay unchanged: Podman/Quadlet, host network, existing `hindsight-db` TimescaleDB container, and local embedding/reranker proxy endpoints.
- The first implementation pass should preserve existing Hindsight API environment values unless upstream documents a required rename or the rendered unit proves a conflict.

---

## Requirements

- R1. Homelab Hindsight API image pin moves from `0.5.6-slim` to `0.6.0-slim`.
- R2. Existing host-owned boundaries remain intact: secrets via `sops.templates."services.env"`, DB through `hindsight-db`, model calls through local `embed-prefix-proxy`/`llama-swap`, and public routing through Cloudflared.
- R3. The upgrade path accounts for v0.6.0 Alembic migrations, especially the new PostgreSQL migrations touching `memory_links` FKs and `entity_cooccurrences`.
- R4. Post-deploy verification proves more than `/health`: recall, retain/worker progress, and recall-eval behavior must be checked.
- R5. Accepted integration updates are kept separate from the homelab runtime boundary: Codex gets upstream recall timeout and synthetic AGENTS.md filtering; Claude gets native plugin update plus matching synthetic startup-message filtering.

---

## Scope Boundaries

- Do not update `flake.lock` or unrelated Nix inputs.
- Do not change the Hindsight DB image, volume bridge path, Cloudflared route, Caddy policy, or local model stack unless the v0.6.0 smoke test exposes a concrete incompatibility.
- Do not adopt Oracle backend support; the homelab remains PostgreSQL/TimescaleDB.
- Do not enable optional Claude MCP knowledge tools or `create-agent` behavior as part of the homelab image upgrade; those change agent UX and should remain explicitly opt-in.
- Do not enable registry auto-update for Hindsight; Hindsight owns schema migrations on startup.

### Deferred to Follow-Up Work

- Evaluate upstream Claude Code MCP knowledge tools and `create-agent` skill as a separate opt-in user-home integration change.
- Consider a small operator note after live deployment if v0.6.0 changes migration or worker behavior materially.

---

## Context & Research

### Relevant Code and Patterns

- `systems/homelab/hindsight-stack.nix` owns the Hindsight API image pin, non-secret environment values, Quadlet text, and restart-on-Quadlet-change activation.
- `systems/homelab/sops.nix` owns secret env rendering, including `HINDSIGHT_API_DATABASE_URL`.
- `systems/homelab/recall-eval.nix` and `systems/homelab/recall-eval/README.md` are the existing recall regression probe and operational triage surface.
- `docs/solutions/tooling-decisions/homelab-podman-quadlet-runtime-migration-2026-04-27.md` documents the current Podman/Quadlet boundary and generated-unit verification pattern.
- `docs/solutions/database-issues/hindsight-recall-eval-on-switch-db-waits-2026-04-27.md` documents prior Hindsight DB wait and worker queue risks; v0.6.0 contains fixes that directly touch memory link deadlocks and async retain behavior.

### Institutional Learnings

- Rendered Quadlet inspection is the right local verification for Hindsight image/env changes before live deployment.
- Mutable image refresh requires restarting the relevant Quadlet image/service path; do not rely on a no-op start of an already active unit.
- `/health` is too shallow for Hindsight upgrades; recall path and worker/DB queue behavior have failed while health was green.

### External References

- GitHub compare: https://github.com/vectorize-io/hindsight/compare/v0.5.6...v0.6.0
- v0.6.0 release: https://github.com/vectorize-io/hindsight/releases/tag/v0.6.0
- Upstream v0.6.0 configuration docs: https://github.com/vectorize-io/hindsight/blob/v0.6.0/hindsight-docs/versioned_docs/version-0.6/developer/configuration.md
- Upstream v0.6.0 Codex integration diff includes configurable `recallTimeout` and synthetic AGENTS.md filtering.

---

## Key Technical Decisions

- Minimal active diff first: update only the image pin in `systems/homelab/hindsight-stack.nix` unless verification exposes a required env or systemd ordering change. This preserves rollback clarity and keeps existing local model routing untouched.
- Keep `HINDSIGHT_API_LLM_MAX_RETRIES=3`: v0.6.0 defaults to `3`, and the current homelab setting already matches the prior retry-cost decision.
- Let Hindsight startup migrations run through the existing container lifecycle, then verify migration success from logs and API behavior. v0.6.0 keeps `HINDSIGHT_API_RUN_MIGRATIONS_ON_STARTUP=true` as the documented default.
- Treat recall-eval as the upgrade smoke, not just a separate monitoring service. v0.6.0 changes data integrity and recall-related internals enough that a green health endpoint is not sufficient.

---

## Open Questions

### Resolved During Planning

- Does `0.6.0-slim` exist in GHCR? Yes; the registry tag list includes `0.6.0-slim` and `0.6.0`.
- Are current env names obviously removed by v0.6.0? No. The v0.6.0 config still defines the current envs used here, including vector/text search extension, LLM provider/model, embeddings OpenAI base URL/model/key, reranker Cohere base URL/model/key, worker limits, recall budget, lazy reranker, host, port, and tenant extension.
- Is this a database-risking release? Yes. v0.6.0 adds PostgreSQL Alembic changes for `memory_links` deferrable FKs and `entity_cooccurrences` backfill, plus DB abstraction work for Oracle.

### Deferred to Implementation

- Exact live migration duration and whether any Alembic step locks long enough to affect interactive recall. This depends on homelab data size and must be observed during deploy.
- Whether Codex `recallTimeout` needs a value above the upstream default of 10 seconds. The config knob is now available, but the default should remain until live prompt-time recall latency proves otherwise.

---

## Implementation Units

### U1. Update the Hindsight Image Pin

**Goal:** Move the host-owned Hindsight API image to v0.6.0 while preserving the existing Quadlet envelope.

**Requirements:** R1, R2

**Dependencies:** None

**Files:**
- Modify: `systems/homelab/hindsight-stack.nix`
- Test expectation: none -- this is a Nix-generated runtime file change with verification through formatting and rendered output.

**Approach:**
- Change `images.hindsight` from `ghcr.io/vectorize-io/hindsight:0.5.6-slim` to `ghcr.io/vectorize-io/hindsight:0.6.0-slim`.
- Leave existing environment values unchanged on the first pass.
- Do not touch `images.db`, volume paths, `Network=host`, or systemd dependencies.

**Patterns to follow:**
- Existing `images = { ... };` attrset in `systems/homelab/hindsight-stack.nix`.
- Rendered-unit verification pattern from `docs/solutions/tooling-decisions/homelab-podman-quadlet-runtime-migration-2026-04-27.md`.

**Test scenarios:**
- Happy path: rendered `hindsight.container` contains `Image=ghcr.io/vectorize-io/hindsight:0.6.0-slim`.
- Regression: rendered unit still contains existing local embedding and reranker proxy env values.
- Regression: rendered unit still uses `Network=host` and `EnvironmentFile` from the sops-rendered services env.

**Verification:**
- Nix formatting succeeds.
- Nix eval of the rendered Quadlet text shows the new image and unchanged critical env/network values.

---

### U2. Run Local Nix Verification

**Goal:** Prove the Nix change is valid before any homelab deploy path consumes it.

**Requirements:** R1, R2

**Dependencies:** U1

**Files:**
- Test expectation: none -- verification uses existing flake checks and eval surfaces.

**Approach:**
- Run the repo's normal formatting/check path for Nix changes.
- Evaluate the generated `environment.etc."containers/systemd/hindsight.container".text` output directly.
- Keep unrelated dirty user changes untouched.

**Patterns to follow:**
- `rules/README.md` baseline verification.
- `rules/nixos-modules.md` generated-file workflow.

**Test scenarios:**
- Happy path: formatting reports no changes or only expected formatting.
- Happy path: flake check or `just check` completes without introducing unrelated lockfile movement.
- Error path: if flake evaluation fails outside the touched Hindsight module, report the unrelated failure separately and do not mask it as an upgrade failure.

**Verification:**
- Local checks complete or the exact blocker is reported with scope.

---

### U3. Deploy and Observe Migration Behavior

**Goal:** Apply the upgraded image through the existing homelab path and confirm v0.6.0 migrations complete without leaving the service in a degraded state.

**Requirements:** R2, R3, R4

**Dependencies:** U1, U2

**Files:**
- Test expectation: none -- this is operational verification against live homelab state.

**Approach:**
- Let the existing `hindsightQuadletRefresh` activation restart the service when the generated Quadlet changes.
- Watch Hindsight logs around startup for migration execution, database connection, and provider initialization.
- Confirm that v0.6.0 does not regress the prior DB wait/worker queue class.

**Patterns to follow:**
- Hindsight service triage in `docs/solutions/database-issues/hindsight-recall-eval-on-switch-db-waits-2026-04-27.md`.
- Quadlet restart behavior in `systems/homelab/hindsight-stack.nix`.

**Test scenarios:**
- Happy path: `hindsight.service` restarts on the new generated unit and starts with the v0.6.0 image.
- Happy path: startup migration logs finish without an Alembic or DB lock failure.
- Error path: migration failure leaves the old Nix generation rollback path available; collect logs before attempting further config edits.
- Error path: long DB waits or pending worker backlog after startup trigger DB/worker inspection before changing concurrency knobs.

**Verification:**
- Live service reports healthy API and database state.
- Logs show no migration failure, repeated restart loop, or sustained worker/pool waiters after the service settles.

---

### U4. Run Hindsight Functional Smoke

**Goal:** Verify the upgraded service through the surfaces that matter to daily use: recall, retain/worker progress, and recall-eval.

**Requirements:** R4

**Dependencies:** U3

**Files:**
- Test expectation: none -- existing recall-eval code is reused unchanged.

**Approach:**
- Check `/health` only as a first gate.
- Exercise a small recall request against the normal bank and tenant path.
- Trigger or inspect `recall-eval-on-switch` so the existing fixture-based regression probe covers the upgraded service.
- Inspect logs for provider response hardening, local reranker calls, DB waits, and worker queue progress.

**Patterns to follow:**
- `systems/homelab/recall-eval/README.md` for recall alert triage.
- Prior recall timeout and DB wait solution docs under `docs/solutions/performance-issues/` and `docs/solutions/database-issues/`.

**Test scenarios:**
- Happy path: `/health` returns healthy and a representative recall returns non-empty results within the expected latency band.
- Integration: recall-eval records a non-unreachable run and does not show the previous `hindsight unreachable` class.
- Error path: `/health` succeeds but recall times out; investigate Hindsight logs and DB/worker queue before touching model proxy flags.
- Error path: retain or batch retain tasks remain pending without claimable progress; inspect worker slot and payload breakdown before increasing concurrency.

**Verification:**
- The service is usable from the actual recall path, not just alive.
- Any degradation is tied to a concrete failing surface and documented before rollback or tuning.

---

### U5. Apply Accepted Integration Updates

**Goal:** Update the accepted Codex and Claude Hindsight integration surfaces without enabling optional MCP knowledge tools.

**Requirements:** R5

**Dependencies:** U1

**Files:**
- Modify: `files/workspace/.hindsight/codex/scripts/recall.py`
- Modify: `files/workspace/.hindsight/codex/scripts/lib/config.py`
- Add/modify: `files/workspace/.hindsight/codex/scripts/lib/content.py`
- Modify active Claude plugin cache after native plugin update.
- Test expectation: Python syntax and transcript filtering smoke tests.

**Approach:**
- Add upstream Codex `recallTimeout` support while preserving the local short-prompt recall skip behavior.
- Add upstream-style Codex synthetic AGENTS.md filtering to text and rich transcript readers.
- Update Claude Hindsight plugin with `claude plugin update hindsight-memory@hindsight`, then add matching synthetic startup-message filtering to its active content processor.
- Keep Claude Code MCP knowledge tools disabled unless explicitly enabled later; they affect agent integration UX, not the server image pin.
- Ignore Oracle, n8n, Dify, AgentCore, SmolAgents, and TypeScript client updates unless the user has a concrete use case.

**Patterns to follow:**
- Project-local Hindsight bank boundary in `mise.toml`.
- Memory note that active Hindsight integration files may live under `~/.hindsight`, while repo-managed mirrors may not be active runtime truth.

**Test scenarios:**
- Happy path: synthetic `# AGENTS.md instructions for ... <INSTRUCTIONS>...</INSTRUCTIONS>` user messages are skipped in Codex text/rich readers and Claude retention formatting.
- Regression: normal user prompts still pass through the readers and retention formatter.
- Recommendation: if prompt-time recall regularly approaches 10 seconds on v0.6.0, set an explicit `recallTimeout` above the default and verify the hook still degrades gracefully.
- Non-goal: do not install framework integrations only because they exist in v0.6.0.

**Verification:**
- Python syntax checks pass for the changed integration files.
- Synthetic filtering smoke test passes for repo Codex content, active Codex content, and active Claude plugin content.

---

## System-Wide Impact

- **Interaction graph:** `hindsight.service` depends on `hindsight-db.service`, `hindsight-db-settings.service`, `llama-swap.service`, and `embed-prefix-proxy.service`. The upgrade should not change that ordering.
- **Error propagation:** Startup migration failures should surface in `hindsight.service` logs and systemd restart behavior; recall path failures may surface only through recall-eval or API request logs.
- **State lifecycle risks:** v0.6.0 migrations can touch existing data and constraints; successful `/health` does not prove migrations or recall query paths are safe under load.
- **API surface parity:** The public route remains `hindsight.deopjib.site` through Cloudflared; client/hook configs should not need URL changes.
- **Integration coverage:** Recall-eval and a direct recall smoke are required because v0.6.0 touches both data integrity and retrieval behavior.
- **Unchanged invariants:** Secrets stay out of Nix literals; Hindsight remains host-networked; local embedding and reranker proxy endpoints stay on `127.0.0.1:8091`.

---

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| Alembic migration locks or fails on existing homelab data | Deploy with log observation, keep rollback path, and inspect DB/worker state before further tuning |
| Health endpoint is green while recall is broken | Run direct recall and recall-eval smoke as release gates |
| Optional v0.6.0 integrations expand scope | Apply only accepted Codex/Claude filtering and timeout support; keep Claude MCP knowledge tools opt-in |
| Local macOS Podman cannot inspect GHCR images | Use registry tag API or homelab-side runtime verification instead of relying on the local stopped Podman machine |

---

## Documentation / Operational Notes

- The most valuable immediate suggestions from v0.6.0 are:
  - configurable Codex recall timeout via `HINDSIGHT_RECALL_TIMEOUT` / `recallTimeout` (implemented with upstream default 10s);
  - filtering synthetic Codex AGENTS.md startup messages from retention (implemented);
  - mirroring the same conservative startup-message filter in the active Claude plugin content processor (implemented locally on top of the native plugin update);
  - new Claude Code MCP knowledge tools and create-agent skill, worth evaluating separately;
  - DB/retain fixes around async batch retain, memory link deadlocks, and provider response hardening, which are good reasons to upgrade but need live smoke.
- Oracle backend, n8n, Dify, AgentCore, SmolAgents, and client SDK updates are not directly relevant to this homelab runtime unless a separate workflow adopts them.

---

## Sources & References

- Related code: `systems/homelab/hindsight-stack.nix`
- Related guide: `docs/guides/homelab-image-deploy-guide.md`
- Related solution: `docs/solutions/tooling-decisions/homelab-podman-quadlet-runtime-migration-2026-04-27.md`
- Related solution: `docs/solutions/database-issues/hindsight-recall-eval-on-switch-db-waits-2026-04-27.md`
- External compare: https://github.com/vectorize-io/hindsight/compare/v0.5.6...v0.6.0
- External release: https://github.com/vectorize-io/hindsight/releases/tag/v0.6.0
