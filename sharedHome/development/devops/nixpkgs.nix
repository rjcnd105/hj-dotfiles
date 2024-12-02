{ pkgs, ... }:
{
  home.shellAliases = {
    update = "sudo nixos-rebuild switch";
  };
  home.packages = with pkgs; [
    deploy-rs
    nixd
    nix-prefetch-git
    nixfmt-rfc-style
  ];
}
