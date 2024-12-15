{ myOptions, ... }:
{

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  nix.settings.trusted-users = [
    "root"
    myOptions.userName
  ];
}
