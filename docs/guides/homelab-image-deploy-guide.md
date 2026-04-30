# Homelab Image Deploy Guide

Audience: coding agents working in this repo or in app repos that deploy to the
homelab.

Goal: app repos own deployable app intent; `nix-dots` owns host admission and
runtime substrate. Do not hardcode app-specific runtime knowledge in `nix-dots`
unless it is imported from an app-owned contract.

Current direction: use per-app admission in `nix-dots` now. Move to k3s/Flux
later when Kubernetes-backed self-service is worth the operational cost. Do not
add a separate app catalog repo in between unless this decision is reopened.

## Agent Rules

- Treat app runtime shape as app-owned data.
- Treat host binding as `nix-dots`-owned policy.
- Prefer app-owned `devops/homelab-admission.nix` over chat or issue comments
  that copy Nix snippets by hand.
- Do not create a per-app NixOS stack by hand when an app contract can express
  the same facts.
- Do not put plaintext secrets in app repos or `nix-dots`.
- Do not make routine image deploys require a NixOS rebuild.
- Do not enable registry auto-update for services that run schema migrations on
  start.
- Keep new contracts close to Kubernetes primitives: image, service, secret env,
  volume, route, health, migration, update policy, release channel.
- Do not add app-specific homelab deploy scripts to app repos. App repos publish
  images; `nix-dots` deploys admitted apps through `homelab-appctl`.

## Ownership Boundary

| Concern | Owner | Notes |
|---|---|---|
| OCI image build and tags | app repo | Publish immutable SHA tags; pointer tags are optional deploy channels. |
| Runtime contract | app repo | Store as `devops/runtime-contract.nix`. |
| Secret values | host/operator | Store through sops or future cluster secret management. |
| Secret names required by the app | app repo | Declare as `requiredSecretEnv`; host maps them to actual secrets. |
| Admission request | app repo proposes, `nix-dots` admits | Store as `devops/homelab-admission.nix` when structured handoff is needed. |
| Public hostname and tunnel route | `nix-dots` | Host admission decision. |
| Persistent volume location and backup policy | `nix-dots` | App may request a volume; host chooses storage. |
| Runtime backend | `nix-dots` | Podman/Quadlet now, k3s later. |
| Migration safety policy | app repo declares, host enforces | Host may reject unsafe auto-update combinations. |
| Release command | app repo | Example: `mise run my-app:release-dev --minor`; starts app CI/release only. |
| Host deploy command | `nix-dots` | `homelab-appctl deploy/smoke/rollback <app> <channel>`. |
| OCI release manifest | app repo, optional | Provenance or audit artifact only; not the homelab deploy ABI. |

## Portability Boundary

`homelab-appctl` is a `nix-dots` homelab adapter, not a public deploy platform.
It assumes this host's NixOS, Podman/Quadlet, Caddy, Cloudflared, sops, and
systemd boundaries.

The portable output of an app repo is the OCI image plus documented runtime
needs: image refs, env, secret names, ports, routes, health paths, volumes,
migration command, and release channel tags. Non-Nix users should consume those
images through their own Docker Compose, Podman, Kubernetes, or platform-specific
deployment layer.

For this homelab, app contributors can trigger app releases if they have app repo
permissions, but only the homelab-side runner applies the published image to the
server. This keeps host secrets and runtime policy out of app repos.

## Change Authority

In the current phase, adding a new app requires a small `nix-dots` host binding
entry. Routine releases after admission should not require `nix-dots` changes.

| Change | Self-service by app repo? | Requires `nix-dots` review? |
|---|---:|---:|
| Move image pointer tag, for example `:dev-current` | yes | no |
| Publish immutable image tag | yes | no |
| Add or update `devops/homelab-admission.nix` | yes | yes, before import |
| Change service image name | yes | yes |
| Add or remove required secret env | yes | yes |
| Add public route or hostname | no | yes |
| Add persistent volume | no | yes |
| Change migration mode | yes | yes |
| Change runtime backend | no | yes |

## Runtime Contract Schema

Each app repo should provide a pure Nix data file:

```text
devops/runtime-contract.nix
```

The file must evaluate without importing `nixpkgs`, reading secrets, reading the
network, or depending on the host. It is data, not deployment logic.

Required top-level fields:

| Field | Type | Meaning |
|---|---|---|
| `name` | string | Stable lowercase app id. Use in unit names and labels. |
| `channel` | string | Deploy channel such as `dev`, `staging`, or `prod`. |
| `images` | attrset string | Fully qualified OCI image references. |
| `services` | attrset service | Runtime services exposed by the app. |
| `routes` | list route | Requested HTTP routing shape. |

Optional top-level fields:

| Field | Type | Default | Meaning |
|---|---|---|---|
| `migrations` | attrset | `{ mode = "none"; }` | Migration command and safety policy. |
| `release` | attrset | `{ versioning = "external"; channels = { }; }` | Host deploy channel metadata. |
| `volumes` | attrset volume | `{ }` | Persistent storage requests keyed by stable volume id. |
| `notes` | string | `""` | Human/operator notes. |

Service fields:

| Field | Type | Required | Meaning |
|---|---|---:|---|
| `image` | string | yes | Key into `images`. |
| `internalPort` | int | yes | Container listen port. |
| `healthPath` | string | no | Path used for readiness/smoke checks. |
| `env` | attrset string | no | Non-secret environment variables. |
| `requiredSecretEnv` | list string | no | Secret env names the host must map. |
| `updatePolicy` | enum | yes | `manual`, `registry-auto`, or `pinned-digest`. |
| `volumeMounts` | list volumeMount | no | Requested mounts from top-level `volumes`. |

Volume fields:

| Field | Type | Required | Meaning |
|---|---|---:|---|
| `notes` | string | no | Human/operator reason for the requested volume. |

Volume mount fields:

| Field | Type | Required | Meaning |
|---|---|---:|---|
| `volume` | string | yes | Key into top-level `volumes`. |
| `mountPath` | string | yes | Container path. |
| `readOnly` | bool | no | Defaults to `false`. |

Route fields:

| Field | Type | Required | Meaning |
|---|---|---:|---|
| `host` | string | yes | Requested public host. |
| `path` | string | yes | Path matcher such as `/`, `/api/*`, `/health`. |
| `service` | string | yes | Key into `services`. |

Migration fields:

| Field | Type | Required | Meaning |
|---|---|---:|---|
| `mode` | enum | yes | Current Podman renderer supports `none` or `manual`. |
| `service` | string | if mode != `none` | Service image used for migration. |
| `command` | list string | if mode != `none` | Command argv. |

Release fields:

| Field | Type | Required | Meaning |
|---|---|---:|---|
| `versioning` | enum | no | Must be `external`; app CI owns versioning. |
| `channels` | attrset channel | no | Deploy channels keyed by `dev`, `prod`, etc. |

Release channel fields:

| Field | Type | Required | Meaning |
|---|---|---:|---|
| `tag` | string | yes | Channel pointer tag such as `dev-current`. |
| `mode` | enum | no | `manual`, `auto`, or `approved`; current runner is host-local. |
| `strategy` | enum | no | Current value: `coordinated`. |
| `smokePaths` | list string | no | Paths checked through Caddy after deploy. |
| `migrate` | enum | no | `none` or `manual`; `manual` requires manual migrations. |
| `rollback` | enum | no | Current value: `record-only`. |

Host policy:

- `registry-auto` is not allowed on the service named by `migrations.service`.
- Manual migrations render a host-local one-shot unit, but are never run during
  NixOS activation or by background registry auto-update.
- Every public service must have either `healthPath` or an explicit documented
  reason why health checks are unavailable.

## Runtime Contract Example

```nix
# devops/runtime-contract.nix
{
  name = "my-app";
  channel = "dev";

  images = {
    api = "ghcr.io/example/my-app-api:dev-current";
    web = "ghcr.io/example/my-app-web:dev-current";
  };

  services = {
    api = {
      image = "api";
      internalPort = 4000;
      healthPath = "/health";
      env = {
        APP_ENV = "dev";
        PORT = "4000";
      };
      requiredSecretEnv = [
        "DATABASE_URL"
        "SECRET_KEY_BASE"
      ];
      updatePolicy = "manual";
      volumeMounts = [
        {
          volume = "app-data";
          mountPath = "/var/lib/my-app";
        }
      ];
    };

    web = {
      image = "web";
      internalPort = 8080;
      updatePolicy = "registry-auto";
    };
  };

  routes = [
    {
      host = "my-app.example.com";
      path = "/health";
      service = "api";
    }
    {
      host = "my-app.example.com";
      path = "/api/*";
      service = "api";
    }
    {
      host = "my-app.example.com";
      path = "/";
      service = "web";
    }
  ];

  migrations = {
    mode = "manual";
    service = "api";
    command = [ "/app/bin/migrate" ];
  };

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
  };

  volumes.app-data = {
    notes = "Persistent app data; host chooses storage class and backup policy.";
  };
}
```

## Homelab Admission Request

To avoid copy-paste handoffs, an app repo may also provide:

```text
devops/homelab-admission.nix
```

This file is a structured request for host admission. It must not contain secret
values and must not implement host runtime logic.

```nix
# devops/homelab-admission.nix
{
  key = "my-app";

  app = {
    enable = true;
    contract = import ./runtime-contract.nix;

    host = {
      domain = "my-app.example.com";
      loopbackPortBase = 18100;
      registryAuth = "ghcr-readonly";

      secretMap = {
        DATABASE_URL = "MY_APP_DATABASE_URL";
        SECRET_KEY_BASE = "MY_APP_SECRET_KEY_BASE";
      };

      volumes.app-data = {
        backup = true;
        class = "local-podman";
      };
    };
  };
}
```

The app repo owns this request. `nix-dots` still owns the decision to import it,
the actual secret values, DNS/tunnel exposure, and volume policy. Later k3s/Flux
can treat the same admission request as an allowlist entry for watched app paths.

## Host Binding Shape

For the current phase, `nix-dots` admits each app through a small host-owned
binding. Prefer importing the app-owned admission request:

```nix
let
  admission = import "${inputs.my-app}/devops/homelab-admission.nix";
in
{
  homelab.apps.${admission.key} = admission.app;
}
```

If the app repo does not yet provide an admission request, use the explicit
fallback shape:

```nix
homelab.apps.my-app = {
  enable = true;
  contract = import "${inputs.my-app}/devops/runtime-contract.nix";

  host = {
    domain = "my-app.example.com";
    loopbackPortBase = 18100;
    registryAuth = "ghcr-readonly";

    secretMap = {
      DATABASE_URL = "MY_APP_DATABASE_URL";
      SECRET_KEY_BASE = "MY_APP_SECRET_KEY_BASE";
    };

    volumes.my-app-db = {
      backup = true;
      class = "local-podman";
    };
  };
};
```

The app contract says what is needed. The host binding says what is allowed and
where host-owned resources come from.

Keep this shape Kubernetes-mappable. It should describe admission, secrets,
ports, routes, and volumes in terms that can later become Kubernetes namespace,
Deployment, Service, Secret, PersistentVolumeClaim, and Ingress/Gateway
resources.

## Current Podman Renderer Requirements

When implementing the Podman/Quadlet renderer in `nix-dots`, it must:

- render Quadlet files under `/etc/containers/systemd/`
- publish app ports to loopback only
- route public traffic through Caddy and cloudflared
- generate sops-backed env files from `secretMap`
- order private registry image pulls after `sops-install-secrets.service`
- add finite systemd start timeouts
- add activation refresh logic for new or changed Quadlet files
- render manual migration one-shot units
- render `/etc/homelab-apps/<app>/<channel>.json` metadata for host commands
- provide `homelab-appctl deploy/smoke/rollback <app> <channel>`
- reject `registry-auto` on the service named by `migrations.service`
- keep Hindsight special until its host-network dependencies are deliberately
  migrated

Renderer output should be inspectable with:

```sh
nix eval --raw '.#nixosConfigurations.homelab_hj.config.environment.etc."<quadlet-path>".text'
```

## Release Automation

The comfortable app-side button lives in the app repo:

```sh
mise run my-app:release-dev --minor
```

That command should create the release PR, run CI, publish OCI images, and move
the channel tag such as `dev-current`. It must not SSH into homelab and must not
carry app-specific host deploy logic.

The homelab applies published images through the generic runner generated by
`nix-dots`:

```sh
homelab-appctl list
homelab-appctl status my-app dev
homelab-appctl smoke my-app dev
homelab-appctl deploy my-app dev --dry-run
homelab-appctl deploy my-app dev
homelab-appctl rollback my-app dev
```

Deploy order:

1. Read `/etc/homelab-apps/<app>/<channel>.json`.
2. Pull image units and record local image IDs.
3. Run the manual migration unit if the contract declares one.
4. Restart generated app service units.
5. Smoke-test declared paths through Caddy loopback with the public Host header.
6. Write a deploy record under `/var/lib/homelab-appctl/<app>/<channel>/`.

Rollback is intentionally conservative in the current Podman phase. The command
exists and reports the previous image records, but automatic image restoration is
enabled only after that path is proven safe for the app and its migrations.

OCI release manifests may exist in app CI for audit/provenance, but they are not
the deploy ABI. The deploy ABI is the app-owned runtime contract plus the host
metadata generated by `nix-dots`.

## Future k3s Path

Introduce k3s/Flux later when the homelab needs true app-owned runtime
reconciliation.

In that mode:

- `nix-dots` owns k3s, Flux, storage classes, ingress/tunnel policy, and cluster
  security baseline
- app repos own Kubernetes manifests, Helm charts, or generated manifests from
  the same `runtime-contract.nix`
- Flux watches approved app repo paths
- image tag updates remain routine app-owned deploys
- host/cluster policy still owns secrets and public exposure

Do not introduce k3s just to move one app's runtime fields out of `nix-dots`.
Use k3s when app count, rollout needs, or self-service policy boundaries justify
the operational cost.

When migrating, preserve the app-owned `runtime-contract.nix` as the source of
truth. The Podman renderer should be replaceable by a Kubernetes renderer rather
than requiring each app to redesign its deploy contract.

## Agent Workflow

When asked to add a new homelab app:

1. Inspect the app repo for `devops/homelab-admission.nix`.
2. If it is missing, inspect or add `devops/runtime-contract.nix` in the app
   repo first, then ask the app repo to add the admission request.
3. Import only the reviewed admission request into `homelab.apps.<key>`.
4. Validate that all images are fully qualified OCI references.
5. Check that every `requiredSecretEnv` has a proposed host secret mapping.
6. Check migration/update safety:
   - allow `registry-auto` for stateless services
   - prefer `manual` for DB-backed services
   - reject registry auto-update on the migration service
   - keep release channel rollback as `record-only` unless automatic image
     restore has been proven on homelab
7. Add or update only the host binding in `nix-dots`.
8. Evaluate generated Quadlet/Caddy/sops/app metadata output.
9. Run `homelab-appctl smoke <app> <channel>` after deployment.

## Podman Smoke Checks

After deployment to homelab:

```sh
systemctl is-active podman-auto-update.timer
systemctl list-units --no-legend --plain '*my-app*'
find /etc/containers/systemd -maxdepth 1 -iname '*my-app*' -print
podman auto-update --dry-run
homelab-appctl smoke my-app dev
```

Expected result:

- app units are running from declared images
- public health route reaches the intended service
- backend/web ports are not directly public
- registry auto-update applies only to services with safe rollback behavior

## Acceptance Checklist

Before a change is ready:

- app repo has `devops/runtime-contract.nix`
- structured handoff uses `devops/homelab-admission.nix` when available
- contract is pure data and evaluates locally
- `nix-dots` contains only host binding, not copied app runtime details
- every required secret env maps to a host secret
- every public route is intentionally exposed
- migration and update policy do not conflict
- generated runtime output is evaluated
- generated app metadata is evaluated
- live deployment smoke checks are documented
