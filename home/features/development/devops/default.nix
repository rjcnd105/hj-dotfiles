{ pkgs, ... }:
{
  imports = [
    ./docker.nix
    ./docker-compose.nix
  ]
  home.packages = with pkgs; [
    teleport
    fluxcd
    vault
    redis
  ];
}
