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
    # ../../sharedHome/app
  ];

  home.packages = with pkgs; [
    docker-client
    docker-compose
  ];

  # homelab 원격 접속: Cloudflare Tunnel + Access(이메일 OTP), 라우터 인바운드 포트 0개.
  # 재인증 주기는 Cloudflare Access 앱(Homelab SSH)의 세션 길이가 정한다.
  # homelab-lan은 터널/Access 장애 시 집 안에서 쓰는 LAN 직결 폴백.
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
