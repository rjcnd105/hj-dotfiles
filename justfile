# nix가 설치되어 있지 않다면
nix_instll:
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

setup_hj-workspace:
    nix run .#darwinConfigurations.hj@workspace.system -- switch
