{
  lib,
  config,
  myOptions,
  ...
}:
{
  services.openssh = {
    enable = true;
    # 맥은 외부 네트워크에도 나가므로 sshd를 키 인증으로만 연다.
    # SSH 세션에는 LANG이 없어 CLI가 C 로케일로 떨어지므로 UTF-8을 넣어 준다.
    extraConfig = ''
      PasswordAuthentication no
      KbdInteractiveAuthentication no
      PermitRootLogin no
      SetEnv LANG=en_US.UTF-8
    '';
  };

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
