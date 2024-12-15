{ lib, config, ... }:
{
  environment.systemPath = [ "/opt/homebraw/bin" ];
  services.nix-daemon.enable = true;
}
