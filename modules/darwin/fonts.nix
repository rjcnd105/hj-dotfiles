# modules/darwin/fonts.nix
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hm.fonts;
in
{
  options.hm.fonts = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable custom fonts";
    };
    additionalFonts = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      description = "Additional Nerd Fonts to install";
    };
  };

  config = lib.mkIf cfg.enable {
    _ = builtins.trace "config" config;
    fonts = {
      fontDir.enable = true;
      fonts = with pkgs; [
        (nerdfonts.override {
          fonts = [
            "D2Coding"
            "JetBrainsMono"
          ] ++ cfg.additionalFonts;
        })
      ];
    };
  };
}
