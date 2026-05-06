---
title: Homelab GitHub Actions runner unblocked queued deploy workflow
date: 2026-05-06
category: integration-issues
module: homelab-deploy-workflow
problem_type: integration_issue
component: development_workflow
symptoms:
  - "rjcnd105/hj-dotfiles homelab deploy workflow stayed queued because no self-hosted runner matched the job"
  - "Runner service could not read the SOPS-backed PAT until secret owner and group were set"
  - "Runner sudo execution failed until systemd sandboxing and the setuid sudo path were corrected"
root_cause: incomplete_setup
resolution_type: environment_setup
severity: high
related_components:
  - github-actions
  - nixos
  - sops-nix
  - sudo
  - systemd
  - homelab-appctl
tags: [github-actions, self-hosted-runner, homelab, sops-nix, sudo, workflow-paths, homelab-appctl]
---

# Homelab GitHub Actions runner unblocked queued deploy workflow

## Problem

App repositories could publish a homelab release and dispatch the
`rjcnd105/hj-dotfiles` `Deploy Homelab App` workflow, but the deploy job stayed
queued because the repository had no self-hosted runner matching
`self-hosted` and `homelab`.

The responsible boundary stayed unchanged: app repos publish release identity
and images; `nix-dots` owns the homelab runner, deploy workflow,
`homelab-appctl`, sudo boundary, smoke checks, and host mutation.

## Symptoms

- Dispatched workflow run `25424486125` stayed `queued`; no job steps started.
- `gh api repos/rjcnd105/hj-dotfiles/actions/runners` returned no runners.
- The homelab host had no visible GitHub Actions runner systemd unit.
- Manual fallback deploy with `sudo -n homelab-appctl deploy ...` succeeded,
  proving app publishing and `homelab-appctl` were not the blocker.
- After the runner existed, runtime failures exposed secondary host-boundary
  issues: unreadable SOPS token, sandboxed sudo, and non-setuid store `sudo`.

## What Didn't Work

- Solving deploy execution in the app repo. The app repo can dispatch and
  publish, but must not own SSH, `systemctl`, Caddy, secrets, migrations, or
  direct host mutation.
- Running on GitHub-hosted runners. The job mutates homelab host state, so it
  must run on the homelab machine.
- Encrypting the PAT without assigning secret ownership. The runner service
  could not read `/run/secrets/GITHUB_RUNNER_HJ_DOTFILES_TOKEN` until `owner`
  and `group` were set to `github-runner-homelab`.
- Calling `sudo` from the runner PATH. The Nix store `sudo` is not the NixOS
  setuid wrapper, so deploy failed until the workflow used
  `/run/wrappers/bin/sudo`.
- Leaving the default NixOS runner sandbox unchanged. The upstream runner unit
  defaults are appropriate for unprivileged CI, but the deploy job deliberately
  crosses into a narrow host-owned sudo path.

## Solution

Add a dedicated NixOS GitHub Actions runner for homelab deploys:

```nix
users.groups.github-runner-homelab = { };

users.users.github-runner-homelab = {
  isSystemUser = true;
  group = "github-runner-homelab";
};

services.github-runners.homelab-deploy = {
  enable = true;
  url = "https://github.com/rjcnd105/hj-dotfiles";
  name = "homelab-deploy";
  tokenFile = config.sops.secrets.GITHUB_RUNNER_HJ_DOTFILES_TOKEN.path;
  extraLabels = [ "homelab" ];
  replace = true;

  user = "github-runner-homelab";
  group = "github-runner-homelab";
};
```

Import the module from `systems/homelab/default.nix`:

```nix
imports = [
  ./app-containers.nix
  ./app-admissions.nix
  ./github-actions-runner.nix
];
```

Declare the SOPS token with runner-readable ownership:

```nix
sops.secrets.GITHUB_RUNNER_HJ_DOTFILES_TOKEN = {
  mode = "0400";
  owner = "github-runner-homelab";
  group = "github-runner-homelab";
};
```

Allow only the host deploy adapter through sudo:

```nix
security.sudo.extraRules = [
  {
    users = [
      myOptions.userName
      "github-runner-homelab"
    ];
    runAs = "root";
    commands = [
      { command = "${homelabAppctl}/bin/homelab-appctl deploy *"; options = [ "NOPASSWD" ]; }
      { command = "${homelabAppctl}/bin/homelab-appctl rollback *"; options = [ "NOPASSWD" ]; }
      { command = "/run/current-system/sw/bin/homelab-appctl deploy *"; options = [ "NOPASSWD" ]; }
      { command = "/run/current-system/sw/bin/homelab-appctl rollback *"; options = [ "NOPASSWD" ]; }
    ];
  }
];
```

Make the workflow use host-stable absolute paths:

```yaml
runs-on:
  - self-hosted
  - homelab
```

```sh
set -euo pipefail
appctl=/run/current-system/sw/bin/homelab-appctl
sudo=/run/wrappers/bin/sudo
"$sudo" -n "$appctl" deploy "$APP" "$CHANNEL" --target "$TARGET"
"$appctl" smoke "$APP" "$CHANNEL"
```

Relax the runner service sandbox only where live sudo execution proved it was
needed:

```nix
serviceOverrides = {
  CapabilityBoundingSet = lib.mkForce [ "~" ];
  NoNewPrivileges = false;
  PrivateMounts = false;
  PrivateUsers = false;
  ProtectSystem = false;
  RestrictNamespaces = false;
  RestrictSUIDSGID = false;
  SystemCallFilter = lib.mkForce [ ];
};
```

## Why This Works

The stuck workflow was not a dispatch problem. GitHub had no eligible runner
for `runs-on: [self-hosted, homelab]`, so the job could never start.

`services.github-runners.homelab-deploy` registers a repository runner against
`rjcnd105/hj-dotfiles` with the required `homelab` label. The service uses a
SOPS-backed PAT only to obtain GitHub registration tokens; runtime workflow jobs
do not need direct token access. The upstream NixOS module also renders
`InaccessiblePaths` for the configured token path and the copied state token.

The runner executes as `github-runner-homelab`, not `root` or the interactive
user. Host mutation is constrained to `homelab-appctl deploy` and
`homelab-appctl rollback` through passwordless sudo. The workflow calls
`/run/wrappers/bin/sudo` because that is the NixOS setuid wrapper, and
`/run/current-system/sw/bin/homelab-appctl` because that is the stable active
system command path.

## Prevention

- Keep homelab deploy jobs pinned to `self-hosted` plus `homelab`; never move
  host mutation to GitHub-hosted runners.
- For runner registration secrets, set SOPS `owner` and `group` to the runner
  service user.
- Use `/run/wrappers/bin/sudo` in workflows that need NixOS sudo semantics.
- Keep sudo rules command-specific; do not grant `systemctl`, `podman`,
  `sudo ALL`, shell access, or broad root access.
- Treat live deploy success as evidence, not a regression guard. Add cheap CI
  checks for runtime invariants that must not drift. PR #20 applied this after
  a stale image pull incident by adding a flake check that fails if
  `homelab-appctl deploy` regresses from `systemctl restart "$image_unit"` back
  to `systemctl start "$image_unit"`.
- Add durable checks for the runner/deploy ABI:
  - workflow contains `runs-on: [self-hosted, homelab]`
  - workflow uses `/run/current-system/sw/bin/homelab-appctl`
  - workflow uses `/run/wrappers/bin/sudo`
  - sudoers includes only deploy and rollback for `github-runner-homelab`
  - `services.github-runners.homelab-deploy.extraLabels` includes `homelab`
- Add a runner health/runbook check for
  `github-runner-homelab-deploy.service` registration/startup failures.
- Install or wire `actionlint` if workflow linting becomes part of repo checks.

## Related Issues

- [`../architecture-patterns/homelab-app-contract-generic-deploy-runner-2026-05-06.md`](../architecture-patterns/homelab-app-contract-generic-deploy-runner-2026-05-06.md)
  covers the broader app-contract and host deploy architecture. This document
  covers the runtime runner implementation failure inside that architecture.
- [`../tooling-decisions/homelab-podman-quadlet-runtime-migration-2026-04-27.md`](../tooling-decisions/homelab-podman-quadlet-runtime-migration-2026-04-27.md)
  explains why Podman/Quadlet is the current renderer and why deploy should
  mutate image state through host-owned commands instead of app repo SSH.
- [`../../guides/homelab-image-deploy-guide.md`](../../guides/homelab-image-deploy-guide.md)
  is the operator-facing guide for release, dispatch, deploy, smoke, and
  rollback flow.
- [`../../plans/2026-05-06-003-fix-homelab-actions-runner-plan.md`](../../plans/2026-05-06-003-fix-homelab-actions-runner-plan.md)
  captured the original queued-runner evidence and acceptance criteria.
- PR #18 added the `Deploy Homelab App` workflow and target-aware
  `homelab-appctl`.
- PR #19 allowed Deopjib dev snapshot targets.
- PR #20 fixed a later stale image pull issue and added a regression guard for
  image unit restart behavior.

## Residual Risks

- Prod approval is currently a GitHub environment boundary, not a host-enforced
  deploy policy. A separate host-side gate or narrower runner/sudo split is
  needed before treating this as a complete prod authorization boundary.
- The runner unit depends on SOPS secrets and GitHub registration but has no
  explicit restart retry policy for startup failures.
- The successful workflow run proves the current state, but runner token
  revocation, runner deregistration, or host drift can invalidate it later.
- `actionlint` was unavailable during verification.
