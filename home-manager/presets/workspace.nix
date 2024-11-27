{ pkgs, lib, ... }:
{
  imports = [
    ../features/cli/all.nix
    ../features/development/all.nix
    ../fonts
  ];
  manual.html.enable = true;
}
