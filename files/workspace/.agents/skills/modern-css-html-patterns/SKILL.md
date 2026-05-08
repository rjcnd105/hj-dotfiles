---
name: modern-css-html-patterns
description: Use this skill to select, adapt, and maintain modern CSS-first HTML platform patterns with runnable examples, source provenance, browser support, and fallback notes.
---

# Modern CSS/HTML Patterns

Use this skill when the user asks for current CSS-first platform techniques, modern HTML primitives that complete those CSS patterns, or runnable examples grounded in indexed sources.

## Preamble

**Skill path**: `/Users/hj/dot/nix-dots/files/workspace/.agents/skills/modern-css-html-patterns`

All helper/script paths are relative to this skill path unless an absolute path is shown.

## Commands

Parse the user's request into a subcommand:

| Input pattern | Subcommand |
| --- | --- |
| `$modern-css-html-patterns add <url-or-description>` | add |
| `$modern-css-html-patterns ingest <url-or-description>` | add |
| `$modern-css-html-patterns add` | add-from-backlog |
| `$modern-css-html-patterns query <requirement>` | query |
| `$modern-css-html-patterns lint` | lint |
| `$modern-css-html-patterns validate` | lint |
| `$modern-css-html-patterns open-examples` | open-examples |
| `$modern-css-html-patterns open-examples <pattern-id>` | open-one-example |

## Core Rules

- Treat CSS as the primary surface, but include HTML primitives such as `popover`, `dialog`, anchors, forms, and inert states when they are part of the pattern contract.
- Use `references/index.jsonl` as the canonical catalog. Do not rely on pattern prose alone.
- Prefer verified MDN, web.dev Baseline, article, or demo sources for support claims. X/Twitter sources are inspiration unless independently reconstructed or verified.
- Use the recorded `support.browserslist_query` and `support.requires` before recommending a pattern.
- When a pattern is `limited`, `experimental`, or `limited-fallback-only`, present the fallback and the known caveats with the code.
- Keep examples minimal and runnable. Every catalog entry must point to an `examples/<pattern-slug>/index.html` file.
- Do not read every example HTML file during recommendation. Use `references/index.jsonl`, `references/example-digests.md`, and selected pattern docs for shortlisting; open runnable HTML only for final adaptation, verification, or bug fixing.
- Do not add duplicate patterns. Check aliases, CSS features, HTML features, and related patterns before creating a new entry.

## Tools

Mechanical validation/scaffolding is delegated to small stdlib-only helpers. These are internal implementation tools, not the user-facing command interface.

| Tool | Role |
| --- | --- |
| `go run scripts/validate_index.go` | Validate JSONL schema, source refs, pattern docs, example paths, support/fallback invariants. |
| `go run scripts/new_pattern.go <pattern-id> "<Pattern Title>"` | Create doc/example placeholders after the add workflow has chosen a new pattern ID/title. Refuses overwrite. |
| `sh scripts/open_examples.sh [examples/<pattern-id>]` | Open all examples or one example folder in Finder. |

## Workflow: query

1. Search `references/index.jsonl` by requirement terms, category, CSS feature, HTML feature, support target, and fallback needs.
2. Read only the relevant sections of `references/example-digests.md` to understand what each shortlisted example demonstrates without loading full HTML.
3. Open the matching file under `references/patterns/` for usage notes and adaptation guidance.
4. Open the linked `example_path` only for the final chosen pattern or for at most 2-3 close candidates when code-level adaptation is needed.
5. If support freshness matters, re-check the linked `support_source_ref` URLs and update `last_checked`, `support.query_verified`, and `logs/ingest.jsonl`.

## Workflow: add

Add a CSS/HTML example, tip, method, or pattern to the skill corpus. This is the skill-level ingest workflow, analogous to `$kb ingest`.

1. Read `references/schema.md` and `references/adding-patterns.md`.
2. Inspect `references/index.jsonl` and `references/backlog.jsonl` for duplicates or near-duplicates.
3. Fetch/check the provided source URL or source description. Use current primary docs for browser support when the feature is modern or support-sensitive.
4. Decide whether to update an existing pattern, add a backlog item, or create a new catalog entry.
5. For a new entry, optionally use the scaffold helper to create only the initial doc/example files:

```sh
go run files/workspace/.agents/skills/modern-css-html-patterns/scripts/new_pattern.go <pattern-id> "<Pattern Title>"
```

6. Edit the JSONL catalog, source logs, pattern doc, and runnable example directly.
7. Run the validator and browser smoke for the affected example.
8. Report what was added, support status, fallback behavior, and verification.

The scaffold helper is not the user-facing workflow. It is an internal convenience step after the agent has chosen the pattern ID/title and source/support model.

## Workflow: add-from-backlog

1. Read `references/backlog.jsonl`.
2. Present the backlog IDs and reasons.
3. Ask which backlog item to process if the user did not name one.
4. Continue with Workflow: add.

## Workflow: lint

Run:

```sh
cd "/Users/hj/dot/nix-dots/files/workspace/.agents/skills/modern-css-html-patterns" && go run scripts/validate_index.go
```

Report validation failures with file/path context and the smallest fix needed.

## Workflow: open-examples

Open the examples folder in Finder:

```sh
sh "/Users/hj/dot/nix-dots/files/workspace/.agents/skills/modern-css-html-patterns/scripts/open_examples.sh"
```

## Workflow: open-one-example

Open one example folder in Finder:

```sh
sh "/Users/hj/dot/nix-dots/files/workspace/.agents/skills/modern-css-html-patterns/scripts/open_examples.sh" "examples/<pattern-id>"
```

## Reference Files

- `references/schema.md`: schema, enums, validation rules, and update policy.
- `references/adding-patterns.md`: checklist, source rules, support rules, and scaffold workflow for adding future tips or patterns.
- `references/index.jsonl`: canonical pattern catalog.
- `references/example-digests.md`: token-light summaries of runnable examples keyed by catalog ID.
- `references/source-seeds.jsonl`: durable source queue and accepted seed list.
- `references/source-details.md`: human-readable provenance notes keyed by `source_event_id`.
- `references/backlog.jsonl`: candidates intentionally not included in the current runnable catalog.
- `logs/ingest.jsonl`: append-only source access and indexing log.
