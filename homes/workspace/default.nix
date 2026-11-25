{ lib, pkgs, ... }:
{
  imports = [
    ../file.nix
    ./home-config.nix
    ./ssh-config.nix
    ./sops.nix
    ./pi.nix
    ./hindsight.nix
    ./worktrunk.nix
    ../../sharedHome/cli
    ../../sharedHome/development
    ../../sharedHome/development/lspmux.nix
  ];

  home.packages = [
    pkgs.docker-client
    pkgs.docker-compose
  ];

  programs.ssh.settings = {
    homelab = {
      HostName = "ssh.deopjib.cc";
      User = "hj";
      ProxyCommand = "${lib.getExe pkgs.cloudflared} access ssh --hostname %h";
    };
    homelab-lan = {
      HostName = "192.168.0.5";
      User = "hj";
    };
  };
}
