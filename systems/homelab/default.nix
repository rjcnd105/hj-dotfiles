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
    ./tailscale-dns.nix
  ];

  homelab.tailscaleDns = {
    enable = true;
    records = {
      # Mac(hj) 로컬 개발 서버에 iPhone 등 tailnet 기기에서
      # https://local.gentlemonster.com 그대로 접속(OAuth·CORS 포함)하기 위한 Split DNS.
      "local.gentlemonster.com" = "100.108.225.30";
    };
  };

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

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 25;
  };

  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5;
    freeMemKillThreshold = 3;
    freeSwapThreshold = 10;
    freeSwapKillThreshold = 5;
    enableNotifications = true;
  };
  systemd.oomd.enable = false;

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    dockerSocket.enable = true;
    defaultNetwork.settings.dns_enabled = true;
  };

  systemd.timers.podman-auto-update.wantedBy = [ "timers.target" ];

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

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
  nix.optimise.automatic = true;

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
    dmidecode
    pciutils
  ];
}
