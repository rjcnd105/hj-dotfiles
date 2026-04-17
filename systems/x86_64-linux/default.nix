{
  pkgs,
  myOptions,
  ...
}:
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  time.timeZone = "Asia/Seoul";
  i18n.defaultLocale = "ko_KR.UTF-8";

  users.users.${myOptions.userName} = {
    isNormalUser = true;
    home = "/home/${myOptions.userName}";
    extraGroups = [
      "wheel"
      "docker"
    ];
    linger = true; # home-manager systemd user service 부팅 상주
    openssh.authorizedKeys.keys = [
      # 설치 시 SSH 공개키 추가
    ];
  };

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = [ myOptions.userName ];
  };

  programs.fish.enable = true;
  users.defaultUserShell = pkgs.fish;

  system.stateVersion = "25.11";
}
