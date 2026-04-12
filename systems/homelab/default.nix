{
  pkgs,
  myOptions,
  ...
}:
{

  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "homelab";

  # Docker
  virtualisation.docker.enable = true;

  # llama.cpp — CPU 모드로 시작. GPU 가속은 ROCm gfx1150 공식 지원 후 추가
  # 로컬 전용 바인딩. 외부 접근이 필요하면 host를 0.0.0.0으로 변경하고 firewall에 8080 추가
  services.llama-cpp = {
    enable = true;
    host = "127.0.0.1";
    port = 8080;
  };

  # comin — GitOps: GitHub main 브랜치를 poll하여 자동 nixos-rebuild switch
  services.comin = {
    enable = true;
    hostname = "homelab_hj";
    remotes = [
      {
        name = "origin";
        url = "https://github.com/rjcnd105/hj-dotfiles.git";
        branches.main.name = "main";
      }
    ];
  };

  environment.systemPackages = with pkgs; [
    devenv
  ];
}
