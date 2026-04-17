{ pkgs, ... }:
{
  # Language Servers — PATH 기반 공통 설치.
  # Claude Code, Helix, Zed(load_direnv/binary override 시), Cursor 등
  # PATH를 존중하는 모든 에디터가 동일 바이너리 사용.
  home.packages = with pkgs; [
    yaml-language-server # YAML LSP
    taplo # TOML LSP (formatter + LSP)
    vscode-langservers-extracted # JSON/HTML/CSS/ESLint LSP 번들
  ];
}
