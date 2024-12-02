{ pkgs, ... }:
{
  imports = [
    ./python.nix
  ];
  home.packages = with pkgs; [
    lua
  ];
}
