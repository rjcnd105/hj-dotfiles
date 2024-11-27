{ pkgs, host, config, host, ... }:
{
  environment.systemPath = [
    "${config.home.profileDirectory}/bin"
  ];
}
