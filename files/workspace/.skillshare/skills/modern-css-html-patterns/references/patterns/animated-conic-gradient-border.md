# Animated Conic Gradient Border

Catalog ID: `animated-conic-gradient-border`

Use this when a featured card or callout needs a decorative animated border without SVG, canvas, or JavaScript.

Avoid it for dense lists, form surfaces, or any state where animation would compete with reading or decision-making.

Support: `conic-gradient()` is widely available and `@property` is Baseline 2024. Keep a static border fallback, then register an angle custom property for smooth rotation when supported.

Source refs: `ev-theosoti-animated-gradient-borders-20260514`, `ev-mdn-conic-gradient-20260514`, `ev-mdn-at-property-gradient-border-20260514`.

## Technique

- Give the card a solid background and `position: relative`.
- Paint the border on pseudo-elements that extend past the card with a negative `inset`.
- Register an angle custom property with `@property` so it interpolates as an `<angle>`.
- Drive a `conic-gradient(from var(--border-angle), ...)` from keyframes.
- Duplicate the gradient layer with blur when a glow is wanted.

## Accessibility

The motion is decorative. Use `prefers-reduced-motion` to stop the rotation and keep a static border.

Example: `examples/animated-conic-gradient-border/index.html`.

Notes:

- Repeat the first color stop at the end of the conic gradient to avoid a visible seam.
- Keep content above the pseudo-elements with `z-index` and `isolation`.
- The card face must be opaque enough to prevent the gradient from competing with content.
