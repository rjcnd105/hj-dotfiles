{ pkgs, lib, ... }:
{
  imports = [
    ../features/cli/all.nix
    ../features/development/all.nix
    ../fonts
  ];
programs.firefox.enable = false;
  manual.html.enable = true;
}
