# NixOS Module Rules

Use these rules when editing `systems/`, service modules, host modules, options,
systemd units, activation scripts, or generated `/etc` files.

## Do

- Model host behavior as NixOS modules and typed options.
- Keep reusable runtime shapes in `options` with `mkOption`, `types`, defaults,
  descriptions, and assertions.
- Use `mkEnableOption` for enable flags.
- Use `types.submodule` for structured app/service declarations.
- Prefer package options or explicit package fields over overlays when a module
  only needs one package to be configurable.
- Generate files through Nix options such as `environment.etc`,
  `systemd.services`, `sops.templates`, and service-specific options.
- Use `systemd.services.<name>.script` or correctly escaped `ExecStart` values.
- Keep activation scripts idempotent and limited to reconciliation that NixOS
  options cannot express.
- Evaluate generated output before checking live host behavior.

## Do Not

- Do not hand-edit generated files under `/etc`, `/run`, or
  `/etc/containers/systemd`.
- Do not add imperative host scripts when a module option can express the same
  state.
- Do not leave module options untyped.
- Do not hide app-specific behavior in generic host modules.
- Do not run migrations, destructive commands, or external network deploys during
  activation.
- Do not use overlays just to swap one package in one service. Use a package
  option when possible.
- Do not expose public ports directly when the host policy says traffic must go
  through Caddy and Cloudflared.

## Examples

Bad untyped module shape:

```nix
{
  config.services.myService = {
    port = "8080";
    settings = { };
  };
}
```

Good typed module shape:

```nix
{ lib, config, ... }:
let
  cfg = config.services.myService;
in
{
  options.services.myService = {
    enable = lib.mkEnableOption "my service";
    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.my-service = {
      wantedBy = [ "multi-user.target" ];
      serviceConfig.Type = "simple";
    };
  };
}
```

Bad generated file workflow:

```sh
sudo vim /etc/containers/systemd/my-app.container
sudo systemctl restart my-app
```

Good generated file workflow:

```nix
environment.etc."containers/systemd/my-app.container".text = ''
  [Container]
  Image=ghcr.io/example/my-app:dev-current
'';
```

Then verify:

```sh
nix eval --raw '.#nixosConfigurations.homelab_hj.config.environment.etc."containers/systemd/my-app.container".text'
```

## Review Checklist

- Are options typed and asserted?
- Is the generated file derived from Nix data rather than edited by hand?
- Is imperative code idempotent and unavoidable?
- Could this be a package option instead of an overlay?
- Does the module preserve rollback by avoiding live mutation in activation?

## Sources

- https://nixos.org/manual/nixos/stable/index.html
- https://nixos.org/manual/nixpkgs/stable/
