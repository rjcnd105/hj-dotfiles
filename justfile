home_dir := env_var('HOME')
timestamp := `date '+%y%m%d_%H%M%S'`
backup_folder := home_dir + "/nix_backup/" + timestamp

default:
  @just --choose
# nix가 설치되어 있지 않다면
nix_instll:
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

build_hj-workspace:
    nix build .#darwinConfigurations.hj@workspace.system

darwin-switch:
    ./result/sw/bin/darwin-rebuild switch --flake .#hj@workspace

_flake_update:
    @nix flake update

_before-conf:
    # 백업 디렉토리 생성
    mkdir -p "{{backup_folder}}/nix"
    mkdir -p "{{backup_folder}}/bash"

    # 백업
    cp -r /etc/nix/nix.conf "{{backup_folder}}/nix/nix.conf.backup"
    cp -r /etc/bash.bashrc "{{backup_folder}}/bash/bashrc.backup"

_remove_before_conf:
    rm -rf /etc/nix/nix.conf
    rm -rf /etc/bash.bashrc
