{ config, myOptions, ... }:
let
  piConfig = "${myOptions.absoluteProjectPath}/files/workspace/.config/pi";
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
    ".pi/agent/AGENTS.md" = link "AGENTS.md";
    ".pi/agent/mcp-adapter.json" = link "mcp-adapter.json";
    ".pi/agent/interactive-shell.json" = link "interactive-shell.json";
    ".pi/agent/pi-vcc-config.json" = link "pi-vcc-config.json";
    ".pi/agent/extensions/subagent/config.json" = link "extensions/subagent/config.json";
    ".pi/agent/extensions/prompt-snippets" = link "extensions/prompt-snippets";
    ".pi/agent/skills/analyze-sessions" = link "skills/analyze-sessions";
  };
}
