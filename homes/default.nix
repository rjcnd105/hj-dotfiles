{ config, pkgs, myOptions, ... }:
{

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
  home.homeDirectory =
    if pkgs.stdenv.isDarwin then "/Users/${myOptions.userName}" else "/home/${myOptions.userName}";


}
