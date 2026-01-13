# Project Context

## Architecture
- **Type**: Nix Flake Dotfiles (nix-darwin + home-manager)
- **Structure**:
  - `flake.nix`: Entry point. Maps `darwinConfigurations` to `systems/`.
  - `systems/workspace/default.nix`: System-level config (nix-darwin).
    - Enables `homebrew` (packages likely managed in specific modules or separate casks file).
    - Configures `nix` (disabled, assumes Determinate Systems daemon).
    - Adds binary caches (`devenv`, `jdx`).
    - Enables TouchID for sudo.
  - `homes/workspace/default.nix`: User entry point. Imports `sharedHome/{cli,development}`.
  - `sharedHome/`: Domain-specific modules.
    - `cli/`: `git`, `fish`, `gh`, `alacritty`, etc.
    - `development/`: `devops` (nixpkgs config), etc.
    - `app/`: GUI apps (e.g., `espanso`).
  - `.jj/`: Jujutsu VCS config (`trunk()` -> `main@origin`, git conflicts).

## Key Technologies
- **System**: MacOS (aarch64-darwin).
- **Package Manager**: Nix (Flakes) + Homebrew (enabled).
- **Shell**: Fish (managed in `sharedHome/cli/shell/fish.nix`).
  - `vim` mode enabled.
  - Custom functions in `~/.config/fish/user-functions.fish`.
- **Dev Tools**: Mise, Devenv, Just, Sops-nix.
- **Theme**: Catppuccin (Macchiato) applied globally via Home Manager module.

## Commands (Justfile)
- **Build**: `just build_hj-workspace`
- **Apply**: `just darwin-switch`
- **Update**: `just flake_update`
- **REPL**: `just repl`
- **Install**: `nix install` (determinate systems)

## Workflow & Conventions
- **VCS**: Jujutsu (jj) with git backing.
  - Commits: Concise, lowercase (e.g., "update configs").
  - Branching: Feature branches (e.g., `switch-alacritty-to-ghostty`).
- **Secrets**: `sops-nix` with `age` encryption.
  - Key: `~/.config/sops/age/keys.txt` (inferred from `keys.txt` pattern usually).
  - Config: `.sops.yaml` defines `secrets/workspace/` and `secrets/shared/` scopes.
- **Environment**: `createEnv.sh` sourced before build commands.

# User Context

## Profile
- **Role**: Frontend Developer (React/TS, 6y+ exp).
- **Interests**: FP (Elixir, Gleam, Haskell), Category Theory, Nix, BEAM.
- **Language**: Korean / English.

## Preferences
- **Communication**: Terse / Minimal (High density).
- **Technical Depth**: High. Prefer mathematical/theoretical context (Category Theory, Type Theory).
- **Tooling**: Strong preference for Nix-based workflows.

## Known Issues / Patterns
- **Alacritty -> Ghostty**: Cancelled (Not supported in Nix/Mise yet).
- **System Updates**: `nix.enable = false` in darwin config (managed externally).
- **Caches**: Relies on `devenv.cachix.org` and `jdx.cachix.org`.
