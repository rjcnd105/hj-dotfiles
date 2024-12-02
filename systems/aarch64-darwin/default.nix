{ lib, config, ... }:
{
  environment.systemPath = [ "/opt/homebrew/bin" ];
  services.nix-daemon.enable = true;
}
