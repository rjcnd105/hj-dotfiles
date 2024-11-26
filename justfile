home_dir := env_var('HOME')
timestamp := `date '+%y%m%d_%H%M%S'`

default:
  @just --choose
# nix가 설치되어 있지 않다면
nix_instll:
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

build_hj-workspace:
    nix build .#darwinConfigurations.hj@workspace.system --show-trace

darwin-switch:
    ./result/sw/bin/darwin-rebuild switch --flake .#hj@workspace --show-trace

switch-from-github:
    nix run nix-darwin -- switch --flake github:rjcnd105/hj-dotfiles#hj@workspace

_flake_update:
    @nix flake update
