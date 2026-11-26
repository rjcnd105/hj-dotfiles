set shell := ["zsh", "-cu"]

root_dir := absolute_path(justfile_directory())

default:
  @just --choose

install-nix:
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

build_hj-workspace:
    nix build .#darwinConfigurations.workspace_hj.system --show-trace --fallback --experimental-features "nix-command flakes"

check:
    nix flake check --all-systems --no-build --show-trace

fmt:
    nix fmt

darwin-switch:
    #!/usr/bin/env zsh
    set -euo pipefail
    export PATH="/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin:$PATH"
    nix_bin="$(command -v nix)"
    nix_env_bin="$(command -v nix-env)"
    build_args=(build .#darwinConfigurations.workspace_hj.system --no-link --print-out-paths --show-trace --fallback --experimental-features "nix-command flakes")
    if [[ $EUID -eq 0 && -n ${SUDO_USER:-} ]]; then
      system_config="$(sudo -H -u "$SUDO_USER" "$nix_bin" "${build_args[@]}")"
    else
      system_config="$("$nix_bin" "${build_args[@]}")"
    fi
    [[ -x $system_config/sw/bin/darwin-rebuild ]]
    if [[ $EUID -eq 0 ]]; then
      root_home=~root
      HOME="$root_home" NIX_REMOTE=daemon "$nix_env_bin" -p /nix/var/nix/profiles/system --set "$system_config"
      "$system_config/sw/bin/darwin-rebuild" activate
    else
      sudo -H env NIX_REMOTE=daemon "$nix_env_bin" -p /nix/var/nix/profiles/system --set "$system_config"
      sudo "$system_config/sw/bin/darwin-rebuild" activate
    fi

switch-from-github:
    nix run nix-darwin -- switch --flake github:rjcnd105/hj-dotfiles#workspace_hj

eval_hj-homelab:
    nix eval .#nixosConfigurations.homelab_hj.config.networking.hostName

repl:
    @nix repl . --debugger

repl-flake:
    @nix repl --expr "builtins.getFlake \"{{root_dir}}\"" --debugger
