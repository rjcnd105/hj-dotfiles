{
  programs.alacritty = {
    enable = true;
    settings = {
      import = [
        "~/.config/alacritty/alacritty.toml"
      ];
    };
  };
}
