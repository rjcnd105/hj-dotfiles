{ pkgs, ... }:
{
  home.packages = [
    (pkgs.callPackage (builtins.fetchTarball {
      url = "https://github.com/peterldowns/nix-search-cli/archive/main.tar.gz";
    }) { })
  ];
}
