# Flake Output Rules

Use these rules when editing `flake.nix`, `flake.lock`, CI checks, templates, or
flake inputs.

## Do

- Keep workflows discoverable through standard outputs:
  - `nixosConfigurations`
  - `darwinConfigurations`
  - `checks`
  - `formatter`
  - `devShells`
  - `templates`
  - `packages` / `apps` when this repo intentionally exposes tools
  - `nixosModules` when exporting reusable modules
- Evaluate concrete outputs before refactoring structure.
- Use explicit systems. Flakes do not infer every target platform for you.
- Track newly added files before relying on flake evaluation. In this repo, use
  `jj file track <path>` when needed.
- Keep `flake.lock` changes narrow and intentional.
- Use `inputs.<name>.inputs.<other>.follows` only when it reduces a real
  duplicate top-level dependency.
- Use `checks` for cheap, deterministic validation.
- Prefer `nix flake check --all-systems --no-build --show-trace` for broad local
  evaluation.

## Do Not

- Do not hide operational workflows in ad hoc scripts when a flake output is the
  stable interface.
- Do not run broad `nix flake update` for unrelated work.
- Do not put secrets in `flake.nix`, flake inputs, generated metadata, or source
  paths referenced by outputs.
- Do not assume untracked files are visible to flake evaluation.
- Do not use relative flake references without `./`.
- Do not force every transitive `nixpkgs` input to follow the root input by
  default. For module and overlay flakes, that is often irrelevant.
- Do not add a flake framework or restructure the root flake unless it removes
  real duplication in this repo.

## Examples

Good targeted eval:

```sh
nix eval .#nixosConfigurations.homelab_hj.config.networking.hostName
nix eval --raw '.#nixosConfigurations.homelab_hj.config.environment.etc."<path>".text'
```

Bad lock update:

```sh
nix flake update
```

Good targeted lock update:

```sh
nix flake lock --update-input deopjibRuntime
```

Bad local reference:

```sh
nix build my-relative-flake#pkg
```

Good local reference:

```sh
nix build ./my-relative-flake#pkg
```

Bad hidden workflow:

```sh
./scripts/check-everything-with-remote-sudo.sh
```

Good flake-visible workflow:

```nix
checks.${system}.formatting = treefmtEval.${system}.config.build.check self;
formatter.${system} = treefmtEval.${system}.config.build.wrapper;
```

## Review Checklist

- Is the intended workflow available from `nix flake show` or a documented
  flake output?
- Did any new file need `jj file track`?
- Is `flake.lock` changed only for the intended input?
- Can CI run the check without SSH, sudo, or live homelab state?
- Is this root-flake complexity justified by repeated structure?

## Sources

- https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-flake.html
- https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-flake-check.html
- https://nix.dev/manual/nix/2.24/command-ref/new-cli/nix.html
- https://nix.dev/tutorials/working-with-local-files.html
