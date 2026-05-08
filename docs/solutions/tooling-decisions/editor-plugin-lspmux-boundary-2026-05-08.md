---
title: Do not force extension-owned LSPs through lspmux
date: 2026-05-08
category: tooling-decisions
module: nix-dots editor language servers
problem_type: tooling_decision
component: tooling
severity: medium
applies_when:
  - "A Cursor or VS Code extension already owns the language-server lifecycle"
  - "An editor plugin exposes bundled LSP settings and a custom path setting"
  - "Agent-facing language-server access needs lspmux without breaking editor plugins"
related_components:
  - cursor
  - zed
  - lspmux
  - mise
  - taplo
tags: [lspmux, cursor, zed, taplo, mise, language-servers, editor-config]
---

# Do not force extension-owned LSPs through lspmux

## Context

The workspace routes many agent/editor language-server entrypoints through Home Manager-managed `lspmux` wrappers. That boundary works well for tools where the editor accepts a normal language-server executable, such as Zed's explicit `lsp.<server>.binary.path` settings and agent-facing wrapper commands.

Cursor's Even Better TOML extension behaved differently. Forcing its Taplo path to `/etc/profiles/per-user/hj/bin/lspmux-mise-taplo` made the extension startup brittle, and led to investigation work around Taplo argument handling and an experimental `lspmux` patch. The final fix was to stop overriding the extension-owned server path and let the plugin use its bundled Taplo server.

## Guidance

Keep extension-owned LSPs on their native extension path unless the extension's override contract is verified to behave like a plain stdio language-server command.

For Cursor Even Better TOML, prefer the bundled server:

```json
{
  "evenBetterToml.taplo.bundled": true
}
```

Do not force the extension through a workspace wrapper:

```json
{
  "evenBetterToml.taplo.bundled": false,
  "evenBetterToml.taplo.path": "/etc/profiles/per-user/hj/bin/lspmux-mise-taplo"
}
```

Keep these responsibilities separate:

- Cursor plugin-owned LSPs use the plugin's bundled/default server when that is the stable integration path.
- Zed can use explicit `lspmux-*` binary overrides where Zed's LSP configuration accepts them cleanly.
- Agents use the Home Manager-generated `lspmux-*` wrapper catalog and should not depend on Cursor extension internals.
- Experimental upstream patches to `lspmux` should not remain in the repo unless they are required by a durable, verified integration boundary.

## Why This Matters

`lspmux` is useful as an executable-level multiplexer, but an editor extension may do more than execute a server binary. It may inject arguments, own bundled assets, cache settings in its extension host, or expect server-specific request behavior during initialization. Treating every extension override as a generic executable slot creates fragile configuration and can make the repo accumulate temporary compatibility code.

The cleaner boundary is narrower: use `lspmux` where the client contract is a normal language-server executable, and leave extension-owned lifecycle surfaces native unless proven otherwise.

## When to Apply

- When a Cursor or VS Code extension has a working bundled LSP and only needs project settings.
- When an LSP wrapper works for Zed or agents but causes extension activation or connection failures in Cursor.
- When a proposed fix requires patching `lspmux` itself just to satisfy one editor plugin override.

## Examples

The Taplo wrapper can still exist for Zed or agent use:

```nix
{
  name = "taplo";
  wrapperName = "lspmux-mise-taplo";
  provider = "mise";
  server = "taplo";
  serverArgs = [
    "lsp"
    "stdio"
  ];
  versionFromMiseTool = "aqua:tamasfe/taplo";
  languages = [ "toml" ];
}
```

Cursor should not be required to use that wrapper. Its TOML extension should stay on the plugin-owned path unless a future version documents and verifies a compatible external-server contract.

## Related

- [Cursor settings](../../../files/workspace/.config/cursor/settings.json)
- [lspmux Home Manager module](../../../sharedHome/development/lspmux.nix)
- [Zed settings](../../../files/workspace/.config/zed/settings.json)
