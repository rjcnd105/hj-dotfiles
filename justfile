# nix가 설치되어 있지 않다면
nix_instll:
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

setup_hj-workspace:
    nix build .#darwinConfigurations.hj@workspace
    ./result/sw/bin/darwin-rebuild switch
