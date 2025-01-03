{ pkgs, ... }:
{
  imports = [
    ./nixpkgs.nix
  ];

  home.packages = with pkgs; [
    teleport
    fluxcd
    # redis
  ];
}
