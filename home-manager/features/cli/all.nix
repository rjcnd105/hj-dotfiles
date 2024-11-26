{ pkgs, lib, ... }:
{
  imports = [
    ./fish.nix
    ./common.nix
    ./additional.nix

    ./catppuccin.nix
    ./rio.nix
    ./nixos.nix
    ./home-manager.nix
    ./git.nix
    ./gh.nix
    ./nixvim.nix
    ./delta.nix
    ./bat.nix
    ./ssh.nix
    ./podman.nix
    ./the-fuck.nix
    ./zoxide.nix
    ./btop.nix
    ./eza.nix
    ./fzf.nix
    ./lazygit.nix
  ];
}
