---
title: SOPS env bindings with per-secret rendered env files
date: 2026-05-07
category: developer-experience
module: nix-dots-secret-env
problem_type: developer_experience
component: tooling
severity: low
applies_when:
  - "A tool should receive one secret env var without loading the whole workspace secret bundle"
  - "A new SOPS-backed env var should automatically get a matching single-key dotenv file"
  - "Several grouped env files need to share the same env-var to SOPS-secret mapping"
tags: [nix, sops-nix, mise, secrets, env, context7, developer-experience]
---

# SOPS env bindings with per-secret rendered env files

## Context

`mise` can load dotenv files through `_.file`, but it loads the whole file rather
than selecting individual keys. Loading `workspace-secrets.env` globally made
unrelated credentials available to every `mise`-launched process when only a
single key, such as `CONTEXT7_API_KEY`, was needed.

The first fix was a dedicated `context7.env`, but that would have required a
new hand-written template every time another tool needed a single secret. The
better shape is a single registry that owns env-var names and backing SOPS
secret names, then generates both grouped env files and per-secret env files
from that registry.

## Guidance

Use an env binding registry as the single source of truth:

```nix
env_bindings = {
  CONTEXT7_API_KEY = "CONTEXT7_API_KEY";
  OPENAI_API_KEY = "openai_gpt_key";
  TELEGRAM_BOT_HJSAGENTBOT = "TELEGRAM_BOT_hjsAgentBot";
};
```

Generate `sops.secrets` from the unique secret names, preserving alternate
`sopsFile` ownership where needed:

```nix
secret_names = builtins.attrNames (
  builtins.listToAttrs (
    map (envVar: {
      name = builtins.getAttr envVar env_bindings;
      value = true;
    }) env_var_names
  )
);
```

Generate per-secret dotenv templates from every env var:

```nix
mkSingleSecretEnvTemplate =
  envVar:
  let
    secret = builtins.getAttr envVar env_bindings;
  in
  {
    name = "env/${envVar}.env";
    value = {
      path = "${rendered_env_dir}/env/${envVar}.env";
      content = ''
        ${envVar}=${builtins.getAttr secret config.sops.placeholder}
      '';
    };
  };
```

Grouped files should list env var names, not repeat placeholder expressions:

```nix
workspace_env_vars = [
  "GITHUB_MASTER_TOKEN"
  "CONTEXT7_API_KEY"
  "FIGMA_READ_API_KEY"
];

"workspace-secrets.env".content = mkEnvContent workspace_env_vars;
```

For narrow consumers, point `mise` at the single-key file:

```toml
[env]
_.file = [
  { path = "$HOME/.config/sops-nix/secrets/rendered/env/CONTEXT7_API_KEY.env", redact = true, read_only = true },
]
```

## Why This Matters

The registry avoids two failure modes:

- Secret exposure drift: a tool that needs one key does not inherit the whole
  workspace secret bundle.
- Template drift: adding a new env var in one place automatically creates the
  `sops.secrets` entry and the matching `rendered/env/<ENV_VAR>.env` file.

Aliases still stay explicit. Nix cannot infer that `openai_gpt_key` should
produce both `OPENAI_GPT_KEY` and `OPENAI_API_KEY`, or that
`TELEGRAM_BOT_hjsAgentBot` should render as `TELEGRAM_BOT_HJSAGENTBOT`. The
binding registry keeps those conventions visible and diffable.

## When to Apply

- When `mise`, Codex MCP, CLI tools, or app-specific tasks should load only one
  secret.
- When one SOPS secret needs multiple env aliases for different tool contracts.
- When grouped env files and per-secret env files must stay in sync.

## Examples

Adding a new per-secret env file now means adding one binding:

```nix
env_bindings = {
  NEW_TOOL_API_KEY = "NEW_TOOL_API_KEY";
};
```

If that env var should also appear in a grouped file, add the env-var name to the
appropriate bundle:

```nix
llm_env_vars = [
  "OPENAI_API_KEY"
  "NEW_TOOL_API_KEY"
];
```

The rendered output includes:

```text
~/.config/sops-nix/secrets/rendered/env/NEW_TOOL_API_KEY.env
```

with a single dotenv assignment:

```dotenv
NEW_TOOL_API_KEY=...
```

## Related

- `homes/workspace/sops.nix`
- `files/workspace/.config/mise/config.toml`
- `files/workspace/.codex/config.toml`
