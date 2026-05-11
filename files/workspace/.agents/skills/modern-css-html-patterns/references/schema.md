# Modern CSS/HTML Patterns Schema

Schema version: `1.0.0`

`references/index.jsonl` is the canonical current catalog. `logs/ingest.jsonl` is the append-only source-event authority. `references/example-digests.md` is the token-light example routing layer. `references/code-kernels.md` is the token-light code suggestion layer. Pattern docs and runnable examples are derived artifacts that must point back to catalog IDs.

Recommendation should not require reading example HTML files. Agents should shortlist from `index.jsonl`, selected `example-digests.md` sections, selected `code-kernels.md` sections, and selected pattern docs. Open runnable HTML only after choosing one final pattern for deeper adaptation, verification, or bug fixing.

`source_refs` are stable source event IDs. Resolve them from:

1. `logs/ingest.jsonl` for the machine-readable access event and acceptance state.
2. `references/source-details.md` for human-readable retrieval notes, reconstruction notes, and recheck triggers.

`references/source-seeds.jsonl` is an optional intake/recheck queue. It may mirror accepted sources for convenience, but it is not a source-ref authority.

## Catalog Entry

Required fields:

- `schema_version`: currently `1.0.0`.
- `id`: stable kebab-case identifier.
- `title`: human-readable pattern name.
- `category`: one of the closed category enum values.
- `aliases`: alternate search terms.
- `css_features`: CSS features, functions, at-rules, selectors, or properties.
- `html_features`: platform primitives involved in the pattern.
- `source_refs`: source event IDs that inspired or substantiate the pattern.
- `support_source_ref`: source event ID used for support claims.
- `example_source_ref`: source event ID used for example reconstruction.
- `verification_status`: catalog verification state.
- `support`: browser support object.
- `fallback`: fallback strategy summary.
- `fallback_test_method`: how the fallback was checked.
- `verification_mode`: how the example was checked.
- `example_path`: exact relative path `examples/<id>/index.html`.
- `states_demonstrated`: states visible in the example.
- `checked_states`: states checked during verification.
- `checked_viewports`: viewport sizes checked or targeted.
- `a11y_checks`: accessibility checks that apply.
- `verification_evidence`: short evidence note.
- `example_verified_at`: ISO date or datetime.
- `verification_target`: runtime target used for verification.
- `expected_primary_result`: expected result with modern support.
- `fallback_result`: expected result without the modern feature.
- `related_patterns`: related catalog IDs.
- `last_checked`: ISO date.

Every catalog ID in `references/index.jsonl` must also have exactly one matching `## <catalog_id>` heading in `references/example-digests.md` and `references/code-kernels.md`. Digest sections must stay token-light: at most 8 non-empty lines and required lines for `Shows`, `Best for`, `Key CSS` or `Key CSS/HTML`, and `Read full HTML when`. Code kernel sections must include a fenced code block and stay token-light: at most 80 non-empty lines. Kernels are adaptation snippets, not canonical full examples; if they conflict with the runnable example, update the kernel. Orphan digest or code-kernel headings are invalid.

## Support Object

Required fields:

- `status`: one of `baseline`, `limited`, `experimental`, `deprecated`.
- `baseline_target`: broad target such as `baseline-2024`, `baseline-2025`, `baseline-2026`, `non-baseline`, or `widely-available`.
- `browserslist_query`: non-empty query string following Browserslist Baseline syntax for `baseline` support, otherwise `null`.
- `query_verified`: boolean.
- `requires`: concrete browser or runtime requirements.
- `caveats`: known support or behavior caveats.

Use broad Baseline labels by default. Add browser-specific caveats only when needed for correctness. `support_source_ref` must point to an accepted, accessible `docs` or `support-doc` source event.

## Source Event

Required fields for `references/source-seeds.jsonl` and `logs/ingest.jsonl`:

- `schema_version`
- `source_event_id`
- `source_id`
- `url`
- `source_kind`
- `access_status`
- `http_status`
- `checked_at`
- `captured_evidence`
- `intended_pattern_ids`
- `accepted`
- `rejected_reason`

Every source event ID in `logs/ingest.jsonl` must also have a matching `## <source_event_id>` heading in `references/source-details.md`. Keep that note concise and durable enough to explain what was actually accessible if the original URL later changes or disappears.

`source_kind` values:

- `inspiration`
- `article`
- `docs`
- `code`
- `demo`
- `support-doc`

`access_status` values:

- `accessible`
- `blocked`
- `partial`
- `not-checked`

## Catalog Enums

`category` values:

- `layout`
- `interaction`
- `motion`
- `state-query`
- `visual-effect`
- `typography`
- `form-control`
- `html-primitive`

`verification_status` values:

- `extracted`
- `reconstructed`
- `verified`
- `needs-review`
- `limited-fallback-only`

`support.status` values:

- `baseline`
- `limited`
- `experimental`
- `deprecated`

## Validation Rules

The validator must reject:

- malformed JSONL
- duplicate catalog IDs
- duplicate source event IDs
- unknown enum values
- missing required fields
- missing `schema_version`
- missing `example_path`
- missing pattern docs
- catalog entries missing from `references/example-digests.md`
- duplicate or orphan headings in `references/example-digests.md`
- digest sections that miss required labels or exceed the token-light line limit
- catalog entries missing from `references/code-kernels.md`
- duplicate or orphan headings in `references/code-kernels.md`
- code kernel sections that lack fenced code or exceed the token-light line limit
- source refs not present in `logs/ingest.jsonl`
- source refs that point to rejected source events
- source events missing from `references/source-details.md`
- support refs that are not accepted, accessible docs/support-doc source events
- support claims without `support_source_ref`
- limited or experimental patterns without fallback notes
- interactive or HTML primitive patterns without checked states and accessibility notes

## Update Policy

- Add a new source event for every re-check instead of editing old log lines.
- Update `last_checked` only after support or source status is actually checked.
- Keep X/Twitter examples marked as inspiration unless a reconstructable code path or independent docs source is recorded.
- Move candidates from `backlog.jsonl` into `index.jsonl` only after adding a runnable example.
