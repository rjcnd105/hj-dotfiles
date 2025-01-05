{ inputs, pkgs, ... }:
{
  programs.mise = {
    enable = true;
    package = pkgs.mise;
    enableFishIntegration = true;
    enableZshIntegration = true;
  };
}
