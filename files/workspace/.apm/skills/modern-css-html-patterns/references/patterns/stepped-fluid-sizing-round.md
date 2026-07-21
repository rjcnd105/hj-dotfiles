# Stepped Fluid Sizing With round()

Catalog ID: `stepped-fluid-sizing-round`

Use this when a component should stay fluid but its typography, spacing, or dimensions need to land on predictable design-system steps.

Avoid it when the value and interval are both static. In that case, write the final value directly.

Support: `round()` is cataloged as Baseline 2024. The fallback keeps the original unrounded `clamp()` value before the enhancement applies.

Source refs: `ev-ishadeed-css-round-20260518`, `ev-mdn-css-round-20260518`, `ev-webdev-stepped-value-functions-20260518`.

## Technique

- Put the fluid value in a custom property, usually from `clamp()`.
- Apply the fluid value directly as the fallback.
- In `@supports`, wrap the same variable in `round()` and choose the step that matches the design scale.
- Use `down` for type that should not overshoot, `up` for containers that must reserve space, and `nearest` for visual rhythm.

## Accessibility

Keep readable `rem` bounds in the original `clamp()` expression. Rounding should refine layout rhythm, not become the only thing preserving legible text size or spacing.

Example: `examples/stepped-fluid-sizing-round/index.html`.

Notes:

- Unsupported browsers drop the rounded declaration, so the unrounded declaration must come first.
- If adapting the article's container query unit examples, verify the `cqi` or `cqw` support target separately.
- Treat the `calc-size(auto)` height-snapping variant as a separate, narrower-support enhancement.
