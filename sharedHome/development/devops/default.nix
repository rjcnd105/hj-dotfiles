{ pkgs, ... }:
{
  imports = [
    ./docker-compose.nix
    ./nixpkgs.nix
  ];

  home.packages = with pkgs; [
    teleport
    fluxcd
    vault
    # redis
  ];
}
