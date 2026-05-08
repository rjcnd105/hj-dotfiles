# Layered Shadow Border

Catalog ID: `layered-shadow-border`

Use this when a component needs a crisp hairline edge, inner highlight, and soft elevation without extra wrapper DOM.

Avoid it when the edge color must be a real layout-affecting border or when the element already has heavy shadow semantics.

Support: broadly available CSS shadows, with optional `color-mix()` enhancement. The catalog records a fixed-color fallback.

Source refs: `ev-x-nilseller-shadow-20260508`, `ev-mdn-cascade-layers-20260508`.

Example: `examples/layered-shadow-border/index.html`.

Notes:

- Put the sharpest inset shadow first.
- Keep the outer shadow low contrast so it does not read as a card-in-card surface.
- Pair with `@layer` only when the surrounding app already uses cascade layers.
