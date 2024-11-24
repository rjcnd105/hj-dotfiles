{ pkgs, lib, ... }:
{
  imports = [
    ../features/cli/common.nix
    ../features/cli/additional.nix
  ];

  manual.html.enable = true;
}
