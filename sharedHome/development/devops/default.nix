{ pkgs, ... }:
{
  imports = [
    ./nixpkgs.nix
  ];

  home.packages = with pkgs; [
    fluxcd
    # redis
  ];
}
