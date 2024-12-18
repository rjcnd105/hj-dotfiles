{ config, ... }:
{
  programs.wezterm = {
    enable = true;
    extraConfig = ''
      return {
        default_prog = { "${config.home.profileDirectory}/bin/nu", "--login" },
        font = wezterm.font "D2CodingLigature Nerd Font",
        font_size = 13.0,
      }
    '';
  };
}
