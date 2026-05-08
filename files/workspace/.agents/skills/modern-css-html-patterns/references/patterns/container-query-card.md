# Container Query Card

Catalog ID: `container-query-card`

Use this when a component should adapt to the space it receives rather than the viewport.

Avoid it when viewport-level layout is the actual product rule; media queries are clearer in that case.

Support: cataloged as Baseline 2024. The fallback is a readable single-column card.

Source refs: `ev-x-kara-container-query-20260508`, `ev-mdn-container-queries-20260508`.

Example: `examples/container-query-card/index.html`.

Notes:

- Put `container-type: inline-size` on the component boundary, not a random ancestor.
- Design the base style as the narrow version.
- Use container query units only with sensible `rem` bounds.
