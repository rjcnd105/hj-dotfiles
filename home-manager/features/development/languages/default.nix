{ pkgs, ... }:
{
  imports = [
    ./nodejs.nix
    ./python.nix
    ./beam.nix
  ];
  home.packages = with pkgs; [
    lua
  ];
}
