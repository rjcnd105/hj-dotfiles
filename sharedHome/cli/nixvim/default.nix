{
  pkgs,
  inputs,
  lib,
  ...
}:
{
  programs.nixvim = {
    enable = true;

    imports = [
      inputs.Neve.nixvimModule
    ];

    filetrees.enable = true;
    copilot.enable = false;
  };
}
