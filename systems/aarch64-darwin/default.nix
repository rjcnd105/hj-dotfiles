{
  lib,
  config,
  myOptions,
  ...
}:
{
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
