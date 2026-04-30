# Nix Language Rules

Use these rules for `.nix` expressions, helper libraries, derivations, and module
fragments.

## Do

- Quote URLs.
- Prefer `let ... in` bindings over broad `rec` attrsets.
- Keep names explicit with `inherit (pkgs) curl jq;` rather than large scopes.
- Import Nixpkgs with explicit `config` and `overlays` when importing manually.
- Use `lib.recursiveUpdate` when a nested merge is intended.
- Give source paths stable names when path identity matters.
- Keep secrets out of Nix expressions and out of paths copied to the Nix store.

## Do Not

- Do not write bare URLs.
- Do not use `rec` just to avoid a `let` block.
- Do not put `with pkgs;` or `with (import <nixpkgs> {});` at the top of a file.
- Do not use `<nixpkgs>` or other lookup paths in repo code.
- Do not rely on user-local Nixpkgs configuration leaking into imports.
- Do not use `//` when you mean a deep merge.
- Do not interpolate broad local directories into strings if that can copy
  unrelated files or secrets into the store.

## Examples

Bad:

```nix
with (import <nixpkgs> {});

rec {
  src = ./.;
  url = https://example.com/source.tar.gz;
  buildInputs = with pkgs; [ curl jq ];
}
```

Good:

```nix
let
  pkgs = import inputs.nixpkgs {
    system = "x86_64-linux";
    config = { };
    overlays = [ ];
  };

  inherit (pkgs) curl jq;
in
{
  src = builtins.path {
    path = ./.;
    name = "myproject";
  };

  url = "https://example.com/source.tar.gz";
  buildInputs = [
    curl
    jq
  ];
}
```

Bad nested update:

```nix
defaults // {
  services = {
    caddy.enable = true;
  };
}
```

Good nested update:

```nix
lib.recursiveUpdate defaults {
  services = {
    caddy.enable = true;
  };
}
```

## Review Checklist

- Are all dependencies explicit?
- Can static analysis see where names come from?
- Does evaluation depend on `$NIX_PATH`, channels, or user-local config?
- Could any referenced path copy secrets or unrelated files into the store?
- Is a shallow merge accidentally deleting nested config?

## Sources

- https://nix.dev/guides/best-practices.html
- https://nix.dev/tutorials/working-with-local-files.html
