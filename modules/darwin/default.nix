{ pkgs, ... }:
{
  config = {
    fonts = {
      fontDir.enable = true;
      fonts = with pkgs; [
        (nerdfonts.override {
          fonts = [
            "D2Coding"
            "JetBrainsMono"
          ];
        })
      ];
    };
  };
}
