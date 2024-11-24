{ config, pkgs, ... }:
let
  hosts = import ../../config/hosts.nix;
  info = import ../../config/info.nix;
in
{
  imports = [
    ../../home-manager/presets/workspace.nix
  ];

  home = {
    username = hosts.user;
    homeDirectory = "/Users/${hosts.user}";
    stateVersion = info.home-manager.stateVersion;
  };
}
