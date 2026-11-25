{
  inputs,
  pkgs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
in
{
  home.packages = [
    pkgs.nixd
    pkgs.nix-prefetch-git
    inputs.self.formatter.${system}
  ];
}
