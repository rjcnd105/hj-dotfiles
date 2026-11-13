# Cross-Document Navigation With @view-transition

Catalog ID: `cross-document-view-transition`

Use this when a same-origin multi-page app needs lightweight navigation motion without turning the route into a client-side app.

Avoid it when cross-browser parity is required today. MDN marks `@view-transition` as limited availability, so ordinary links must remain the complete fallback.

Support: non-Baseline / limited. Both the current and destination documents must opt in with `@view-transition { navigation: auto; }`.

Source refs: `ev-mdn-view-transition-at-rule-20260508`.

## Technique

- Keep navigation as ordinary same-origin links.
- Add `@view-transition { navigation: auto; }` to both documents.
- Animate `::view-transition-old(root)` and `::view-transition-new(root)` while leaving unsupported browsers with normal page loads.

## Accessibility

Respect `prefers-reduced-motion`. Do not replace links with client-side routing only to obtain transition motion.

Example: `examples/cross-document-view-transition/index.html`.

Notes:

- Put the at-rule in both documents involved in the navigation.
- Keep links real; the transition is enhancement, not routing logic.
- Disable custom transition animation under `prefers-reduced-motion`.
