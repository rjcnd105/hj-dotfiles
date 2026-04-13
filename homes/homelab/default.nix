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
  ] ++ lib.optional enableSecrets ../workspace/sops.nix;

  home.packages = with pkgs; [
    claude-code

    # 개발 런타임 — workspace에서는 mise로 관리하지만 homelab은 Nix 패키지 사용
    erlang
    elixir
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
