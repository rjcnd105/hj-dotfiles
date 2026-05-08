# Adding Patterns

Use this workflow when adding another CSS/HTML tip, example, method, or pattern to this skill.

This is an agent workflow. The user should be able to say `$modern-css-html-patterns add <url>` or ask conversationally to add a pattern. The agent then runs the source checks, duplicate check, catalog edits, example writing, and validation. Shell helpers in `scripts/` are implementation tools, not the user-facing interface.

## Input Patterns

| User input | Behavior |
| --- | --- |
| `$modern-css-html-patterns add <url>` | Fetch/check the URL, decide whether it deserves a catalog entry, then update the corpus. |
| `$modern-css-html-patterns add <description>` | Search current docs/sources as needed, then update the corpus if the pattern is distinct. |
| `$modern-css-html-patterns ingest <url>` | Alias for `add`. |
| `$modern-css-html-patterns add` | Inspect `references/backlog.jsonl` and ask which backlog item or source to process. |

## Decision Gate

Add a new catalog entry only when the candidate has a distinct feature set, interaction pattern, or visual outcome. If it mostly overlaps with an existing entry, update `related_patterns`, add a note to that pattern doc, or keep the candidate in `references/backlog.jsonl`.

## Agent Add Sequence

1. Read `references/schema.md`.
2. Read `references/index.jsonl`, `references/source-seeds.jsonl`, `references/backlog.jsonl`, and the most relevant existing pattern docs.
3. Check the new source:
   - For ordinary web/docs pages, fetch the current page.
   - For X/Twitter, record direct access status separately from metadata extraction.
   - For browser support, prefer MDN, web.dev Baseline, specs, or browser docs over social posts.
4. Decide one of:
   - update an existing pattern
   - create a new pattern
   - add/keep a backlog item
   - reject the source with a `rejected_reason`
5. If creating a new pattern, choose a stable kebab-case `id`, category, support status, fallback, and verification target.
6. Optionally run the scaffold helper to create placeholder doc/example files.
7. Edit JSONL, pattern doc, and example HTML.
8. Run validation and affected-example browser smoke.
9. Report the catalog ID, support status, fallback, and any remaining caveats.

## Required File Updates

1. Record the source access event in `logs/ingest.jsonl`.
2. Add the source to `references/source-seeds.jsonl` if it should remain part of the durable source queue.
3. Add or update the matching `## <source_event_id>` note in `references/source-details.md`.
4. Add or update the catalog line in `references/index.jsonl`.
5. Create the pattern doc under `references/patterns/<pattern-id>.md`.
6. Create the runnable example under `examples/<pattern-id>/index.html`.
7. Run the validator:

```sh
go run scripts/validate_index.go
```

From the repository root, use:

```sh
go run files/workspace/.agents/skills/modern-css-html-patterns/scripts/validate_index.go
```

## Scaffold Helper

After the agent has decided to create a new pattern, it may create doc and example placeholders with:

```sh
go run scripts/new_pattern.go <pattern-id> "<Pattern Title>"
```

The helper refuses to overwrite existing files. It intentionally does not edit JSONL files because source provenance, support status, and verification state must be explicit. Do not hand this command to the user as the whole answer to an add/ingest request; run the workflow.

Open the examples folder in Finder with:

```sh
sh scripts/open_examples.sh
```

Open a specific example folder with:

```sh
sh scripts/open_examples.sh examples/<pattern-id>
```

## Source Rules

- X/Twitter, videos, screenshots, and social posts are `source_kind: inspiration` unless exact code is independently accessible.
- MDN, web.dev, specifications, and browser docs are preferred for `support_source_ref`.
- Article/demo pages can be `example_source_ref` only when the resulting example is extracted or clearly reconstructed.
- Blocked sources still belong in `logs/ingest.jsonl` with `access_status: blocked` or `partial`.
- `source-details.md` must state what was actually accessible, what was reconstructed, and when the source should be rechecked. Do not depend on a social URL remaining readable later.

## Support Rules

- Use broad Baseline labels such as `baseline-2024`, `baseline-2025`, `baseline-2026`, `widely-available`, or `non-baseline`.
- Use `browserslist_query: null` for limited or experimental features.
- If `support.status` is `limited` or `experimental`, include a real fallback, fallback test method, and fallback result.
- Do not mark a pattern `verified` unless the example behavior was checked, not merely rendered.

## Example Rules

- Keep examples plain HTML/CSS unless the platform pattern requires JavaScript.
- Put fallback behavior first, then progressive enhancement inside `@supports`, `@container`, media queries, or feature-specific guards.
- Include mobile and desktop viewport expectations in `checked_viewports`.
- For interaction or HTML primitive examples, record checked states and accessibility notes.
