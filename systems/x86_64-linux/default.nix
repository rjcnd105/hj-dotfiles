{
  pkgs,
  myOptions,
  ...
}:
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # comin GitOps는 main push마다 세대를 만든다. 상한이 없으면 커널/initrd가
  # /boot(487M)를 채운다 — nix.gc 주기와 무관하게 부팅 엔트리를 직접 제한한다.
  boot.loader.systemd-boot.configurationLimit = 10;

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      # PasswordAuthentication=no만으로는 PAM 경유 keyboard-interactive 비밀번호
      # 경로가 남는다 — 무차별 대입 로그의 "Failed keyboard-interactive/pam"이 그 증거.
      KbdInteractiveAuthentication = false;
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
      "podman"
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

  system.stateVersion = "26.05";
}
