---
name: find-skills
description: Helps users discover and install agent skills when they ask questions like "how do I do X", "find a skill for X", "is there a skill that can...", or express interest in extending capabilities. This skill should be used when the user is looking for functionality that might exist as an installable skill.
---

# Find Skills

This skill helps you discover and install agent packages with Microsoft Agent
Package Manager (APM). Codex is the source-of-truth target; the repository
manifest projects the same package to Claude Code and Cursor.

## When to Use This Skill

Use this skill when the user:

- Asks "how do I do X" where X might be a common task with an existing skill
- Says "find a skill for X" or "is there a skill for X"
- Asks "can you do X" where X is a specialized capability
- Expresses interest in extending agent capabilities
- Wants to search for tools, templates, or workflows
- Mentions they wish they had help with a specific domain (design, testing, deployment, etc.)

## What is APM?

APM (`apm`) manages skills, instructions, agents, hooks, commands, MCP servers,
and other agent primitives from one `apm.yml` manifest and a reproducible
`apm.lock.yaml`.

**Key commands:**

- `apm marketplace list` - List configured package marketplaces
- `apm marketplace browse <marketplace>` - Browse a marketplace
- `apm search <query>@<marketplace>` - Search a configured marketplace
- `apm view <owner/repo> versions` - Inspect available Git refs
- `apm install <owner/repo/path>` - Add and install a package
- `apm update` - Review and update locked dependencies
- `apm install --frozen` - Reproduce the committed lockfile without updates

APM can consume a GitHub repository, a virtual package path within a repository,
an APM package, or a Claude plugin. Existing catalogs such as
https://skills.sh/ remain useful for discovery, but installation and locking
must use APM.

## How to Help Users Find Skills

### Step 1: Understand What They Need

When a user asks for help with something, identify:

1. The domain (e.g., React, testing, design, deployment)
2. The specific task (e.g., writing tests, creating animations, reviewing PRs)
3. Whether this is a common enough task that a skill likely exists

### Step 2: Check Available Sources

Start with configured APM marketplaces:

```bash
apm marketplace list
apm marketplace browse <marketplace>
```

If the repositories are not indexed by a configured marketplace, search
official project documentation, GitHub, or skills.sh and identify the exact
repository and virtual package path.

### Step 3: Search for Packages

```bash
apm search <query>@<marketplace>
```

For example:

- React performance → `apm search "react performance"@<marketplace>`
- PR review → `apm search "pr review"@<marketplace>`
- Changelog generation → `apm search changelog@<marketplace>`

### Step 4: Verify Quality Before Recommending

**Do not recommend a skill based solely on search results.** Always verify:

1. **Install count** — Prefer skills with 1K+ installs. Be cautious with anything under 100.
2. **Source reputation** — Official sources (`vercel-labs`, `anthropics`, `microsoft`) are more trustworthy than unknown authors.
3. **GitHub stars** — Check the source repository. A skill from a repo with <100 stars should be treated with skepticism.
4. **Package shape** — Confirm the repository contains `apm.yml`,
   `.apm/skills/<name>/SKILL.md`, `skills/<name>/SKILL.md`, or a supported
   plugin manifest before installing.

### Step 5: Present Options to the User

When you find relevant skills, present them to the user with:

1. The skill name and what it does
2. The install count and source
3. The install command they can run
4. The exact source and virtual package path

Example response:

```
I found a skill that might help! The "react-best-practices" skill provides
React and Next.js performance optimization guidelines from Vercel Engineering.
(185K installs)

To install it:
apm install vercel-labs/agent-skills/skills/react-best-practices

Source: https://github.com/vercel-labs/agent-skills
```

### Step 6: Offer to Install

If the user wants to proceed, you can install the skill for them:

```bash
apm install <owner/repo/path>
```

Do not add `--global` in this dotfiles workspace. The project under
`files/workspace` is already projected to the user's home by Nix. After
installation, compile the Codex root instructions when APM prints the
post-install reminder:

```bash
apm compile --target codex --single-agents --output .codex/AGENTS.md
```

APM deploys the shared instruction directly to Claude Code and Cursor rule
directories during `apm install`.

## When No Skills Are Found

If no relevant skills exist:

1. Acknowledge that no existing skill was found
2. Offer to help with the task directly using your general capabilities
3. Suggest creating a local package under `.apm/skills/<name>/SKILL.md`

Example:

```
I searched for skills related to "xyz" but didn't find any matches.
I can still help you with this task directly! Would you like me to proceed?

If this is something you do often, you could create your own skill:
.apm/skills/my-xyz-skill/SKILL.md
```
