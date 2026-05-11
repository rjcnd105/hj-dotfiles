# Progressive Sidenotes With anchor()

Catalog ID: `anchor-function-sidenote`

Use this when article notes should stay in source order but become margin sidenotes on wide layouts.

Avoid it when notes contain required form instructions or critical warnings; keep those inline.

Support: cataloged as Baseline 2026 target through MDN `anchor()` support checking. Narrow and unsupported layouts keep notes inline.

Source refs: `ev-x-s3thompson-anchor-sidenote-20260508`, `ev-mdn-anchor-function-20260508`.

Example: `examples/anchor-function-sidenote/index.html`.

Notes:

- Put the note in normal reading order first.
- Assign `anchor-name` to a small marker near the sentence being annotated.
- Associate the positioned note with that marker via `position-anchor` before relying on `anchor()`.
- Promote notes to the margin only inside `@supports` and a wide-layout query.
