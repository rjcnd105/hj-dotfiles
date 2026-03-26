---
title: "Nix LSP in Zed: Switch from nil to nixd for Flake-Aware Autocompletion"
date: 2026-03-26
problem_type: developer_experience
component: tooling
root_cause: config_error
resolution_type: config_change
severity: medium
tags:
  - nix
  - zed
  - lsp
  - nixd
  - nil
  - direnv
  - flake
  - autocompletion
  - nix-darwin
  - home-manager
module: nix-darwin-config
category: developer-experience
---

# Nix LSP in Zed: Switch from nil to nixd for Full Autocompletion

## Problem

Nix files in Zed editor had zero autocompletion, error highlighting, or option property suggestions -- effectively plain text editing despite having LSP tooling installed.

## Symptoms

- No `pkgs.*` attribute completion when typing package names
- No nix-darwin or home-manager option path suggestions (e.g., `programs.fish.enable`)
- No inline error highlighting for undefined attributes or type mismatches
- Formatting via nixfmt worked (the only functioning LSP feature)

## What Didn't Work

1. **Configuring nil's `nix.flake.autoEvalInputs`** -- nil is architecturally a parser-based LSP. Even with flake settings, it cannot evaluate expressions or resolve option/attribute paths. This is a fundamental limitation, not a configuration gap.
2. **Creating `.nixd.json` project config** -- Deprecated in nixd v2.x. Only LSP `workspace/configuration` is read. Wasted time discovering this through trial.
3. **Running nil + nixd simultaneously** -- Adds complexity and potential diagnostic conflicts without clear benefit when nixd is properly configured alone.

## Solution

### 1. Switch nil to nixd in Zed languages block

**Before:**
```json
"Nix": {
  "language_servers": ["nil", "!nixd"]
}
```

**After:**
```json
"Nix": {
  "language_servers": ["nixd", "!nil"],
  "formatter": { "language_server": { "name": "nixd" } },
  "format_on_save": "on",
  "show_edit_predictions": true,
  "show_whitespaces": "selection"
}
```

### 2. Configure nixd with flake evaluation expressions

**Before:**
```json
"lsp": {
  "nil": {
    "initialization_options": {
      "formatting": { "command": ["nixfmt"] }
    }
  }
}
```

**After:**
```json
"lsp": {
  "nixd": {
    "settings": {
      "formatting": { "command": ["nixfmt"] },
      "nixpkgs": {
        "expr": "import (builtins.getFlake \"/Users/hj/dot/nix-dots\").inputs.nixpkgs { }"
      },
      "options": {
        "darwin": {
          "expr": "(builtins.getFlake \"/Users/hj/dot/nix-dots\").darwinConfigurations.workspace_hj.options"
        },
        "home-manager": {
          "expr": "(builtins.getFlake \"/Users/hj/dot/nix-dots\").darwinConfigurations.workspace_hj.options.home-manager.users.type.getSubOptions []"
        }
      },
      "diagnostic": { "suppress": ["sema-extra-with"] }
    }
  }
}
```

### 3. Add devShell + .envrc to complete direnv pipeline

**flake.nix:**
```nix
devShells.aarch64-darwin.default =
  let
    pkgs = import nixpkgs { system = "aarch64-darwin"; };
  in
  pkgs.mkShell {
    packages = with pkgs; [ nixd nixfmt ];
  };
```

**.envrc (project root):**
```
use flake .
```

**.gitignore:**
```
.direnv
```

## Why This Works

- **nil vs nixd architecture:** nil is parser-based (syntax analysis only). nixd links against the official Nix C++ libraries (libexpr, libstore) and performs real evaluation to extract type information.
- **`nixpkgs.expr`** gives nixd the evaluated nixpkgs attrset for `pkgs.*` completion (350k+ packages).
- **`options.darwin.expr`** provides all nix-darwin system option paths with documentation.
- **`options.home-manager.expr`** uses `type.getSubOptions []` to extract the home-manager submodule options from the `attrsOf submodule` type.
- **devShell + .envrc** completes a 3-stage pipeline that was 2/3 built: nix-direnv (enabled) -> direnv (enabled) -> Zed `load_direnv: "shell_hook"` (configured). The missing piece was `.envrc` + devShell.
- **`sema-extra-with`** is suppressed because `with pkgs; [...]` is idiomatic Nix but triggers false positive warnings in nixd.

## Prevention

1. **nil vs nixd choice:** Always verify whether your Nix LSP supports flake evaluation before configuring it. nil cannot; nixd can. Choose based on whether you need option/attribute completion.
2. **nixd v2.x configuration:** `.nixd.json` is deprecated. Configuration must go through the editor's LSP `workspace/configuration` mechanism (Zed: `lsp.nixd.settings`, VS Code: `settings.json`, Neovim: `lspconfig`).
3. **Test expressions in nix repl first:**
   ```bash
   nix repl
   nix-repl> (builtins.getFlake "/path/to/flake").darwinConfigurations.HOST.options
   ```
4. **Complete the direnv pipeline:** If using `load_direnv` in your editor, all three pieces must exist: (a) nix-direnv enabled, (b) `.envrc` at project root, (c) devShell in flake.
5. **First use:** Run `direnv allow` after creating `.envrc`. nixd's initial flake evaluation takes 10-30 seconds but is cached afterwards.

## Related

- [Ideation: Nix Zed LSP DX](../../ideation/2026-03-26-nix-zed-lsp-ideation.md) -- full ideation analysis with 7 ranked ideas, 3 applied
- [nixd GitHub](https://github.com/nix-community/nixd) -- v2.9.0 configuration docs
- [Zed nix extension](https://github.com/zed-extensions/nix) -- forwards `lsp.nixd.settings` via `workspace_configuration`
