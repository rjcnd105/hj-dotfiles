---
title: "feat: homelab app release automation substrate"
type: feat
status: superseded
date: 2026-04-30
superseded_by: ../solutions/architecture-patterns/homelab-app-contract-generic-deploy-runner-2026-05-06.md
---

# feat: homelab app release automation substrate

> Superseded on 2026-07-20. The current release ABI and host transaction are
> documented in `../solutions/architecture-patterns/homelab-app-contract-generic-deploy-runner-2026-05-06.md`.

## Summary

Add a small, generic release automation layer for admitted homelab apps without
moving app release ownership into `nix-dots`.

The durable split stays:

- App repos own PR flow, CI, SemVer or release-note decisions, OCI image builds,
  immutable image tags, and channel pointer tags.
- `nix-dots` owns host admission, secrets, volumes, public ingress, runtime
  policy, local deploy orchestration, smoke checks, and future renderer choice.

This is not the time to introduce k3s solely to make one-command deploys feel
more self-service. The near-term target is a host-local `homelab-appctl` command
driven by generated app metadata. Later, the same app contract should map to
k3s and Flux image automation when app count and rollout complexity justify the
extra control plane.

## Review Tier

Deep. This plan touches deployment orchestration, migrations, registry auth,
public routing, and future Kubernetes migration boundaries. The review is
included at the end of this document and its critical findings are already
reflected in the plan.

## Problem Frame

The current repo can admit app-owned runtime contracts and render Podman/Quadlet,
Caddy, Cloudflared, sops templates, and activation refresh logic. That solves
"how does this homelab run an app?" It does not yet solve "how do all admitted
apps get a predictable release workflow?"

The user wants a convenient release path where, especially for `dev`, one
command can trigger the app-side release workflow and the homelab can consume the
new image without hand-editing `nix-dots` every time.

The risky part is responsibility creep. If `nix-dots` starts deciding SemVer,
parsing app commits, or hand-coding app release details, it becomes a central
release platform and makes the later k3s migration messier. If app repos get
broad SSH or webhook access to the host, the security boundary becomes too wide.

## Current Repo Baseline

- `systems/homelab/app-containers.nix` already defines `homelab.apps` and
  renders app contracts to Quadlet `.image`, `.container`, `.network`, and
  `.volume` files.
- It routes admitted apps through Caddy and Cloudflared, binding service ports to
  loopback instead of exposing containers directly.
- It generates sops-backed env templates from `requiredSecretEnv` and
  `host.secretMap`.
- It validates migration safety enough to reject `registry-auto` on the service
  named by `migrations.service`.
- It does not render migration one-shot units.
- It does not expose a generic deploy/status/smoke command for admitted apps.
- `docs/guides/homelab-image-deploy-guide.md` already establishes the current
  boundary: app repo owns runtime contract and admission request; `nix-dots`
  owns host binding and runtime substrate.

## Requirements

- R1. Routine app releases after admission must not require a NixOS rebuild or a
  `nix-dots` edit.
- R2. Release automation must be generic over `homelab.apps`, not hard-coded for
  Deopjib or any single app.
- R3. App repos own versioning, changelog, PR, CI, and image publication.
  `nix-dots` only consumes declared images and deploy channels.
- R4. Dev can support low-friction deploys; prod must remain explicit and
  approval-oriented.
- R5. DB-backed or migration-owning services must not rely on blind registry
  auto-update.
- R6. No broad SSH keys, broad webhooks, plaintext registry credentials, or app
  repo write access to host configuration.
- R7. The host deploy surface must be inspectable from generated files and
  testable with Nix evaluation.
- R8. The app contract must remain close to Kubernetes primitives so that a later
  k3s/Flux renderer can replace the Podman renderer without redesigning each
  app.

## Non-Goals

- Do not introduce k3s in this phase.
- Do not build a central app catalog repository.
- Do not make `nix-dots` infer SemVer from app commits.
- Do not use an LLM as the sole authority for version bumps or release safety.
- Do not add remote CI-to-host deploy credentials in the first pass.
- Do not promise robust rollback until the image and migration model can prove
  it.

## Target Model

App repo flow:

1. Developer runs one app-owned command, for example
   `mise run deopjib:release-dev --minor`.
2. The app repo opens or updates a PR, runs CI, decides version or release notes,
   builds OCI images, and publishes immutable tags.
3. The app repo moves a channel pointer tag such as `:dev-current` only after CI
   passes.

This command is the release start button. It should not SSH into homelab or run
app-specific host deploy logic.

Homelab flow:

1. `nix-dots` has already admitted the app through `homelab.apps.<key>`.
2. A host-local command reads generated metadata for the admitted app.
3. The command surface is:
   - `homelab-appctl deploy deopjib dev`
   - `homelab-appctl smoke deopjib dev`
   - `homelab-appctl rollback deopjib dev`
4. Deploy pulls and resolves image digests, runs a migration unit only when the
   contract says migrations are manual and the operator requested deploy,
   restarts app units in a deterministic order, runs smoke checks through Caddy,
   and reports the result.
5. Rollback is a host responsibility. In v1 it is record-backed and conservative;
   stronger automatic rollback is added only after the exact image restore path is
   proven on homelab.

Future k3s flow:

1. The same app contract becomes Kubernetes manifests, Helm values, or Flux
   allowlisted app paths.
2. Image automation moves from Podman/Quadlet pull/restart to Flux/Renovate or a
   Kubernetes image updater.
3. Secrets, ingress, and storage policy remain cluster-owned rather than app
   repo-owned.

## Ownership Boundary

| Concern | Owner | Notes |
|---|---|---|
| PR creation, CI, SemVer, release notes | app repo | Use Release Please, Semantic Release, custom CI, or a simpler app-local policy. |
| OCI image build and tag publication | app repo | Publish immutable SHA tags; pointer tags are deploy channels. |
| App runtime contract | app repo | `devops/runtime-contract.nix` remains source of app intent. |
| Admission and public hostname | `nix-dots` | Host still decides what is allowed to run and be exposed. |
| Registry credentials | `nix-dots` / host operator | sops-backed auth files only. |
| Deploy orchestration | `nix-dots` | Generic, metadata-driven host command. |
| Migration execution | `nix-dots` command using app contract | Never implicit for migration-owning services. |
| OCI release manifest | app repo, optional | Provenance or audit artifact only; not the homelab deploy ABI. |
| Kubernetes migration | `nix-dots` | Replace renderer later, not the app contract. |

## Contract Extension

Add an optional `release` block to the app-owned runtime contract. Keep it small
and declarative. It describes deploy channel policy, not app release mechanics.

```nix
release = {
  versioning = "external";

  channels.dev = {
    tag = "dev-current";
    mode = "manual";
    strategy = "coordinated";
    smokePaths = [
      "/health"
      "/"
    ];
    migrate = "manual";
    rollback = "record-only";
  };

  channels.prod = {
    tag = "prod-current";
    mode = "approved";
    strategy = "coordinated";
    smokePaths = [
      "/health"
      "/"
    ];
    migrate = "manual";
    rollback = "record-only";
  };
}
```

Field intent:

| Field | Meaning |
|---|---|
| `versioning = "external"` | `nix-dots` does not decide SemVer. |
| `channels.<name>.tag` | Human channel label expected in image refs or app CI. |
| `mode` | `manual`, `auto`, or `approved`. Start with `manual` support only. |
| `strategy` | `coordinated` means pull all service images before restart. |
| `smokePaths` | Paths checked through the host route after deploy. |
| `migrate` | `none` or `manual` in v1. |
| `rollback` | `record-only` in v1; stronger rollback is future work. |

Do not make this a general workflow language. If a field is not needed by the
host runtime, it belongs in the app repo's CI config instead.

## Nix-Dots Implementation Units

### U1. Add release schema and assertions

**Goal:** Extend `homelab.apps.<key>.contract` with optional release channel
metadata while preserving existing app contracts.

**Files:**

- Modify: `systems/homelab/app-containers.nix`
- Modify: `docs/guides/homelab-image-deploy-guide.md`

**Approach:**

- Default `contract.release = { versioning = "external"; channels = { }; }`.
- Assert `versioning == "external"` in this phase.
- Assert release channel names are valid ids.
- Assert `migrate = "manual"` only when `contract.migrations.mode == "manual"`.
- Assert `smokePaths` are absolute paths.
- Do not add auto remote deploy behavior in this unit.

**Verification:**

- Existing Deopjib admission still evaluates without adding a release block.
- A synthetic app with a `release.channels.dev` block evaluates.
- Invalid channel names or migration policy fail Nix evaluation clearly.

### U2. Generate app metadata for host commands

**Goal:** Produce a stable machine-readable summary for every enabled admitted
app so deploy tools do not scrape systemd or reimplement Nix logic.

**Files:**

- Modify: `systems/homelab/app-containers.nix`

**Approach:**

- Render one JSON file per logical app/channel under
  `/etc/homelab-apps/<app>/<channel>.json`.
- Include app key, app name, channel, domain, caddy loopback URL, service unit
  names, image refs, image unit names, migration unit name if present, smoke
  paths, update policies, and release channel metadata.
- Prefer generated metadata over shell-time discovery.

**Verification:**

- `nix eval --json` can inspect the generated JSON text.
- Metadata for services matches generated Quadlet unit names.
- Metadata contains no secret values.

### U3. Render manual migration one-shot units

**Goal:** Make declared manual migrations executable by the host without
embedding app-specific commands in `nix-dots`.

**Files:**

- Modify: `systems/homelab/app-containers.nix`

**Approach:**

- When `contract.migrations.mode == "manual"`, render a one-shot systemd unit
  such as `<app>-<channel>-migrate.service`.
- Use the migration service image, network, env template, registry auth, and
  volumes from the referenced service.
- Run the exact argv from `contract.migrations.command`.
- Do not attach the migration unit to `multi-user.target`.
- Do not run migrations during NixOS activation.

**Verification:**

- Synthetic migration app renders the migration unit.
- App with `migrations.mode = "none"` renders no migration unit.
- The migration unit is not auto-started by systemd install targets.

### U4. Add `homelab-appctl`

**Goal:** Provide one host-local command for admitted app status, smoke checks,
and manual deploy orchestration.

**Files:**

- Modify: `systems/homelab/app-containers.nix`
- Optionally create: `systems/homelab/appctl.nix` if the script becomes large
  enough to deserve a separate module.

**Commands:**

```sh
homelab-appctl list
homelab-appctl status <app> <channel>
homelab-appctl smoke <app> <channel>
homelab-appctl deploy <app> <channel> --dry-run
homelab-appctl deploy <app> <channel>
homelab-appctl rollback <app> <channel>
homelab-appctl logs <app> <channel>
```

**Approach:**

- Implement as a small shell script packaged by Nix.
- Read `/etc/homelab-apps/<app>/<channel>.json`.
- For `status`, show systemd status for generated service units.
- For `smoke`, curl the configured smoke paths through the Caddy loopback URL
  with the app host header.
- For `deploy --dry-run`, print planned image pulls, migration unit, restarts,
  and smoke checks without changing state.
- For `deploy`, resolve or record image digests, pull image units first, run the
  migration unit when requested by metadata, restart app container units, then
  run smoke checks.
- For `rollback`, use the latest deploy record for that app/channel. In v1 this
  may be limited to clearly reporting the previous image IDs and required manual
  recovery command if automatic image restore is not yet proven.
- Keep root/systemd privileges explicit. Do not hide permission failures.

**Verification:**

- `homelab-appctl list` works from generated metadata.
- `homelab-appctl deploy <app> <channel> --dry-run` does not mutate state.
- `homelab-appctl smoke <app> <channel>` uses loopback Caddy, not direct
  container ports.
- `homelab-appctl rollback <app> <channel>` has a defined v1 behavior even when
  automatic restore is not yet enabled.

### U5. Record deploy state and provide rollback surface

**Goal:** Make deploy provenance visible and prepare for rollback without
claiming more than the current Podman/tag model can safely guarantee.

**Files:**

- Modify: `systems/homelab/app-containers.nix`
- Modify or create appctl script from U4

**Approach:**

- Store deploy records under `/var/lib/homelab-appctl/<app>/<channel>/`.
- Record timestamp, app metadata hash, service image refs before deploy, pulled
  image IDs or digests when available, restart result, migration result, and
  smoke result.
- In v1, set `rollback = "record-only"` by default and provide a required
  `homelab-appctl rollback <app> <channel>` command.
- If exact image restoration is not proven for the current app/channel, rollback
  must fail closed with the deploy record path and the manual recovery command
  rather than pretending recovery happened.
- Add an automatic rollback command only after the exact image-id restore path is
  proven on homelab.

**Verification:**

- A dry run writes nothing.
- A successful deploy writes a record without secrets.
- A failed smoke check reports the record path and failed command.
- Rollback never uses app-specific scripts from app repos.

### U6. Update agent and app repo guidance

**Goal:** Make the workflow efficient for agents without copy-paste handoffs.

**Files:**

- Modify: `docs/guides/homelab-image-deploy-guide.md`
- Optionally modify: `AGENTS.md` if a short stable rule is useful there.

**Approach:**

- Add a "Release Automation" section to the guide.
- Tell app agents to implement app-side `mise run <app>:release-dev --minor` or
  equivalent in the app repo, not in `nix-dots`.
- Tell `nix-dots` agents to admit app contracts and verify generated metadata,
  not infer app release details.
- Document that v1 remote deploy trigger is intentionally absent.

**Verification:**

- A new app agent can tell what to put in app CI.
- A `nix-dots` agent can tell what host binding and app metadata to expect.
- The guide distinguishes admission-time Nix changes from routine image deploys.

## App Repo Work This Plan Assumes

This repo should not do the following work for every app, but the guide should
state that each app repo needs it:

- A release command, for example `mise run deopjib:release-dev --minor`.
- A CI workflow that builds and tests images.
- An immutable image tag per commit or release.
- A channel pointer tag such as `dev-current`.
- Optional Release Please or Semantic Release if the app wants automated SemVer.
- Optional LLM-assisted release notes or risk summaries, with CI/test results as
  the authority.
- Optional OCI release manifest for provenance or audit only. Homelab deployment
  must consume the app contract and registry images, not an app-specific release
  manifest ABI.

OpenRouter or another LLM can be useful for summarizing changes and suggesting a
version bump, but the final release decision should be encoded in app CI policy
and visible in PR/release artifacts.

## k3s Migration Guardrails

This plan deliberately keeps the host deploy model Kubernetes-mappable:

| Current field or artifact | k3s/Flux later |
|---|---|
| app contract service | `Deployment` container plus `Service` |
| `requiredSecretEnv` and `secretMap` | `Secret` references and cluster secret policy |
| app routes | `Ingress`, Gateway API route, or Cloudflared ingress controller policy |
| manual migration unit | `Job` or Helm hook with explicit approval |
| `homelab-appctl deploy` | Flux image automation or `kubectl rollout` wrapper |
| deploy record | Kubernetes events, Flux history, and image digest history |

Introduce k3s only when one of these is true:

- There are enough admitted apps that per-app systemd orchestration becomes
  repetitive and limiting.
- Apps need Kubernetes-native rollout, readiness, service discovery, or Jobs.
- Flux/Renovate image automation is worth operating as a control loop.
- Third-party services arrive as Helm charts or Kubernetes operators.

## Validation Plan

Local validation:

```sh
nix flake check --all-systems --no-build
nix eval --json '.#nixosConfigurations.homelab_hj.config.environment.etc'
```

Synthetic eval cases:

- App with no release block remains valid.
- App with `release.channels.dev` metadata is rendered.
- App with no migrations renders no migration unit.
- App with manual migrations renders a one-shot migration unit.
- App with `registry-auto` on migration service still fails evaluation.

Homelab validation after deployment:

```sh
homelab-appctl list
homelab-appctl status deopjib dev
homelab-appctl smoke deopjib dev
homelab-appctl deploy deopjib dev --dry-run
homelab-appctl rollback deopjib dev
```

Do not run a live deploy automatically as part of repo evaluation. Live deploy is
an operator action on the host.

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---:|---:|---|
| `nix-dots` becomes a release platform | Medium | High | Keep SemVer, PR, CI, and image publication in app repos. |
| Migration unit causes data damage | Low | High | Render only manual one-shot units; never auto-run on switch. |
| Pointer tag rollback is unreliable | Medium | Medium | v1 provides a rollback command but fails closed unless image restore is proven. |
| Remote CI trigger becomes a broad host credential | Medium | High | Defer remote triggers; start with host-local command. |
| Metadata drifts from rendered units | Low | Medium | Generate metadata from the same Nix values as Quadlet units. |
| k3s migration still needs manual work | Medium | Medium | Keep contract fields Kubernetes-shaped and document the mapping. |

## Alternatives Considered

- Move directly to k3s now: rejected for v1 because the current problem is
  release orchestration, not a need for Kubernetes controllers.
- Use Podman `registry-auto` for every dev service: rejected because migration
  services and stateful apps need coordinated pull, migration, restart, and
  smoke checks.
- Add app repo webhooks or SSH deploy keys now: rejected because it widens the
  host trust boundary before the local deploy command is proven.
- Build a central app catalog repo: rejected because current per-app admission is
  already clear enough and avoids another source of truth.
- Let `nix-dots` decide versions with an LLM: rejected because app CI is the
  correct authority for versioning and release quality.

## Phased Delivery

### Phase 1: Metadata and docs

- Add optional release schema.
- Generate `/etc/homelab-apps/<app>/<channel>.json`.
- Update the homelab image deploy guide.

### Phase 2: Host-local operations

- Add `homelab-appctl list/status/smoke/rollback`.
- Add dry-run deploy planning.

### Phase 3: Manual deploy and migrations

- Render manual migration one-shot units.
- Add coordinated pull, migrate, restart, smoke deploy flow.
- Record deploy state.

### Phase 4: Remote trigger review

- Reassess after host-local deploy has been used successfully.
- If needed, add a narrow pull-based trigger, not broad app repo SSH access.

### Phase 5: k3s trigger review

- Reassess when app count or rollout needs meet the k3s trigger.
- Start with Nix-managed k3s manifests before adding Flux.
- Add Flux/Renovate image automation only when the Kubernetes control loop is
  already justified.

## Review Notes

**Inline review:**

Deep review found three critical risks and the plan has been adjusted for them:

1. Remote app CI triggers are security-sensitive, so v1 now uses a host-local
   `homelab-appctl` command and explicitly defers remote triggers.
2. Rollback through mutable pointer tags is not reliable enough to promise, so
   v1 includes a rollback command but keeps automatic restore conservative until
   the exact image-id path is proven.
3. Migrations are data-risky, so v1 renders manual one-shot units but never runs
   them during NixOS activation or by background registry auto-update.

**Failure post-mortem:**

The likely failure mode is that the release command becomes a hidden mini
platform: app CI, host deploy, rollback, and migration semantics all blur
together. The early warning sign would be app-specific conditionals appearing in
`nix-dots` or app repos requesting broad host credentials. The plan counters
this by generating metadata from admitted contracts and keeping app release
logic outside `nix-dots`.

**Over-engineering post-mortem:**

The likely overbuild is implementing k3s, remote webhooks, automatic rollback,
and LLM versioning before the host has a boring local deploy command. The plan
now sequences those as later reviews and starts with metadata, smoke checks, and
dry-run deploys.

**Unstated assumptions made explicit:**

1. App repos can publish reliable channel tags. If this is false, app CI must be
   fixed before host automation helps.
2. Host-local operator commands are acceptable for v1. If this is false, remote
   trigger design becomes a separate security plan.
3. Manual migrations are rare enough to gate explicitly. If this is false, the
   app probably needs k3s Jobs or a stronger migration controller sooner.
4. Generated JSON metadata is enough for appctl. If this is false, the appctl
   design should move to a typed Nix-generated executable rather than shell
   discovery.

**Autonomy check:**

No user stop is required before Phase 1 implementation. The only justified
future decision is whether and when to allow remote CI-to-host deploy triggers,
because that changes credential and threat boundaries.

**Open questions:**

1. Which app should be the first non-Deopjib consumer of this flow?
2. Should `prod` ever accept channel pointer tags, or require immutable digests?
3. After v1, is a narrow remote trigger still desired, or is host-local/pull-based
   operation enough?

**Conditions for rejected alternatives:**

1. Direct k3s would be correct if multiple apps already required Kubernetes
   Jobs, probes, service discovery, or Flux automation. Plausibility: Medium.
2. Registry auto-update everywhere would be correct if all admitted apps were
   stateless and migration-free. Plausibility: Low.
3. A remote webhook would be correct if host-local deploys become the main
   bottleneck and a narrow forced-command credential is designed. Plausibility:
   Medium.
4. A central app catalog would be correct if app admissions become too numerous
   for per-app flake inputs and host bindings. Plausibility: Low for now.

**Red team:**

This plan still depends on app repos publishing sane tags. If an app CI pipeline
moves `dev-current` before images are tested, `homelab-appctl` will faithfully
deploy bad input. The host cannot fix a broken upstream release discipline. The
countermeasure is to keep image publication policy in the app repo guide and
make smoke checks fail loudly rather than silently treating deployment as a CI
success.

**Review summary:**

- Confidence: Medium-high.
- Critical issues addressed: remote trigger credentials deferred; rollback
  command defined with record-only default; migrations kept manual and never
  activation-driven.
- Worth considering later: narrow remote trigger, automatic rollback, and k3s
  renderer once host-local appctl proves insufficient.
- Acceptable gaps: first non-Deopjib consumer is not chosen yet; prod digest
  policy can be decided before prod admission.

**Review confidence:** Medium-high. The boundary is clear and the first phases
are small. The main uncertainty is how much remote triggering the user will want
after host-local deploys are working.

## Decision Brief

**Recommendation:**
Build a generic host-local release substrate in `nix-dots`: generated app
metadata, `homelab-appctl`, manual migration units, dry-run deploys, smoke
checks, rollback surface, and deploy records. Keep app CI and versioning in app
repos, and defer remote triggers plus k3s until the local workflow proves
insufficient.

- **Effort:** Large (half day+)
- **Risk:** Medium. Migration execution and rollback semantics are the hard
  parts, so v1 makes both explicit and conservative.
- **If we skip this:** Each admitted app can run, but release operations stay
  ad hoc and agents will keep rediscovering how to pull, restart, migrate, and
  smoke-check apps.
- **Reversible?** Mostly. Metadata and appctl can be removed without changing
  app contracts; migration units and deploy records are additive.

**Actions:**

1. Extend `systems/homelab/app-containers.nix` with optional release schema and
   generated `/etc/homelab-apps/<app>/<channel>.json`.
2. Add `homelab-appctl list/status/smoke/rollback` and dry-run deploy.
3. Render manual migration one-shot units from `contract.migrations`.
4. Add coordinated deploy and deploy records.
5. Update `docs/guides/homelab-image-deploy-guide.md` with release automation
   guidance for agents and app repos.

**Needs your input:**

- Approve whether the first implementation should stop at Phase 1-2
  metadata/status/smoke/dry-run, or include Phase 3 live deploy/migration in the
  same pass.

**Prompts used:**

- "내 앱에서도 작성했는데, homelab에 배포되는 모든 앱들에 대해서 나는 릴리즈를 자동화하고 싶어..."
- "그래 그렇게 하려고 할때 이 레포에서는 할 게 없어?"
- "해당하는 작업 $compound-engineering:ce-plan 이후 $compound-engineering:ce-doc-review"
