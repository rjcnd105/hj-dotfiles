# hj-dotfiles

Personal nix-darwin (`workspace_hj`) and NixOS homelab (`homelab_hj`) flake configuration.

## Configuration Structure

- `flake.nix`: host outputs (`darwinConfigurations`, `nixosConfigurations`), checks, formatter, and devShells.
- `systems/`: NixOS and nix-darwin system modules (`systems/homelab/` for homelab services and app deployment).
- `homes/` and `sharedHome/`: Home Manager modules.
- `files/workspace/`: linked user dotfiles and agent configurations (`~/.config/...`, `.claude/`, `.codex/`, `.agents/`, `.skillshare/`).
- `packages/homelab-appctl/`: host-side app release deploy CLI.
- `docs/guides/` and `docs/solutions/`: operational guides and incident notes.

## Install (macOS)

1. Install Determinate Nix:

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

2. Install [mise](https://mise.jdx.dev/installing-mise.html).
3. First-time bootstrap (`just` and `darwin-rebuild` are installed by the flake):

```bash
nix build .#darwinConfigurations.workspace_hj.system --fallback --experimental-features "nix-command flakes"
sudo ./result/sw/bin/darwin-rebuild switch --flake .#workspace_hj
```

4. Subsequent updates:

```bash
just build_hj-workspace
just darwin-switch
```

## Supported Hosts

- `workspace_hj` (`aarch64-darwin`, macOS via `nix-darwin` + Home Manager)
- `homelab_hj` (`x86_64-linux`, NixOS + `comin` GitOps + Podman/Quadlet)

## Key Tools

- Terminal & Shell: `ghostty`, `fish`, `starship`, `yazi`, `carapace`, `atuin`, `fzf`, `zoxide`, `eza`
- VCS & Dev: `git`, `jj`, `gh`, `lazygit`, `worktrunk`, `helix`, `direnv`, `mise`, `devenv`, `ripgrep`, `fd`, `sd`
- Fonts: `sarasa-gothic`, `nerd-fonts.d2coding`, `nerd-fonts.jetbrains-mono`
- Homelab: `podman`, `quadlet-nix`, `caddy`, `cloudflared`, `postgresql_18`, `ollama-vulkan`, `llama.cpp`, `hindsight`, `beszel`, `restic`
