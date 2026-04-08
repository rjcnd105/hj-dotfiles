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
  services.llama-cpp = {
    enable = true;
    host = "0.0.0.0";
    port = 8080;
  };

  # comin — GitOps: GitHub main 브랜치를 poll하여 자동 nixos-rebuild switch
  services.comin = {
    enable = true;
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
