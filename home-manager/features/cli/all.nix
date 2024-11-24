{ pkgs, lib, ... }:
{
  imports = [
    ./common.nix
    ./additional.nix

    ./zsh.nix
    ./nixos.nix
    ./home-manager.nix
    ./git.nix
    ./neovim.nix
    ./kitty.nix
    ./delta.nix
    ./bat.nix
    ./neovim.nix
    ./p7zip.nix
    ./ssh.nix
    ./podman.nix
    ./the-fuck.nix
    ./tlrc.nix
    ./zellij.nix
    ./zoxide.nix
    ./zstd.nix
    ./btop.nix
    ./eza.nix
    ./fzf.nix
    ./lazygit.nix
  ];
}
