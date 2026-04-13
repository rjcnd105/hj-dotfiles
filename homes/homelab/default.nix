{ lib, pkgs, ... }:
let
  enableSecrets = builtins.getEnv "ENABLE_SECRETS" != "0";
in
{
  imports = [
    ../file.nix
    ../workspace/home-config.nix
    ../workspace/ssh-config.nix
    ../../sharedHome/cli
    ../../sharedHome/development
  ] ++ lib.optional enableSecrets ../workspace/sops.nix;

  programs.mise = {
    enable = true;
    enableFishIntegration = true;
  };

  home.packages = [
    pkgs.claude-code
  ];
}
