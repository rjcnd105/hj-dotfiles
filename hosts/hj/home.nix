{ config, pkgs, ... }:
let
  users = import ../../config/users.nix;
  home_info = import ../home-share-info.nix;
in
{
  imports = [
    ../../home/flavors/desktop/minimal
  ];

  home = {
    username = users.work;
    homeDirectory = "/Users/${users.work}";
    stateVersion = home_info;
    sessionPath = [
      "/opt/homebrew/bin"
    ];
    sessionVariables = {
      SHELL = "/opt/homebrew/bin/bash";
    };
    packages = with pkgs; [
      tesseract
      postgresql
    ];
  };
}
