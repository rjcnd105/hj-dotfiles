{ pkgs, ... }:
{
  programs.mise = {
    enable = true;
    package = pkgs.mise;
    enableFishIntegration = true;
    globalConfig = {
      tools = {

      };
    };
  };
}
