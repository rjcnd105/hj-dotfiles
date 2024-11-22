{ config, pkgs, ... }:
let
  hosts = import ../../config/hosts.nix;
  home_info = import ../home-share-info.nix;
in
{
  imports = [
    ../../home/flavors/
  ];

  home = {
    username = hosts.user;
    homeDirectory = "/Users/${hosts.user}";
    stateVersion = home_info;
  };
}
