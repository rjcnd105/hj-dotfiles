# Claude Code's Bash tool runs bash (CLAUDE_CODE_SHELL in .claude/settings.json).
# Desktop sessions inherit no shell env and import it from this file's snapshot.
if [ -x "$HOME/.local/bin/mise" ]; then eval "$("$HOME/.local/bin/mise" activate bash)"; fi
