{ lib, namespace, ... }:
with lib.${namespace};
{

  system.stateVersion = 5;

  networking = {
    hostName = "hj";
    computerName = "hj";
    localHostName = "hj";
  };

  environment.systemPath = [ "/opt/homebrew/bin" ];

  config.home-manager = {
    useUserPackages = true;
    useGlobalPkgs = true;
  };
}
