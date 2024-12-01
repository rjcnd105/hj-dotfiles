# modules/darwin/fonts.nix
{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.system.fonts;
in
{
  options.${namespace}.system.fonts = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable custom fonts";
    };
    fonts = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      description = "Additional Nerd Fonts to install";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.variables = {
      LOG_ICONS = "true";
    };
    # _ = builtins.trace "config" config;
    fonts = {
      fontDir.enable = true;
      fonts = with pkgs; [
        (nerdfonts.override {
          fonts = [
            "D2Coding"
            "JetBrainsMono"
          ] ++ cfg.fonts;
        })
      ];
    };
  };
}
