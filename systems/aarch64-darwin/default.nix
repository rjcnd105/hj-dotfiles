{ lib, config, ... }:
{
  environment.systemPath = [ "/opt/homebraw/bin" ];
  config.system.stateVersion = 6;
}
