---
title: "handoff: homelab cross-repo app deploy dispatch"
type: handoff
status: draft
date: 2026-05-06
---

# handoff: homelab cross-repo app deploy dispatch

## Context

The app repo should remain responsible for release intent, OCI image
publication, and channel/tag movement. It must not become a hidden homelab
infra tool with SSH, systemd, Caddy, secrets, migration, or deploy-record logic.

`nix-dots` remains responsible for the host deploy runner:

- admitted app/channel validation
- registry pull and image resolution
- migration execution
- systemd restart
- smoke check
- deploy record writes
- no-op behavior when the currently deployed target already matches the
  requested target

## Current Failure

The app-side dev release workflow reached image publication, moved
`dev-current`, and created the app release tag. It failed only when dispatching
the homelab deploy workflow:

```text
HOMELAB_DEPLOY_DISPATCH_TOKEN:
curl: (22) The requested URL returned error: 401
```

The secret is empty in the app repo. That is expected for the previous
successful image-publish workflow because the old workflow never dispatched
`nix-dots`; it stopped after GHCR image publication and `dev-current` movement.

There is also no deployed `deploy-homelab-app.yml` workflow on the remote
`hj-dotfiles` default branch yet, so the host-side dispatch target must land
before the app repo workflow can complete.

## Required `nix-dots` Work

1. Add a default-branch GitHub Actions workflow:

   ```text
   .github/workflows/deploy-homelab-app.yml
   ```

   It should accept `workflow_dispatch` inputs:

   ```text
   app
   channel
   target
   ```

2. Run the job only on the homelab self-hosted runner:

   ```yaml
   runs-on:
     - self-hosted
     - homelab
   ```

3. Keep an explicit allowlist at first:

   ```text
   deopjib:dev
   deopjib:prod
   ```

4. Treat `target` as the deployment identity, not as deploy logic. The preferred
   target shape is the app release identifier, for example:

   ```text
   deopjib-v0.0.1
   ```

   A full source commit SHA is also acceptable while the app workflow still uses
   SHA-tagged images, but the durable model is release-version targeting with
   component digests recorded by the deploy runner.

5. The workflow should run:

   ```sh
   sudo -n homelab-appctl deploy "$APP" "$CHANNEL" --target "$TARGET"
   homelab-appctl smoke "$APP" "$CHANNEL"
   ```

6. `homelab-appctl deploy` must read:

   ```text
   /etc/homelab-apps/<app>/<channel>.json
   ```

   and no-op if the latest successful deploy record already has the same target.

7. Successful deploy records should include:

   ```text
   app
   channel
   target
   deployedAt
   service image refs or resolved digests
   migration result
   smoke result
   ```

## Required App Repo Setup

After the nix-dots workflow is on the remote default branch, add an app repo
Actions secret named:

```text
HOMELAB_DEPLOY_DISPATCH_TOKEN
```

Use a fine-grained GitHub token scoped narrowly to the `rjcnd105/hj-dotfiles`
repository with permission to dispatch Actions workflows. The app repo should
only be able to request the allowlisted workflow; it should not get SSH access
to the homelab or write access to nix-dots source.

## Expected Dev Flow

```sh
mise run deopjib:release-dev --patch
```

Expected behavior:

1. app repo opens/merges the release PR
2. app workflow publishes changed component images
3. app workflow creates the release identifier, for example `deopjib-v0.0.1`
4. app workflow dispatches `nix-dots` with `app=deopjib`,
   `channel=dev`, and `target=deopjib-v0.0.1`
5. homelab runner deploys through `homelab-appctl`
6. repeated dispatch with the same target is a no-op

## Expected Prod Flow

```sh
mise run deopjib:deploy-prod -- 0.0.1
```

Expected behavior:

1. app workflow resolves `deopjib-v0.0.1`
2. app workflow promotes the verified component images to prod channel pointers
3. app workflow dispatches `nix-dots` with `app=deopjib`,
   `channel=prod`, and `target=deopjib-v0.0.1`
4. homelab runner deploys prod through `homelab-appctl`
5. repeated dispatch with the same target is a no-op

## Non-Goals

- Do not add SSH deploy scripts to the app repo.
- Do not put Caddy, systemd, secrets, migration, or deploy-record logic in the
  app repo.
- Do not make `nix-dots` infer app SemVer from commits.
- Do not use mutable channel tags as the only deploy identity. Channel tags are
  pointers; `target` is the release identity recorded by the host.
