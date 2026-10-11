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
    ".pi/agent/claude-bridge.json" = link "claude-bridge.json";
    # Pi reads one context file from its agent directory, so the APM-generated
    # shared guide takes AGENTS.md and Pi-specific rules use APPEND_SYSTEM.md.
    ".pi/agent/AGENTS.md" = {
      source = config.lib.file.mkOutOfStoreSymlink "${workspace}/.codex/AGENTS.md";
      force = true;
    };
    ".pi/agent/APPEND_SYSTEM.md" = link "APPEND_SYSTEM.md";
    ".pi/agent/mcp.json" = link "mcp.json";
    ".pi/agent/pi-vcc-config.json" = link "pi-vcc-config.json";
    ".pi/agent/extensions/subagent/config.json" = link "extensions/subagent/config.json";
    ".pi/agent/skills/analyze-sessions" = link "skills/analyze-sessions";
  };
}
