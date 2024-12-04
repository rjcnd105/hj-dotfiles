{
  config,
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    inputs.nix-index-database.darwinModules.nix-index
    inputs.determinate.darwinModules.default
  ];

  config = {
    environment.systemPackages = [
      inputs.comma
    ];
    environment.variables = {
      EDITOR = "zed";
      SHELL = "nu";
      LANG = "ko_KR.UTF-8";
    };

    environment.shells = [
      pkgs.bashInteractive
      pkgs.nushell
    ];

    home-manager = {
      sharedModules = [
        inputs.nixvim.homeManagerModules.nixvim
        inputs.catppuccin.homeManagerModules.catppuccin
        {
          catppuccin = {
            enable = true;
            flavor = "macchiato";
          };
        }
      ];
    };
  };

}
