{
  inputs,
  myOptions,
  ...
}:
{
  imports = [ ./mise-packages.nix ];

  config = {
    services.tailscale.enable = true;

    users.users.${myOptions.userName}.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIRZWjotRmcM4XUoYrxI2YVdpCyg+XI3wKmB15Hiifgy workspace-mac"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINGPjgrrHOv4rkODcbgTJOnWmQjBLoGttDry7lv12UvM herdr-mobile"
    ];

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
  };
}
