{
  pkgs,
  inputs,
  lib,
  customConfig,
  ...
}:
{
  programs.nixvim = {
    enable = true;
    # https://github.com/redyf/Neve/blob/main/config/default.nix
    imports = [ inputs.Neve.nixvimModule ];

    colorschemes.enable = false;

    filetrees.enable = true;
  };
}
