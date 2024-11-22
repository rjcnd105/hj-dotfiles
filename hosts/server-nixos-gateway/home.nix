{ config, pkgs, ... }:
let
  hosts = import ../../config/hosts.nix;
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
    homeDirectory = "/home/${hosts.gateway.user}";
    stateVersion = home_info.stateVersion;
  };
}
