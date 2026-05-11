---
title: Modern CSS/HTML pattern code kernels for token-light agent recall
date: 2026-05-11
category: developer-experience
module: modern-css-html-patterns
problem_type: developer_experience
component: tooling
severity: low
applies_when:
  - "Agents need CSS/HTML pattern snippets without reading aggregate references or full examples"
  - "A skill corpus has indexed examples plus compact per-pattern adaptation snippets"
  - "Validators must keep indexed code kernels addressable, bounded, and non-duplicative"
tags: [modern-css-html-patterns, agent-skills, code-kernels, token-optimization, css, html, validator]
---

# Modern CSS/HTML pattern code kernels for token-light agent recall

## Context

`modern-css-html-patterns` started as a CSS/HTML skill with runnable examples, source provenance, support notes, and fallback guidance. The first retrieval design avoided reading full example HTML by adding token-light digests and a single `references/code-kernels.md` file.

That was better than opening `examples/<id>/index.html`, but it still had the same scaling problem in a smaller package. Once the catalog grows past a dozen patterns, a single aggregate code-kernel file becomes a mini database: an agent can accidentally read every snippet while trying to answer with one pattern. The user called this out directly during review: recommendation and first-pass code generation should not require reading full examples or a large aggregate snippet file.

Session history search did not surface an older completed solution for this exact `modern-css-html-patterns` structure. The relevant decisions came from this session's review loop and the current pushed bookmark `skill/modern-css-html-pattern-digests`.

## Guidance

Keep the skill corpus as layered recall, not as one large reference file. Each layer has a narrow job:

1. `references/index.jsonl` is the canonical machine-readable catalog. It owns `id`, support status, fallback notes, source refs, `example_path`, and `code_kernel_path`.
2. `references/example-digests.md` is the shortlist layer. It explains fit with `Shows`, `Best for`, `Key CSS` or `Key CSS/HTML`, and `Read full HTML when`.
3. `references/code-kernels/<id>.md` is the first-pass code suggestion layer. Open only the selected pattern's kernel file.
4. `references/patterns/<id>.md` contains caveats and usage notes.
5. `examples/<id>/index.html` is the verified full source. Open it only for exact adaptation, debugging, or browser verification.

The catalog entry should point to the kernel explicitly:

```json
{"id":"container-query-card","example_path":"examples/container-query-card/index.html","code_kernel_path":"references/code-kernels/container-query-card.md"}
```

Do not duplicate that path in the digest. The digest is for human routing; `index.jsonl` is the source of truth for file paths.

The per-pattern kernel should contain only the ID heading and useful code:

````md
# container-query-card

```css
.card {
  container-type: inline-size;
  display: grid;
  gap: 18px;
}

@container (min-width: 34rem) {
  .card {
    grid-template-columns: minmax(180px, 0.8fr) minmax(0, 1fr);
  }
}
```
````

Avoid repeating boilerplate such as "this is not the canonical full example" in every kernel file. That policy belongs in `SKILL.md` and `references/schema.md`; repeating it in each shard wastes the exact context budget the sharding is meant to protect.

Source provenance needs the same separation:

- `logs/ingest.jsonl` is the source-event authority.
- `references/source-details.md` explains retrieval and reconstruction notes.
- `references/source-seeds.jsonl` is only an optional intake/recheck queue.

For example, a social post can remain a partial inspiration source while MDN support docs provide the accepted `support_source_ref`.

## Why This Matters

Large examples mix reusable code with demo scaffolding, labels, visual checks, fallback notes, and explanatory UI. Reading them too early makes agents copy example-only details into production suggestions and consumes tokens before the pattern has even been selected.

A single aggregate kernel file has a subtler version of the same failure mode. It is compact today, but at 50 or 100 patterns it becomes another file agents may read wholesale. Sharding makes the desired access path obvious and cheap:

```text
index.jsonl -> digest section -> one code_kernel_path -> pattern doc -> full HTML only if needed
```

Executable validation turns that retrieval design into a durable contract instead of prose guidance. The validator now rejects:

- missing or incorrect `code_kernel_path`
- orphan files in `references/code-kernels/`
- legacy aggregate `references/code-kernels.md`
- digest sections over the line budget
- digest sections that duplicate `Code kernel:` path pointers
- code kernels without fenced code or with too much non-empty text

The result is a skill that can grow without forcing every future query to pay for the whole corpus.

## When to Apply

- A skill or KB contains many runnable examples and agents need to recommend one or two patterns.
- The corpus may grow past 50 entries.
- First-pass answers need code snippets, but full examples are still needed for verification.
- Source reliability varies across social posts, articles, demos, and MDN/browser support docs.
- Intake queues or seed files risk being mistaken for canonical source authority.
- Reviewers notice repeated explanatory boilerplate inside every small reference shard.

## Examples

### Query flow

Use the smallest layer that can answer the current request:

```text
1. Search references/index.jsonl for category, CSS/HTML features, support target, fallback needs, and aliases.
2. Read only matching sections in references/example-digests.md.
3. For code suggestions, open only the selected entry's code_kernel_path.
4. Read references/patterns/<id>.md for caveats when needed.
5. Open examples/<id>/index.html only for exact adaptation, debugging, or browser verification.
```

### Add workflow

When adding a pattern, update the same layers deliberately:

```text
logs/ingest.jsonl
references/source-details.md
references/index.jsonl
references/example-digests.md
references/code-kernels/<pattern-id>.md
references/patterns/<pattern-id>.md
examples/<pattern-id>/index.html
```

`references/source-seeds.jsonl` may mirror an intake item, but it is not required for source authority.

### Validator guardrails

The Go validator is the backstop:

```sh
go run files/workspace/.agents/skills/modern-css-html-patterns/scripts/validate_index.go
```

The expected passing result for the current corpus is:

```text
Validated 12 patterns and 30 source events.
```

### Related

- [`docs/solutions/tooling-decisions/npx-skills-single-ground-truth-2026-04-21.md`](../tooling-decisions/npx-skills-single-ground-truth-2026-04-21.md) — related skill storage ground-truth decision, but not the same retrieval problem.
- [`docs/solutions/best-practices/jj-review-skill-subagent-diff-strategy-2026-04-03.md`](../best-practices/jj-review-skill-subagent-diff-strategy-2026-04-03.md) — related token-optimization pattern for subagent review payloads.
- [`files/workspace/.agents/skills/modern-css-html-patterns/SKILL.md`](../../../files/workspace/.agents/skills/modern-css-html-patterns/SKILL.md) — skill entrypoint and query workflow.
- [`files/workspace/.agents/skills/modern-css-html-patterns/references/schema.md`](../../../files/workspace/.agents/skills/modern-css-html-patterns/references/schema.md) — schema and validation policy.
