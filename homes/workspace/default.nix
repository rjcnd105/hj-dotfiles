{
  config,
  lib,
  pkgs,
  ...
}:
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

  # Homelab 관리용 SSH 호스트/LAN IP는 공개 설정에 두지 않고 sops 템플릿으로
  # ~/.ssh/config.d/homelab.conf에 렌더링한다(ssh-config.nix가 Include).
  sops.secrets = {
    HOMELAB_SSH_HOST.mode = "600";
    HOMELAB_LAN_IP.mode = "600";
  };

  sops.templates."ssh-homelab.conf" = {
    path = "${config.home.homeDirectory}/.ssh/config.d/homelab.conf";
    mode = "600";
    content = ''
      Host homelab
        HostName ${config.sops.placeholder.HOMELAB_SSH_HOST}
        User hj
        ProxyCommand ${lib.getExe pkgs.cloudflared} access ssh --hostname %h

      Host homelab-lan
        HostName ${config.sops.placeholder.HOMELAB_LAN_IP}
        User hj
    '';
  };
}
