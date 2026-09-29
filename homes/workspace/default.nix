{ pkgs, ... }:
{
  imports = [
    ../file.nix
    ./home-config.nix
    ./ssh-config.nix
    ./sops.nix
    ./pi.nix
    ../../sharedHome/cli
    ../../sharedHome/development
    # ../../sharedHome/app
  ];

  home.packages = with pkgs; [
    docker-client
    docker-compose
  ];
}
