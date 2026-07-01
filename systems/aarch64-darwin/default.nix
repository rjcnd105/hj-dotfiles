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
