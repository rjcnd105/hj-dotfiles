{ config, pkgs, ... }:
let
  users = import ../../config/users.nix;
  home_info = import ../home-share-info.nix;
in
{
  imports = [
    ../../features/system/basic.nix
    ../../features/system/nix.nix
    ../../features/system/users.nix
  ];

  home = {
    username = users.default;
    homeDirectory = "/home/${users.default}";
    stateVersion = home_info.stateVersion;
  };
}
