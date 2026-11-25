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
    linger = true;
  };

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = [ myOptions.userName ];
  };

  # 로그인 셸은 bash로 두고 대화형 세션만 fish로 넘긴다. 로그인 셸이 fish면
  # `ssh homelab '<cmd>'`를 fish가 해석해 에이전트가 쓴 bash 문법이 깨진다.
  programs.fish.enable = true;
  # set-environment가 PATH를 새로 쓰므로 그 뒤에 렌더링되는 loginShellInit에 둔다.
  programs.bash.loginShellInit = ''
    hm_vars=/etc/profiles/per-user/''${USER:-}/etc/profile.d/hm-session-vars.sh
    [ -r "$hm_vars" ] && . "$hm_vars"
    unset hm_vars
  '';
  programs.bash.interactiveShellInit = ''
    if grep -qv fish /proc/$PPID/comm && [[ $SHLVL == [12] ]] && [[ -z ''${BASH_EXECUTION_STRING} ]]; then
      SHELL=${pkgs.fish}/bin/fish exec fish
    fi
  '';

  system.stateVersion = "26.05";
}
