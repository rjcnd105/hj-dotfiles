{ pkgs, ... }:
{
  programs.helix = {
    enable = true;

    package = pkgs.helix;

    extraPackages = with pkgs; [
      nil # lsp
    ];
  };
}
