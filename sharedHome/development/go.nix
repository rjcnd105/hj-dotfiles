{ pkgs, ... }:
{
  home.packages = with pkgs; [
    go
    gopls
    gofumpt
    golangci-lint
    delve
  ];
}
