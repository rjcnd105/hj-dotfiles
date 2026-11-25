{ config, myOptions, ... }:
let
  workspace = "${myOptions.absoluteProjectPath}/files/workspace";
  piConfig = "${workspace}/.config/pi";
  link = path: {
    source = config.lib.file.mkOutOfStoreSymlink "${piConfig}/${path}";
    force = true;
  };
in
{
  # Pi writes credentials, sessions, package caches, and runtime state beneath
  # ~/.pi/agent. Link only the repository-owned configuration files.
  home.file = {
    ".pi/agent/settings.json" = link "settings.json";
    ".pi/agent/models.json" = link "models.json";
    ".pi/agent/claude-bridge.json" = link "claude-bridge.json";
    # Pi reads one context file from its agent directory, so the shared guide
    # (synced to .config/pi/AGENTS.md by skillshare extras) takes AGENTS.md and
    # Pi-specific rules use APPEND_SYSTEM.md.
    ".pi/agent/AGENTS.md" = link "AGENTS.md";
    ".pi/agent/APPEND_SYSTEM.md" = link "APPEND_SYSTEM.md";
    # skillshare(`sync mcp -p`)가 project 경로인 .pi/mcp.json에 쓴다.
    ".pi/agent/mcp.json" = {
      source = config.lib.file.mkOutOfStoreSymlink "${workspace}/.pi/mcp.json";
      force = true;
    };
    ".pi/agent/pi-vcc-config.json" = link "pi-vcc-config.json";
    ".pi/agent/extensions/subagent/config.json" = link "extensions/subagent/config.json";
    ".pi/agent/skills/analyze-sessions" = link "skills/analyze-sessions";
    ".config/pi/prompts" = link "prompts";
    # `wt config plugins pi install`이 쓰는 파일과 같은 원본을 wt 버전에 맞춰 링크한다.
    ".pi/agent/extensions/worktrunk.ts".source =
      "${config.programs.worktrunk.package.src}/dev/pi-extension.ts";
  };
}
