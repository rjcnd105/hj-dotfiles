---
title: "feat: Route editor language servers through lspmux and mise"
type: feat
status: completed
date: 2026-05-07
---

# feat: Route editor language servers through lspmux and mise

## Summary

Configure `lspmux` the Nix way for the workspace user, keep the server lifecycle under Home Manager/launchd, and route Zed/Cursor language-server launches through wrappers that resolve mise-managed tools. Elixir should prefer `elixir-ls` first and `expert` second; `lexical` and `next-ls` stay out of the active editor path.

---

## Requirements

- R1. Install and expose `lspmux` through Nix/Home Manager, not ad hoc Cargo/Homebrew setup.
- R2. Render the macOS `lspmux.plist` shape through Home Manager `launchd.agents`, not a manually copied plist.
- R3. Let GUI editors invoke stable wrapper paths while those wrappers resolve actual LSP binaries through `mise`.
- R4. Configure Elixir tooling order as `elixir-ls` first, `expert` second, with `lexical` and `next-ls` disabled or absent.
- R5. Preserve existing Nix LSP behavior and avoid unrelated editor rewrites.

---

## Scope Boundaries

- Do not replace `mise` as the tool-version owner for language servers.
- Do not broadly update `flake.lock` or Nixpkgs.
- Do not change homelab runtime behavior.
- Do not add a custom non-Nix launchd plist file.

### Deferred to Follow-Up Work

- Removing lexical from non-Cursor VS Code installs is separate because the current request targets workspace Zed/Cursor, and `code` CLI is not available in this shell.

---

## Context & Research

### Current Implementation Snapshot

- `sharedHome/development/lspmux.nix` has already been started in the working copy.
- `sharedHome/development/default.nix` has already been updated to import the lspmux module.
- `files/workspace/.config/mise/config.toml` has already been started with `rust` components and `expert`.
- Runtime probing found `lspmux` in nixpkgs at `0.3.0`, current shell `mise` at `/opt/homebrew/bin/mise`, and `expert` installable through mise at `0.1.4`.
- Runtime probing added missing `rust-analyzer` and `rust-src` rustup components so `mise exec -- rust-analyzer --version` works.

### Relevant Code and Patterns

- `sharedHome/development/lsp.nix` is the existing shared language-server package surface.
- `sharedHome/development/devops/nixpkgs.nix` owns Nix-specific language tooling such as `nixd` and `nil`.
- `files/workspace/.config/zed/settings.json` is the workspace Zed LSP configuration surface.
- `files/workspace/.config/cursor/settings.json` is the Cursor/VS Code-style LSP configuration surface.
- `homes/file.nix` maps `files/workspace` config through out-of-store Home Manager links.

### Institutional Learnings

- `docs/solutions/developer-experience/nix-zed-lsp-nixd-switch-2026-03-26.md` documents that Zed LSP overrides belong under `lsp.<server>.settings` and language blocks, and that `nixd` should remain the flake-aware Nix LSP.
- Prior mise work in this repo separates the repo's Nix-pinned `mise` package from the currently active shell binary; direct `type -a`, `mise exec`, and `nix eval` checks are the reliable truth surfaces.

### External References

- `lspmux` upstream README: server/client split, macOS launchd example, config path, `--server-path`, and `LSPMUX_SERVER`.
- Zed language configuration docs: `lsp.<server>.binary.path`, `arguments`, and `env` are supported for language server binary overrides.
- Cursor/VS Code extension manifests: `elixirLS.languageServerOverridePath`, `rust-analyzer.server.path`, and `expert.server.releasePathOverride` are the relevant override settings.

---

## Key Technical Decisions

- Home Manager owns the `lspmux` daemon: this matches the user's plist-as-Nix requirement and keeps GUI-session startup declarative.
- Wrapper binaries live in the Home Manager profile: editor JSON can use stable absolute paths such as `/etc/profiles/per-user/hj/bin/lspmux-mise-elixir-ls`, while implementation details stay Nix-generated.
- Wrappers call `/opt/homebrew/bin/mise exec -- <server>` by default, with `MISE_BIN` override support: this keeps mise itself outside Home Manager while letting GUI-launched editors use the same mise-managed LSP versions.
- Keep `nixd` outside lspmux for now: it is Nix-owned and already configured for flake-aware completion; the current request is about mise-managed LSPs.

---

## Open Questions

### Resolved During Planning

- Should `lspmux.plist` be copied directly? No. It should be represented with `launchd.agents.lspmux.config`.
- Should Elixir use lexical or next-ls? No. Use `elixir-ls` first, `expert` second.

### Deferred to Implementation

- Exact generated launchd plist output: verify with `nix eval` after finishing the module.
- Whether Zed's Expert binary override starts cleanly through `lspmux`: verify by checking config shape and leave live editor smoke as manual if the editor is not launched during this session.

---

## Implementation Units

### U1. Add Nix-managed lspmux service and wrappers

**Goal:** Provide `lspmux`, its config file, the launchd agent, and editor-facing wrappers from Home Manager.

**Requirements:** R1, R2, R3

**Dependencies:** None

**Files:**
- Create: `sharedHome/development/lspmux.nix`
- Modify: `sharedHome/development/default.nix`

**Approach:**
- Install `pkgs.lspmux`.
- Write `xdg.configFile."lspmux/config.toml"` with local TCP defaults and a bounded `pass_environment`.
- Use `launchd.agents.lspmux.config` on Darwin to render the plist shape.
- Generate wrapper binaries for `elixir-ls`, `expert`, `rust-analyzer`, and debugger support through `pkgs.writeShellApplication`.

**Patterns to follow:**
- `sharedHome/development/lsp.nix`
- `sharedHome/development/devops/nixpkgs.nix`

**Test scenarios:**
- Test expectation: none -- Home Manager config and wrapper generation are declarative configuration; verification is eval/build-based.

**Verification:**
- Workspace Darwin Home Manager evaluation includes `pkgs.lspmux`.
- Generated launchd agent contains label `org.codeberg.p2502.lspmux` and `ProgramArguments = [ lspmux server ]`.
- Wrapper paths appear in the Home Manager package list after evaluation.

### U2. Pin mise-owned LSP tool availability

**Goal:** Ensure mise knows about the language-server tools that wrappers expect.

**Requirements:** R3, R4

**Dependencies:** U1

**Files:**
- Modify: `files/workspace/.config/mise/config.toml`

**Approach:**
- Add `rust-analyzer` and `rust-src` rust components to the existing `rust` tool entry.
- Add `expert` as a mise-managed tool.
- Do not add lexical or next-ls.

**Patterns to follow:**
- Existing `[tools.*]` entries in `files/workspace/.config/mise/config.toml`

**Test scenarios:**
- Test expectation: none -- tool declaration only; verification is runtime command discovery.

**Verification:**
- `mise ls --current` includes `expert`.
- `mise exec -- rust-analyzer --version` succeeds.
- `mise exec -- expert --version` or `expert --help` succeeds.

### U3. Route Zed LSPs through lspmux wrappers

**Goal:** Update Zed settings so Elixir and selected mise-managed LSPs use the Nix-generated wrapper paths.

**Requirements:** R3, R4, R5

**Dependencies:** U1, U2

**Files:**
- Modify: `files/workspace/.config/zed/settings.json`

**Approach:**
- Add `binary.path` overrides for `elixir-ls`, `expert`, and `rust-analyzer` pointing at `/etc/profiles/per-user/hj/bin/lspmux-mise-*`.
- Change Elixir and HEEx server order to `elixir-ls`, `expert`, then existing HTML/Tailwind helpers.
- Explicitly disable `next-ls` and `lexical` in Elixir/HEEx language blocks.
- Preserve existing `nixd`, formatting, Tailwind, and agent settings.

**Patterns to follow:**
- Existing Zed `lsp` and `languages` sections in `files/workspace/.config/zed/settings.json`
- `docs/solutions/developer-experience/nix-zed-lsp-nixd-switch-2026-03-26.md`

**Test scenarios:**
- Test expectation: none -- editor settings change; verification is JSON validation and config inspection.

**Verification:**
- `jq` parses `files/workspace/.config/zed/settings.json`.
- Elixir/HEEx language-server order matches the requirement.
- `nixd` block remains unchanged except for unrelated formatting stability from `jq` if any.

### U4. Route Cursor LSPs through lspmux wrappers

**Goal:** Update Cursor settings so VS Code-style language server extensions use the same wrapper paths.

**Requirements:** R3, R4, R5

**Dependencies:** U1, U2

**Files:**
- Modify: `files/workspace/.config/cursor/settings.json`

**Approach:**
- Set `elixirLS.languageServerOverridePath` to the Home Manager-managed ElixirLS release shim directory at `~/.local/share/lspmux/cursor-elixir-ls-release-shim`.
- Set `expert.server.releasePathOverride` to the Expert lspmux wrapper and keep stdio startup.
- Set `rust-analyzer.server.path` to the rust-analyzer lspmux wrapper.
- Remove stale `mise.binPath` pointing at non-existent `~/.local/bin/mise` and replace with the current live `mise` binary path.
- Do not configure lexical or next-ls.

**Patterns to follow:**
- Existing Cursor settings shape in `files/workspace/.config/cursor/settings.json`
- Local Cursor extension manifests for ElixirLS, Expert, and rust-analyzer

**Test scenarios:**
- Test expectation: none -- editor settings change; verification is JSON validation and extension-setting inspection.

**Verification:**
- `jq` parses `files/workspace/.config/cursor/settings.json`.
- Cursor extension list includes `elixir-lsp.elixir-ls` and `expertlsp.expert`.
- Cursor extension list does not include lexical or next-ls.

---

## System-Wide Impact

- **Interaction graph:** GUI editor -> editor LSP extension -> Home Manager wrapper -> `mise exec` -> `lspmux client` -> `lspmux server` launchd agent -> actual language server.
- **Error propagation:** Wrapper failures should surface in editor LSP logs; `lspmux` daemon logs go to `~/Library/Logs/lspmux.log`.
- **State lifecycle risks:** Long-running LSP instances may outlive editor windows by design; `instance_timeout = 300` bounds idle retention.
- **API surface parity:** Zed and Cursor should point at the same wrapper family for matching LSPs.
- **Integration coverage:** Local eval verifies Nix rendering; live editor behavior still depends on restarting Home Manager/launchd and the editor.
- **Unchanged invariants:** Existing Nix flake outputs, homelab modules, and `nixd` flake-aware setup remain unchanged.

---

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| Editor extensions pass validation flags such as `--version` before normal LSP startup | Wrappers handle version probes before starting `lspmux`; ElixirLS uses `mise current elixir-ls` because its launcher otherwise starts the LSP process. |
| GUI app environment misses mise paths | Wrappers default to `/opt/homebrew/bin/mise` and allow `MISE_BIN` override. |
| `lspmux` multiplexing drops some server-to-client requests | Keep rollout scoped to editor config and preserve direct Nix LSP for `nixd`; fall back by removing binary override if a language server misbehaves. |
| Existing unrelated dirty work in the repo | Touch only lspmux/mise/editor config files and leave existing skill/config changes untouched. |

---

## Documentation / Operational Notes

- After applying Home Manager/nix-darwin, restart the `lspmux` launch agent or log out/in so the new daemon is active.
- Restart Zed and Cursor after Home Manager switch so editor LSP processes use the new wrapper paths.
- Updating LSP versions through `mise` remains supported after Nix switch; already-running `lspmux` instances may need editor restart, `lspmux reload`, or the configured idle timeout before the new LSP process is spawned.

---

## Sources & References

- Related code: `sharedHome/development/lsp.nix`
- Related code: `sharedHome/development/devops/nixpkgs.nix`
- Related code: `files/workspace/.config/zed/settings.json`
- Related code: `files/workspace/.config/cursor/settings.json`
- Related learning: `docs/solutions/developer-experience/nix-zed-lsp-nixd-switch-2026-03-26.md`
- External docs: `https://codeberg.org/p2502/lspmux`
- External docs: `https://zed.dev/docs/configuring-languages`
- External docs: `https://marketplace.visualstudio.com/items?itemName=ExpertLSP.expert`
