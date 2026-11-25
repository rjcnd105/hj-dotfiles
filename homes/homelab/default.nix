{ pkgs, ... }:
{
  imports = [
    ../file.nix
    ../workspace/home-config.nix
    ../workspace/ssh-config.nix
    ../workspace/sops.nix
    ../../sharedHome/cli
    ../../sharedHome/development
  ];

  # Claude Code는 공식 설치본 사용 (새 호스트: curl -fsSL https://claude.ai/install.sh | bash)
  home.packages = [
    pkgs.beamPackages.erlang
    pkgs.beamPackages.elixir
    pkgs.python3
    pkgs.nodejs_24
    pkgs.rustc
    pkgs.cargo
    pkgs.gleam
    pkgs.zig
    pkgs.bun
    pkgs.usage
  ];
}
