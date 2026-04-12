{
  pkgs,
  inputs,
  myOptions,
  ...
}:
{

  config = {

    environment.variables = {
      USER = myOptions.userName;
      SYSTEM = myOptions.system;
      USER_HOST = myOptions.hostName;
    };

    home-manager = {
      useUserPackages = true;
      useGlobalPkgs = true;
      backupFileExtension = "backup";
      sharedModules = [
        inputs.sops-nix.homeManagerModules.sops
      ];
      extraSpecialArgs = {
        inherit inputs myOptions;
      };
    };

    # nerd-fonts list
    # https://github.com/NixOS/nixpkgs/blob/master/pkgs/data/fonts/nerd-fonts/manifests/fonts.json
    fonts.packages = [
      pkgs.nerd-fonts.d2coding
      pkgs.nerd-fonts.jetbrains-mono
    ];
  };
}
