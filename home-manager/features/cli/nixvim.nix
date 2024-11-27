{ nixvim, ... }: {
  imports = [
    nixvim.homeManagerModules.nixvim
  ];
  programs.nixvim = {
    plugins = {
      lualine.enable = true;
      bufferline.enable = true;
      web-devicons.enable = true;
    };
  };
}
