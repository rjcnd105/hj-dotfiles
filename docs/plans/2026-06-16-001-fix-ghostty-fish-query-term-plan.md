---
title: "fix: Disable fish terminal queries in Ghostty"
type: "fix"
date: "2026-06-16"
---

# fix: Disable fish terminal queries in Ghostty

## Summary

Scope the fish `no-query-term` feature flag to Ghostty-launched fish sessions so interrupted terminal queries stop leaking raw OSC/CSI responses into the prompt. Keep normal fish sessions and existing Ghostty keybindings unchanged.

## Problem Frame

After Ghostty restarted with the repo-managed config, `Ctrl+C` after a running command can leave sequences such as `^[]11;...`, `^[[38;1R`, and `^[[?62;...c` in the fish input buffer. Local fish 4.7.1 documentation says `query-term` writes terminal escape queries and reads responses; it also names `no-query-term` as the workaround for incompatible terminals. This repo already launches Ghostty through a small wrapper, so the least invasive fix is to add the feature flag there rather than changing global fish startup.

## Requirements

- R1. Ghostty-launched fish sessions must report `query-term` as off.
- R2. Non-Ghostty fish sessions must keep their current feature set.
- R3. Existing Ghostty config, split keybindings, `macos-option-as-alt`, and fish shell integration must remain unchanged.
- R4. The change must be carried through the existing Home Manager file-link path, not by editing generated files under the home directory.
- R5. Verification must distinguish terminal-query leakage from the separate `Option+Backspace` CSI-u key sequence.

## Key Technical Decisions

- KTD1. Scope the feature flag in the Ghostty command wrapper: `files/workspace/.config/ghostty/config` already starts fish through the wrapper, and `homes/file.nix` links that config into Ghostty's macOS application-support path.
- KTD2. Do not use universal `fish_features`: `set -Ua fish_features no-query-term` would affect every fish session, while the observed problem is tied to Ghostty restart/config behavior.
- KTD3. Do not change `sharedHome/cli/shell/fish.nix`: global fish setup is shared across terminals and hosts, and this fix only needs the Ghostty launch path.
- KTD4. Treat `^[[127;3u` as a possible follow-up: disabling terminal queries addresses query responses, while CSI-u `Alt+Backspace` handling may still need a fish binding if it remains visible.

## Scope Boundaries

- In scope: Ghostty's fish launch wrapper and verification of the resulting fish feature state.
- Out of scope: broad fish startup refactors, global feature variables, Ghostty keybinding redesign, and changing `macos-option-as-alt`.

## Implementation Units

### U1. Scope `no-query-term` to Ghostty fish

- **Goal:** Make Ghostty-launched fish run with `query-term` disabled without changing global fish behavior.
- **Requirements:** R1, R2, R3, R4
- **Dependencies:** None
- **Files:** `files/workspace/.config/ghostty/ghostty-nix-env.sh`
- **Approach:** Add the fish `--features no-query-term` invocation flag to the existing `exec` line. Leave the wrapper as the only changed runtime path so Home Manager continues linking the same file into both XDG and Ghostty app-support locations.
- **Patterns to follow:** Keep the wrapper minimal and declarative, matching its current single-purpose launch shape.
- **Test scenarios:**
  - Starting fish through the same wrapper reports `query-term` as `off`.
  - Starting fish outside the wrapper keeps the current session feature behavior.
  - The wrapper still starts fish as a login shell.
- **Verification:** A new Ghostty session launches fish successfully, and `status features` in that session shows `query-term off`.

### U2. Verify terminal behavior and separate keybinding follow-up

- **Goal:** Confirm the original raw terminal query leak is gone and avoid folding unrelated CSI-u key handling into this fix.
- **Requirements:** R1, R5
- **Dependencies:** U1
- **Files:** `files/workspace/.config/ghostty/ghostty-nix-env.sh`
- **Approach:** Reproduce the user-facing flow in a fresh Ghostty session after the wrapper change. If OSC/device-attribute/cursor-position responses no longer appear after interrupting commands, close this fix. If `Option+Backspace` still emits `^[[127;3u`, record that as a separate fish binding follow-up rather than expanding this change.
- **Patterns to follow:** Keep verification tied to the live Ghostty path because plain non-interactive fish commands cannot prove terminal input-buffer behavior.
- **Test scenarios:**
  - Interrupting a running command returns to a clean prompt without raw `OSC 11`, cursor-position, or device-attribute response text.
  - `Option+Backspace` behavior is checked separately and classified as fixed, remaining, or unrelated.
- **Verification:** The original `Ctrl+C` symptom no longer reproduces in a fresh Ghostty session; any remaining `^[[127;3u` behavior is tracked separately.

## Sources & Research

- `files/workspace/.config/ghostty/config` already starts Ghostty through the repo-managed wrapper and enables `shell-integration = fish`.
- `homes/file.nix` links the repo-managed Ghostty config into `Library/Application Support/com.mitchellh.ghostty/config`.
- Local fish 4.7.1 docs describe `query-term` as writing escape sequences and reading terminal responses, and list `no-query-term` as the workaround for incompatible terminals.
- Local fish terminal compatibility docs identify cursor-position reports and kitty keyboard protocol as terminal query surfaces, matching the observed raw sequences.
