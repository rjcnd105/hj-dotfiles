{
  pkgs,
  ...
}:
{

  imports = [
    ./hardware-configuration.nix
    ./sops.nix
    ./cloudflared.nix
    ./ai-stack.nix
    ./hindsight-stack.nix
    ./recall-eval.nix
  ];

  networking.hostName = "homelab";

  # 정적 IP — ipTIME DHCP 예약 대신 NixOS에서 직접 고정
  networking.interfaces.eno1.ipv4.addresses = [
    {
      address = "192.168.0.5";
      prefixLength = 24;
    }
  ];
  networking.defaultGateway = "192.168.0.1";
  networking.nameservers = [
    "111.118.0.1"
    "111.118.0.11"
  ];

  # zram 스왑 — 압축 RAM 기반 swap. 미사용 시 RAM 소비 ≈ 0.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 25;
  };

  # earlyoom — kswapd livelock 전에 선제 조치 → SSH 유지.
  # systemd-oomd와 중복 방지를 위해 oomd는 비활성.
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5;
    freeMemKillThreshold = 3;
    freeSwapThreshold = 10;
    freeSwapKillThreshold = 5;
    enableNotifications = true;
  };
  systemd.oomd.enable = false;

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
    ghostty.terminfo
    # 메모리/iGPU UMA 실측용 (dmidecode -t memory)
    dmidecode
    # PCI 디바이스 조회 (lspci) — iGPU/NVMe BDF 확인
    pciutils
  ];
}
