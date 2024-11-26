{ pkgs, lib, ... }:
{
  imports = [
    ./common.nix
    ./additional.nix

    ./catppuccin.nix
    ./zsh.nix
    ./nixos.nix
    ./home-manager.nix
    ./git.nix
    ./gh.nix
    ./neovim.nix
    ./kitty.nix
    ./delta.nix
    ./bat.nix
    ./neovim.nix
    ./ssh.nix
    ./podman.nix
    ./the-fuck.nix
    ./fish.nix
    ./zoxide.nix
    ./btop.nix
    ./eza.nix
    ./fzf.nix
    ./lazygit.nix
  ];
}
