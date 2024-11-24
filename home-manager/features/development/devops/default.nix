{ pkgs, ... }:
{
  imports = [
    ./docker.nix
    ./docker-compose.nix
    ./postgres.nix
  ];
  home.packages = with pkgs; [
    teleport
    fluxcd
    vault
    redis
  ];
}
