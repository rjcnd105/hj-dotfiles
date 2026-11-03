{ lib, pkgs, ... }:
let
  enableSecrets = builtins.getEnv "ENABLE_SECRETS" != "0";
in
{
  imports = [
    ../file.nix
    ../workspace/home-config.nix
    ../workspace/ssh-config.nix
    ../../sharedHome/cli
    ../../sharedHome/development
  ]
  ++ lib.optional enableSecrets ../workspace/sops.nix;

  # Claude Code는 자동 업데이트로 latest를 따르도록 Nix 패키지 대신 공식 설치본을 쓴다.
  # 새 호스트: curl -fsSL https://claude.ai/install.sh | bash (nix-ld는 systems/homelab에서 켠다)
  home.packages = with pkgs; [
    # 개발 런타임 — workspace에서는 mise로 관리하지만 homelab은 Nix 패키지 사용
    # top-level erlang/elixir은 deprecated. beamPackages.* 와 outPath 동일.
    beamPackages.erlang
    beamPackages.elixir
    python3
    nodejs_24
    rustc
    cargo
    gleam
    zig
    bun
    usage
  ];
}
