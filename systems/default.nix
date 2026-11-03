{
  pkgs,
  inputs,
  myOptions,
  ...
}:
{

  config = {

    # 원격 접속 공통 경로: Tailscale이 기기 간 경로를, Mosh가 끊김에 강한 터미널 세션을 맡는다.
    # 기기 등록은 호스트마다 `sudo tailscale up`을 한 번 실행한다.
    services.tailscale.enable = true;
    environment.systemPackages = [ pkgs.mosh ];

    users.users.${myOptions.userName}.openssh.authorizedKeys.keys = [
      # workspace 맥
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIRZWjotRmcM4XUoYrxI2YVdpCyg+XI3wKmB15Hiifgy"
      # iPhone Moshi
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICUB++mLHDtGJQzI68/UMofBKi1J+CgmmMp+E1SmxzWh moshi"
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

    # nerd-fonts list
    # https://github.com/NixOS/nixpkgs/blob/master/pkgs/data/fonts/nerd-fonts/manifests/fonts.json
    fonts.packages = [
      pkgs.sarasa-gothic
      pkgs.nerd-fonts.d2coding
      pkgs.nerd-fonts.jetbrains-mono
    ];
  };
}
