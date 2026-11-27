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

  # Claude Code는 공식 설치본 사용. 새 호스트에서는 버전과 SHA-256을 검증한 뒤 설치한다:
  #   BASE=https://downloads.claude.ai/claude-code-releases
  #   VER=2.1.326 # 최신 버전 확인: curl -fsSL "$BASE/stable"
  #   curl -fsSLO "$BASE/$VER/manifest.json" && curl -fsSLO "$BASE/$VER/linux-x64/claude"
  #   printf '%s  claude\n' "$(jq -r '.platforms["linux-x64"].checksum' manifest.json)" | sha256sum -c -
  #   chmod +x claude && ./claude install "$VER" && rm -f claude manifest.json
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
