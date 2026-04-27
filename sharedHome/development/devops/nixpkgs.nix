{
  inputs,
  pkgs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
in
{
  home.shellAliases = {
    update = "sudo nixos-rebuild switch";
  };
  home.packages = with pkgs; [
    deploy-rs
    nixd
    nil
    nix-prefetch-git
    inputs.self.formatter.${system}
  ];
}
