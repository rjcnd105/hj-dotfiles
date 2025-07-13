set shell := ["zsh", "-cu"]

home_dir := env_var('HOME')
timestamp := `date '+%y%m%d_%H%M%S'`


root_dir := absolute_path(justfile_directory())
export PWD := root_dir


default:
  @just --choose

# nix가 설치되어 있지 않다면
nix_instll:
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

build_hj-workspace:
    set -euo pipefail
    source {{root_dir}}/createEnv.sh
    nix build .#darwinConfigurations.workspace_hj.system --show-trace --impure --fallback --experimental-features "nix-command flakes"

darwin-switch:
    set -euo pipefail
    source {{root_dir}}/createEnv.sh
    ./result/sw/bin/darwin-rebuild switch --flake .#workspace_hj --show-trace --impure --fallback


# new-darwin-switch:
#     set -euo pipefail
#     source {{root_dir}}/createEnv.sh
#     ./result/sw/bin/darwin-rebuild activate


switch-from-github:
    nix run nix-darwin -- switch --flake github:rjcnd105/hj-dotfiles#workspace_hj --impure

mkEnv:
    source ./createEnv.sh

flake_update:
    @nix flake update

repl:
    @nix repl . --debugger

repl-flake:
    @nix repl --expr "builtins.getFlake \"{{root_dir}}\"" --debugger
