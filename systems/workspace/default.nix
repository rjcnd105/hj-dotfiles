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
    LANG = "ko_KR.UTF-8";
    SHELL = "/etc/profiles/per-user/${customConfig.userName}/bin/nu";
  };
in
{


  imports = [
    inputs.nix-index-database.darwinModules.nix-index
  ];

  config = {
    environment.systemPackages = [
      inputs.comma
    ];

    environment.variables = variables;

    # system.activationScripts.postActivation.text = ''
    #   # 현재 셸의 모든 환경변수를 launchctl에 설정
    #   for var in $(env | cut -d= -f1); do
    #     /bin/launchctl setenv "$var" "''${!var}"
    #   done
    # '';

    # system.activationScripts.postActivation.text = ''
    #    ${pkgs.nushell}/bin/nu -c '
    #      if (ls /etc/agenix/ | length) > 0 {
    #        sudo chown ${myvars.username} /etc/agenix/*
    #      }
    #    '
    #  '';

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
