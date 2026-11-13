# Popover Entry Transition With @starting-style

Catalog ID: `starting-style-popover`

Use this when a native `popover` needs a polished opening transition while preserving platform open/close behavior.

Avoid it when the design requires full modal semantics; use `dialog` for modal tasks.

Support: cataloged as Baseline 2024, with caveats around discrete `display` and `overlay` transitions.

Source refs: `ev-x-kara-starting-style-20260508`, `ev-mdn-starting-style-20260508`, `ev-mdn-popover-api-20260508`.

## Technique

- Build the interaction with native `popover` and `popovertarget` first.
- Apply opacity and transform transitions to `:popover-open`.
- Use `@starting-style` for the opening frame and guard discrete `display`/`overlay` transitions with `@supports`.

## Accessibility

Use popover for lightweight non-modal panels. Choose `dialog` when the task needs modal semantics, focus trapping, or a blocking decision.

Example: `examples/starting-style-popover/index.html`.

Notes:

- Keep the content useful when the transition enhancement is ignored.
- Use a visible close button for discoverability.
- Guard discrete transition behavior with `@supports`.
