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

    imports = [
      inputs.Neve.nixvimModule
    ];

    filetrees = true;
  };
}
