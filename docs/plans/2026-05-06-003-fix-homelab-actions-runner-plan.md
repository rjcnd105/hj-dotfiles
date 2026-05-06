---
title: "fix: homelab deploy workflow runner"
type: fix
status: proposed
date: 2026-05-06
origin: docs/plans/2026-05-06-002-feat-homelab-deploy-dispatch-plan.md
---

# fix: homelab deploy workflow runner

## Summary

Finish the host-side piece that lets app repos trigger homelab deploys without
SSH or app-owned systemd logic.

The app repo can now publish a Deopjib dev release and dispatch this repo's
`Deploy Homelab App` workflow, but the dispatched job stays queued because
`rjcnd105/hj-dotfiles` currently has no self-hosted runner registered.

The next `nix-dots` task is to declare and verify a homelab GitHub Actions
runner with labels `self-hosted` and `homelab`, then prove it can run the
existing host-owned deploy command non-interactively.

## Current evidence

These checks were taken after app workflow run
`https://github.com/rjcnd105/my-app/actions/runs/25424447379` dispatched
`https://github.com/rjcnd105/hj-dotfiles/actions/runs/25424486125`.

```sh
gh run view 25424486125 --repo rjcnd105/hj-dotfiles --json status,conclusion,jobs
```

Observed result:

- workflow status: `queued`
- job `deploy`: `queued`
- no job steps started

```sh
gh api repos/rjcnd105/hj-dotfiles/actions/runners \
  --jq '{total_count, runners: [.runners[] | {name,status,busy,labels: [.labels[].name]}]}'
```

Observed result:

```json
{"total_count":0,"runners":[]}
```

On the homelab host, no Actions runner service was visible:

```sh
systemctl list-units --all --no-pager | grep -Ei 'actions|runner|github'
systemctl list-unit-files --no-pager | grep -Ei 'actions|runner|github'
```

The manual fallback deploy succeeded with the same target, so app publishing,
target-aware `homelab-appctl`, and the runtime services are not the blocker:

```sh
sudo -n homelab-appctl deploy deopjib dev --target deopjib-v0.0.0-dev.8b4781a
homelab-appctl smoke deopjib dev
sudo -n homelab-appctl deploy deopjib dev --dry-run --target deopjib-v0.0.0-dev.8b4781a
```

The final dry-run returned:

```text
action: no-op; target already deployed
```

## Responsible boundary

- App repos own release identity and image publication.
- `nix-dots` owns the deploy workflow, homelab runner, validation,
  `homelab-appctl`, sudo boundary, migration, restart, smoke checks, and deploy
  records.
- Do not add SSH, direct `systemctl`, Caddy, secret, migration, or
  `/var/lib/homelab-appctl` logic to app repos.
- Do not run the deploy job on a GitHub-hosted runner. The job mutates homelab
  state and must run on the homelab host.

## Required changes

### 1. Add a runner registration secret

Add a long-lived runner registration credential to the homelab SOPS file.

Recommended key:

```yaml
GITHUB_RUNNER_HJ_DOTFILES_TOKEN: <fine-grained PAT>
```

Use a fine-grained token with the narrowest permission GitHub currently exposes
for repository self-hosted runner registration on `rjcnd105/hj-dotfiles`.
The local NixOS `services.github-runners` module accepts a PAT in `tokenFile`
and obtains short-lived registration tokens on service startup. Do not use a
one-hour runner registration token in Nix config; it will break on future
service re-registration.

Implementation surface:

- update `secrets/homelab/services.yaml` through `sops`
- add `sops.secrets.GITHUB_RUNNER_HJ_DOTFILES_TOKEN.mode = "0400";` in
  `systems/homelab/sops.nix`

### 2. Add a dedicated homelab runner module

Create a small module, for example:

```text
systems/homelab/github-actions-runner.nix
```

Import it from `systems/homelab/default.nix`.

Use `services.github-runners.<name>` instead of ad hoc install scripts. The
local NixOS module exposes the needed options:

- `enable`
- `url`
- `name`
- `tokenFile`
- `extraLabels`
- `replace`
- `extraPackages`
- `user`
- `group`
- `serviceOverrides`

Suggested shape:

```nix
{
  config,
  pkgs,
  ...
}:
{
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

    extraPackages = with pkgs; [
      bash
      coreutils
      curl
      jq
      sudo
      systemd
    ];

    # The deploy workflow intentionally crosses into host mutation through
    # narrow sudo. Keep these overrides minimal and verify them on-host.
    serviceOverrides = {
      NoNewPrivileges = false;
      PrivateUsers = false;
    };
  };
}
```

Use a dedicated system user instead of `root` or the interactive `hj` user. The
runner will execute repository workflow code, so the only elevated path should
be the narrow `sudo -n homelab-appctl deploy/rollback` rule.

### 3. Extend the narrow sudo rule

The deploy workflow currently runs:

```sh
sudo -n homelab-appctl deploy "$APP" "$CHANNEL" --target "$TARGET"
homelab-appctl smoke "$APP" "$CHANNEL"
```

Grant the dedicated runner user only the same appctl commands that the operator
needs:

```text
github-runner-homelab NOPASSWD: homelab-appctl deploy *
github-runner-homelab NOPASSWD: homelab-appctl rollback *
```

Implement this through the existing sudo rule owner in
`systems/homelab/app-containers.nix`, not through a separate imperative sudoers
file.

Do not grant broad `systemctl`, `podman`, `sudo ALL`, or shell access.

### 4. Use absolute appctl paths in the workflow

Patch `.github/workflows/deploy-homelab-app.yml` so the job does not depend on
the runner service PATH for `homelab-appctl`.

Suggested deploy step:

```sh
set -euo pipefail
appctl=/run/current-system/sw/bin/homelab-appctl
sudo -n "$appctl" deploy "$APP" "$CHANNEL" --target "$TARGET"
"$appctl" smoke "$APP" "$CHANNEL"
```

The existing sudo rule already allows the `/run/current-system/sw/bin` form.
Keeping the path explicit makes the workflow less sensitive to the GitHub
runner module's `path` construction.

## Verification checklist

Run local checks before pushing:

```sh
nix fmt
nix flake check --all-systems --no-build --show-trace
git diff --check
```

After the change lands on `main` and comin applies the new generation, verify on
the homelab host:

```sh
systemctl status github-runner-homelab-deploy.service --no-pager
systemctl cat github-runner-homelab-deploy.service
sudo -n -l -U github-runner-homelab
```

Verify GitHub sees the runner:

```sh
gh api repos/rjcnd105/hj-dotfiles/actions/runners \
  --jq '.runners[] | {name,status,busy,labels: [.labels[].name]}'
```

Expected:

- one runner named `homelab-deploy`
- status `online`
- labels include `self-hosted`, the OS/arch labels, and `homelab`

Verify the deploy command from the runner-equivalent user. Use a target that is
already deployed first so the host should no-op:

```sh
sudo -u github-runner-homelab \
  sudo -n /run/current-system/sw/bin/homelab-appctl deploy deopjib dev \
  --dry-run --target deopjib-v0.0.0-dev.8b4781a
```

Expected:

```text
action: no-op; target already deployed
```

Then re-dispatch the queued path with the same target:

```sh
gh workflow run deploy-homelab-app.yml \
  --repo rjcnd105/hj-dotfiles \
  --ref main \
  -f app=deopjib \
  -f channel=dev \
  -f target=deopjib-v0.0.0-dev.8b4781a
```

Expected:

- workflow starts on `homelab-deploy`
- workflow succeeds
- deploy step no-ops because the target is already deployed
- smoke still succeeds

## Acceptance criteria

- `rjcnd105/hj-dotfiles` has an online self-hosted runner with label `homelab`.
- `Deploy Homelab App` no longer remains queued for lack of a runner.
- The runner service does not run as root.
- The runner user has only narrow passwordless sudo for `homelab-appctl`
  deploy/rollback.
- Re-dispatching an already deployed Deopjib dev target succeeds as a no-op.
- A future `mise run deopjib:release-dev -- --no-release` from the app repo can
  publish, dispatch, deploy, smoke, and record the target without any manual
  `homelab-appctl` call.

## Non-goals

- Do not redesign release manifests.
- Do not add app-specific deploy scripts to app repos.
- Do not use a GitHub-hosted runner for host mutation.
- Do not broaden the app/channel allowlist beyond `deopjib:dev` and
  `deopjib:prod` until another admitted app needs it.
- Do not introduce k3s, Flux, or a second deploy controller for this fix.
