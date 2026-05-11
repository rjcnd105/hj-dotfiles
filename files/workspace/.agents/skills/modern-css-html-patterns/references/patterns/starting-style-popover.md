# Popover Entry Transition With @starting-style

Catalog ID: `starting-style-popover`

Use this when a native `popover` needs a polished opening transition while preserving platform open/close behavior.

Avoid it when the design requires full modal semantics; use `dialog` for modal tasks.

Support: cataloged as Baseline 2024, with caveats around discrete `display` and `overlay` transitions.

Source refs: `ev-x-kara-starting-style-20260508`, `ev-mdn-starting-style-20260508`, `ev-mdn-popover-api-20260508`.

Example: `examples/starting-style-popover/index.html`.

Notes:

- Keep the content useful when the transition enhancement is ignored.
- Use a visible close button for discoverability.
- Guard discrete transition behavior with `@supports`.
