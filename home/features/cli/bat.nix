{
  programs.bat = {
    enable = true;
    config = {
      theme = "Catppuccin Mocha";
    };
    extraPackages = [ ];
    aliases = {
      cat = "bat --style=plain --paging=never";
    };
  };
}
