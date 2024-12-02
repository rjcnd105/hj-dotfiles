{ pkgs, ... }:
{
  imports = [
    ./docker-compose.nix
    ./nixpkgs.nix
    ./postgres.nix
  ];

  home.packages = with pkgs; [
    teleport
    fluxcd
    vault
    redis
  ];
}
