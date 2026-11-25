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
    sudo darwin-rebuild switch --flake .#workspace_hj --show-trace --fallback

switch-from-github:
    nix run nix-darwin -- switch --flake github:rjcnd105/hj-dotfiles#workspace_hj

eval_hj-homelab:
    nix eval .#nixosConfigurations.homelab_hj.config.networking.hostName

repl:
    @nix repl . --debugger

repl-flake:
    @nix repl --expr "builtins.getFlake \"{{root_dir}}\"" --debugger
