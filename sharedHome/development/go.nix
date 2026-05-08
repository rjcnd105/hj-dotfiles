{ pkgs, ... }:
{
  home.packages = with pkgs; [
    go
    gofumpt
    golangci-lint
    delve
  ];
}
