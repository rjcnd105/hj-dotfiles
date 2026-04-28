set shell := ["zsh", "-cu"]

home_dir := env_var('HOME')
timestamp := `date '+%y%m%d_%H%M%S'`


root_dir := absolute_path(justfile_directory())


default:
  @just --choose

# nix가 설치되어 있지 않다면
nix_instll:
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

build_hj-workspace:
    nix build .#darwinConfigurations.workspace_hj.system --show-trace --fallback --experimental-features "nix-command flakes"

check:
    nix flake check --all-systems --no-build --show-trace

fmt:
    nix fmt

darwin-switch:
    darwin-rebuild switch --flake .#workspace_hj --show-trace --fallback

switch-from-github:
    nix run nix-darwin -- switch --flake github:rjcnd105/hj-dotfiles#workspace_hj

eval_hj-homelab:
    nix eval .#nixosConfigurations.homelab_hj.config.networking.hostName

flake_update:
    @nix flake update

repl:
    @nix repl . --debugger

repl-flake:
    @nix repl --expr "builtins.getFlake \"{{root_dir}}\"" --debugger
