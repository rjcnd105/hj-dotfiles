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

  home.packages = [
    pkgs.claude-code
  ];
}
