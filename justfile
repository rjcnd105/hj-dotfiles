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

darwin-switch:
    darwin-rebuild switch --flake .#workspace_hj --show-trace --fallback

switch-from-github:
    nix run nix-darwin -- switch --flake github:rjcnd105/hj-dotfiles#workspace_hj

build_hj-homelab:
    nix eval .#nixosConfigurations.homelab_hj.config.networking.hostName

flake_update:
    @nix flake update

# recall-eval — upstream gate (manual). Runs the strict probe on homelab and
# pulls the resulting state locally. Exits non-zero on critical regression.
recall-eval-gate:
    #!/usr/bin/env bash
    set -u
    mkdir -p "{{home_dir}}/.local/state/recall-eval"
    ssh homelab 'sudo systemctl start recall-eval-gate.service'
    rc=$?
    just recall-eval-pull-state
    exit $rc

# recall-eval — acknowledge all current alerts (clears Claude hook surface).
# Telegram still fires on future transitions.
recall-eval-ack:
    #!/usr/bin/env bash
    set -u
    ssh homelab 'sudo systemctl start recall-eval-ack.service'
    just recall-eval-pull-state

# recall-eval — pull alert-state.json + history.jsonl tail to local cache.
# Reads via sudo (state dir is 0700 DynamicUser).
recall-eval-pull-state:
    #!/usr/bin/env bash
    set -u
    dir="{{home_dir}}/.local/state/recall-eval"
    mkdir -p "$dir"
    ssh homelab 'sudo cat /var/lib/recall-eval/alert-state.json 2>/dev/null || echo "{}"' > "$dir/alert-state.json"
    ssh homelab 'sudo tail -n 50 /var/lib/recall-eval/history.jsonl 2>/dev/null || true' > "$dir/history.jsonl.tail"
    echo "recall-eval state → $dir"

repl:
    @nix repl . --debugger

repl-flake:
    @nix repl --expr "builtins.getFlake \"{{root_dir}}\"" --debugger
