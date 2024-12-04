{
  config,
  pkgs,
  inputs,
  customConfig,
  ...
}:
let
  variables = {
    EDITOR = "zed";
    SHELL = "nu";
    LANG = "ko_KR.UTF-8";
  };
in
{
  imports = [
    inputs.nix-index-database.darwinModules.nix-index
    inputs.determinate.darwinModules.default
  ];

  config = {

    users.users.${customConfig.userName} = {
      shell = pkgs.nushell;
    };
    environment.systemPackages = [
      inputs.comma
    ];
    environment.variables = variables;

    environment.shells = [
      pkgs.bashInteractive
      pkgs.zsh
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
      extraSpecialArgs = {

        inherit inputs;
        customConfig = {
          environment.variables = variables;
        } // customConfig;
      };
    };
  };

}
