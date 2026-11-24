{ lib, pkgs, ... }:
let
  # Inkling-2-Mini(inkling2_loop, PR #32694, >= b12600)와 Radeon 890M Vulkan 가속을 위해
  # nixpkgs(v1.0.0/b12359) 대신 최신 b12669로 오버라이드한다.
  # nixpkgs가 b12600+로 올라오면 overrideAttrs를 걷어내고 vulkanSupport override만 남긴다.
  llamaCppBuildNumber = "12669";
  llamaCppBuildCommit = "30ec35a";
  llamaCppLatest = (pkgs.llama-cpp.override { vulkanSupport = true; }).overrideAttrs (old: {
    version = "b${llamaCppBuildNumber}";
    src = pkgs.fetchFromGitHub {
      owner = "ggml-org";
      repo = "llama.cpp";
      tag = "b${llamaCppBuildNumber}";
      hash = "sha256-I9Sc+sLHP7jvzz4bQS5lp49PLC+mWBk7oNMkCHLZ30M=";
    };
    # b12669에서 tools/ui가 ui/apps/chat으로 이동했고, 오프라인 Nix 샌드박스에서는
    # LLAMA_BUILD_UI=OFF + LLAMA_USE_PREBUILT_UI=OFF로 내장 UI 없이 빌드한다.
    nativeBuildInputs = builtins.filter (
      p:
      !(builtins.elem (p.name or "") [
        "npm-config-hook"
        "nodejs"
      ])
      && !(lib.hasPrefix "nodejs-" (p.name or ""))
    ) old.nativeBuildInputs;
    npmDeps = null;
    npmDepsHash = null;
    npmRoot = null;
    preConfigure = "";
    cmakeFlags =
      (builtins.filter (
        f: !(lib.hasPrefix "-DLLAMA_BUILD_NUMBER:" f) && !(lib.hasPrefix "-DLLAMA_BUILD_COMMIT:" f)
      ) old.cmakeFlags)
      ++ [
        (lib.cmakeFeature "LLAMA_BUILD_NUMBER" llamaCppBuildNumber)
        (lib.cmakeFeature "LLAMA_BUILD_COMMIT" llamaCppBuildCommit)
        (lib.cmakeBool "LLAMA_BUILD_UI" false)
        (lib.cmakeBool "LLAMA_USE_PREBUILT_UI" false)
      ];
    doCheck = false;
  });
in
{

  imports = [
    ./hardware-configuration.nix
    ./sops.nix
    ./cloudflared.nix
    ./podman-dns-lifecycle.nix
    ./app-containers.nix
    ./app-admissions.nix
    ./postgres.nix
    ./ollama.nix
    ./github-actions-runner.nix
    ./thermal-alert.nix
    ./operator.nix
    ./comin-notify.nix
    ./backup.nix
    ./beszel.nix
    ./hindsight.nix
  ];

  homelab.hindsight = {
    enable = true;
    server.enable = true;
    dashboard.enable = true;
  };

  homelab.beszel = {
    enable = true;
    agent.enable = true;
  };

  networking.hostName = "homelab";

  # 고정 nameserver를 쓰는 앱·컨테이너 DNS를 MagicDNS가 바꾸지 않게 한다.
  services.tailscale.extraSetFlags = [ "--accept-dns=false" ];

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

  # Podman runtime. dockerCompat keeps the `docker` command mapped to Podman;
  # dockerSocket exposes Podman's Docker-compatible API at /run/docker.sock.
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    dockerSocket.enable = true;
    defaultNetwork.settings.dns_enabled = true;
  };

  systemd.timers.podman-auto-update.wantedBy = [ "timers.target" ];

  # llama.cpp — Radeon 890M Vulkan 가속 활성(b12669, inkling2_loop 지원).
  # 로컬 전용 바인딩. 외부 접근이 필요하면 host를 0.0.0.0으로 변경하고 firewall에 8080 추가
  hardware.graphics.enable = true;
  services.llama-cpp = {
    enable = true;
    package = llamaCppLatest;
    settings = {
      host = "127.0.0.1";
      port = 8080;
    };
  };
  systemd.services.llama-cpp.serviceConfig.SupplementaryGroups = [
    "render"
    "video"
  ];

  # 자동 GC — comin GitOps 박스는 rebuild마다 세대가 쌓인다. 주간 정리 + store 중복 제거.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
  nix.optimise.automatic = true;

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

  # Claude Code 공식 설치본(~/.local/bin/claude)과 자동 업데이트본은 Nix store 밖의
  # 일반 Linux 바이너리이므로 NixOS에서 실행하려면 nix-ld가 필요하다.
  programs.nix-ld.enable = true;

  environment.systemPackages = with pkgs; [
    devenv
    ghostty.terminfo
    llamaCppLatest
    # 메모리/iGPU UMA 실측용 (dmidecode -t memory)
    dmidecode
    # PCI 디바이스 조회 (lspci) — iGPU/NVMe BDF 확인
    pciutils
  ];
}
