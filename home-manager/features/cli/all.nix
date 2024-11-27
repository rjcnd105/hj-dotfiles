{ pkgs, lib, ... }:
{
  imports = [
    ./common.nix
    ./additional.nix

    ./catppuccin.nix
    ./fish.nix
    ./rio.nix
    ./nixos.nix
    ./home-manager.nix
    ./git.nix
    ./gh.nix
    ./nixvim.nix
    ./kitty.nix
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
