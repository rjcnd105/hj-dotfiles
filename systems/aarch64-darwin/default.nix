{
  pkgs,
  lib,
  config,
  myOptions,
  ...
}:
{
  services.openssh = {
    enable = true;
    # 맥은 외부 네트워크에도 나가므로 sshd를 키 인증으로만 연다.
    # mosh-server는 UTF-8 로케일이 없으면 시작하지 않는데 SSH 세션에는 LANG이 없다.
    extraConfig = ''
      PasswordAuthentication no
      KbdInteractiveAuthentication no
      PermitRootLogin no
      SetEnv LANG=en_US.UTF-8
    '';
  };

  # Nix 빌드 mosh-server는 ad-hoc 서명이라 macOS 방화벽이 자동 허용하지 않고,
  # 허용 규칙은 store 경로에 묶이므로 활성화 때마다 현재 경로를 등록한다.
  system.activationScripts.postActivation.text = ''
    /usr/libexec/ApplicationFirewall/socketfilterfw --add ${pkgs.mosh}/bin/mosh-server >/dev/null
    /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp ${pkgs.mosh}/bin/mosh-server >/dev/null
  '';

  environment.systemPath = [ "/opt/homebrew/bin" ];
  system.stateVersion = 6;

  environment.variables.HOME = "/Users/${myOptions.userName}";
  environment.variables.BRILLIANT_CODEX_PATH = "${
    config.users.users.${myOptions.userName}.home
  }/.cache/.bun/bin/codex";

  # Dock-launched apps need this in the user launchd environment after each login.
  launchd.user.agents.brilliant-environment.serviceConfig = {
    ProgramArguments = [
      "/bin/launchctl"
      "setenv"
      "BRILLIANT_CODEX_PATH"
      config.environment.variables.BRILLIANT_CODEX_PATH
    ];
    RunAtLoad = true;
  };

  networking = {
    hostName = myOptions.userName;
    computerName = myOptions.userName;
    localHostName = myOptions.userName;
  };

  users.users.${myOptions.userName} = {
    name = myOptions.userName;
    home = "/Users/${myOptions.userName}";
  };

  system.primaryUser = myOptions.userName;
  system.defaults.NSGlobalDomain.AppleFontSmoothing = 2;
}
