# Homelab Image Deploy Guide

Audience: agents and operators changing an app repository or its NixOS homelab
admission.

## Decision

Each app repository owns its release artifacts and runtime intent. `nix-dots`
owns whether and how that intent is admitted to the homelab.

```text
app repo
  runtime-contract.nix + homelab-admission.nix
  release manifest + exact OCI image digests
                |
                v
nix-dots flake input (pinned app revision)
  typed admission + assertions
  sops/network/storage/Caddy/Quadlet/systemd
                |
                v
homelab-appctl deploy --target <release-id>
  validate -> exact pull/tag -> migrate -> one restart -> smoke -> record
```

This is intentionally smaller than Kubernetes, Nomad, or a separate app
catalog. Revisit a controller only when several apps need continuous
reconciliation, rollout strategies, or shared cluster primitives that are
simpler than this host-local path.

## Ownership

| Concern | Authority |
|---|---|
| App version and release target | app repository |
| Backend/web image build and release manifest | app repository |
| Runtime services, dependencies, readiness, routes, and migrations | app-owned `devops/runtime-contract.nix` |
| Proposed homelab binding | app-owned `devops/homelab-admission.nix` |
| Admission and pinned app revision | `nix-dots` |
| Secret values | sops-backed host configuration |
| Network, storage, Caddy, Cloudflared, Quadlet, systemd | `nix-dots` |
| Exact host activation and deploy records | `homelab-appctl` |

Do not copy an app's service graph into `systems/homelab/default.nix`. Import
the app-owned admission through `systems/homelab/app-admissions.nix`, then let
the typed `homelab.apps` module render it.

## App Contract

`devops/runtime-contract.nix` must be pure Nix data. It may be a function of
admission parameters such as `channel` and `domain`, but must not import
`nixpkgs`, read secrets, perform I/O, or contain host activation logic.

The current typed contract supports:

- `images`: fully qualified OCI references;
- `services`: image key, internal port, env, required secret names, update
  policy, mounts, `dependsOn`, optional HTTP health path, and optional native
  container readiness command;
- `routes`: domain/path/service mapping;
- `migrations`: `none` or a manual one-shot command;
- `release`: external versioning, HTTPS manifest URL containing `{target}`, and
  channel tag/mode/target-pattern/strategy/smoke/migration policy;
- `volumes`: stable logical volume requests.

Update policies have distinct meanings:

| Policy | Use |
|---|---|
| `manual` | Release-coordinated app services. The manifest supplies the exact digest. |
| `pinned-digest` | Independently pinned infrastructure images such as PostgreSQL. |
| `registry-auto` | Stateless services with explicitly safe independent updates only. |

A `manual` service image must end in the admitted channel tag, for example
`:dev-current`. That tag is a local activation pointer, not the release
authority. The host pulls `name@sha256:...` from the release manifest and tags
that exact image locally before restarting the service.

A `pinned-digest` image must end in `@sha256:<64 lowercase hex>`. It remains a
normal declarative Quadlet image unit and does not participate in an app
release transaction.

Example release section:

```nix
release = {
  versioning = "external";
  manifestUrl = "https://github.com/example/my-app/releases/download/{target}/release.json";
  channels.${channel} = {
    tag = "${channel}-current";
    mode = if channel == "prod" then "approved" else "auto";
    targetPattern = if channel == "prod" then "^my-app-v[0-9]+\\.[0-9]+\\.[0-9]+$" else "^my-app-v.*$";
    strategy = "coordinated";
    smokePaths = [
      "/health"
      "/"
    ];
    migrate = "manual";
  };
};
```

## Admission

`devops/homelab-admission.nix` proposes a host binding:

```nix
let
  runtimeContract = ./runtime-contract.nix;
in
{
  key = "my-app";
  app = {
    enable = true;
    contract = import runtimeContract {
      channel = "dev";
      domain = "dev.my-app.example";
    };
    host = {
      domain = "dev.my-app.example";
      loopbackPortBase = 18100;
      secretMap.DATABASE_URL = "MY_APP_DATABASE_URL";
      volumes.db-data.backup = true;
    };
  };
}
```

The app file contains only secret names. Actual values remain in sops files and
render to `/run/secrets/...` on the host. Public container ports bind to
loopback; ingress remains Caddy plus Cloudflared.

`nix-dots` imports the proposal from its pinned flake input:

```nix
let
  admissionSource = "${inputs.myApp}/devops/homelab-admission.nix";
  runtimeContractSource = "${inputs.myApp}/devops/runtime-contract.nix";
  manifestSchemaSource = "${inputs.myApp}/devops/release-manifest.schema.json";
  manifestGeneratorSource = "${inputs.myApp}/scripts/generate-release-manifest";
  admission = import admissionSource;
in
{
  homelab.apps.${admission.key} = admission.app // {
    runtimeContractSourceSha256 = builtins.hashFile "sha256" runtimeContractSource;
    homelabAdmissionSourceSha256 = builtins.hashFile "sha256" admissionSource;
    manifestSchemaSourceSha256 = builtins.hashFile "sha256" manifestSchemaSource;
    manifestGeneratorSourceSha256 = builtins.hashFile "sha256" manifestGeneratorSource;
    host = admission.app.host // {
      releaseManifestOrigins = [ "https://github.com/example/my-app" ];
    };
  };
}
```

The module rejects invalid ids, routes, dependencies, secret mappings, volume
mappings, unsafe migration/auto-update combinations, malformed digests, and
manual services without an HTTPS manifest URL under a host-admitted origin and
a matching channel tag.

## Release Manifest

For release-managed services, the app's release manifest is the immutable
artifact identity. It must include:

- schema version, app id, release target, version, source revision, and creation
  time;
- every admitted release-managed image name and exact digest;
- SHA-256 of the app-owned runtime contract, admission, manifest schema, and
  manifest generator sources.

The host accepts a manifest only when its app, target, all deployment source hashes,
image names, and digest syntax match generated admission metadata. This makes
the release artifact authoritative for image identity without giving the app
repository authority over host secrets or topology.

Pointer tags such as `dev-current` and `prod-current` remain useful for humans
and local container references. They must never decide which remote bytes are
deployed.

## Generated NixOS Runtime

The `homelab.apps` module renders:

- Podman networks, volumes, containers, and only the independently managed
  Quadlet image units;
- native systemd `Requires`/`After` edges from `dependsOn`;
- Quadlet health checks and `Notify=healthy` from `readiness`;
- sops-backed env files;
- manual migration one-shot units;
- loopback Caddy routes and Cloudflared ingress;
- `/etc/homelab-apps/<app>/<channel>.json` admission metadata;
- the generic `homelab-appctl` package and a deploy-only sudo rule.

Release-managed containers use the admitted channel reference with
`Pull=never`. `homelab-appctl` is the single owner of exact pull/tag and release
restart. This avoids the former double restart where Quadlet image units moved
tags and the deploy command restarted containers a second time.

## Deploy Flow

The host interface is:

```sh
homelab-appctl list
homelab-appctl status <app> <channel>
homelab-appctl smoke <app> <channel>
homelab-appctl deploy <app> <channel> --target <release-id> --dry-run
sudo -n homelab-appctl deploy <app> <channel> --target <release-id>
homelab-appctl logs <app> <channel>
```

`--dry-run` performs read-only manifest download and admission validation, then
prints exact images, migration unit, release service units, and smoke paths.

A real deploy:

1. Rejects an invalid target or missing metadata.
2. Acquires a host-local app/channel lock and treats a target as a no-op only
   when the latest successful record used byte-identical admitted metadata.
3. Downloads and validates the release manifest.
4. Snapshots current local image ids.
5. Pulls each admitted `image@digest` and moves only its local channel tag.
6. Runs the declared migration once.
7. Restarts all release-managed services in one systemd transaction. Pinned
   dependencies such as PostgreSQL are not restarted.
8. Runs declared Caddy-loopback smoke checks once.
9. Publishes an `in-progress` record before image mutation, then records target,
   metadata, images, migration, smoke, and final result under
   `/var/lib/homelab-appctl/<app>/<channel>/`.

If pull, tag, or migration fails, the command records failure and restores prior
local channel tags where applicable. If restart or smoke fails, deploy a known
good release target. If its source hashes differ, first revert the pinned app
input through PR/comin, then deploy that target. There is no separate rollback
subcommand because it would create a second release authority. Image rollback
never rolls back database migrations automatically.

## Change and Activation Workflow

Routine app releases whose runtime contract is unchanged do not update the Nix
flake or rebuild NixOS. App CI publishes a release manifest and dispatches the
host-owned deploy workflow with the release target.

When runtime intent changes:

1. Merge the app contract/admission change and publish its release manifest.
2. App CI must not auto-deploy while any deployment source hash is not admitted.
3. Update only the app input in `nix-dots` and review the lock diff.
4. Run Nix evaluation and generated-runtime checks.
5. Merge the `nix-dots` PR; let comin activate it on the homelab.
6. Dispatch the same release target. The host now accepts its source hashes and
   exact image digests.

Do not run ad-hoc `nixos-rebuild` from a development Mac for this GitOps host.
Local work proves evaluation; the PR, CI, and comin path owns activation.

Focused local validation while developing both repositories:

```sh
nix fmt --override-input myApp path:/absolute/path/to/app
nix flake check --all-systems --no-build --show-trace --no-write-lock-file \
  --override-input myApp path:/absolute/path/to/app
```

The Linux-only checks build in CI. They execute the app-owned manifest producer,
negative admission cases, the generated appctl dry-run, a stubbed full deploy
transaction including failure recovery and concurrent calls, and Quadlet
dependencies/readiness. Release deployment must exclude the pinned database
service.

## New App Checklist

- Add a pure app-owned runtime contract and structured admission request.
- Use exact digests for independently pinned stateful dependencies.
- Declare service dependencies and readiness in the contract, not in shell
  sleeps.
- Keep secret values in sops and ports loopback-only.
- Import the admission from one pinned flake input.
- Verify generated metadata, Quadlet, Caddy, and migration units.
- Publish an immutable release manifest for manual services.
- Use the generic host workflow and `homelab-appctl`; do not add per-app SSH or
  systemd scripts.
- Prove backup/restore and decide data-retention semantics before production
  admission.
