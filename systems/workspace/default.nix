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
    SHELL = "/etc/profiles/per-user/${customConfig.userName}/bin/zsh";
    LANG = "ko_KR.UTF-8";
  };
in
{
  imports = [
    inputs.nix-index-database.darwinModules.nix-index
  ];

  config = {

    users.users.${customConfig.userName} = {
      shell = pkgs.nushell;
    };
    environment.systemPackages = [
      inputs.comma
      pkgs.devenv
    ];
    environment.variables = variables;

    environment.shells = [
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
