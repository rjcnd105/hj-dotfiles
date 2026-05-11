# Cross-Document Navigation With @view-transition

Catalog ID: `cross-document-view-transition`

Use this when a same-origin multi-page app needs lightweight navigation motion without turning the route into a client-side app.

Avoid it when cross-browser parity is required today. MDN marks `@view-transition` as limited availability, so ordinary links must remain the complete fallback.

Support: non-Baseline / limited. Both the current and destination documents must opt in with `@view-transition { navigation: auto; }`.

Source refs: `ev-mdn-view-transition-at-rule-20260508`.

Example: `examples/cross-document-view-transition/index.html`.

Notes:

- Put the at-rule in both documents involved in the navigation.
- Keep links real; the transition is enhancement, not routing logic.
- Disable custom transition animation under `prefers-reduced-motion`.
