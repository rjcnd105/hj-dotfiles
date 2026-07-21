# Relative Color Token Palette

Catalog ID: `relative-color-token-palette`

Use this when a component needs hover, active, soft-surface, border, shadow, or accent tokens derived from one base color.

Avoid it when the palette values are brand-approved constants that must not move, or when older browser support requires every derived token to match exactly.

Support: CSS relative color syntax is Baseline Newly available. Keep absolute fallback tokens first, then replace them inside `@supports (color: oklch(from red l c h))`.

Source refs: `ev-theosoti-relative-colors-20260514`, `ev-mdn-relative-colors-20260514`, `ev-webdev-css-relative-color-baseline-20260514`.

## Technique

- Define one input token such as `--tone`.
- Provide absolute fallback values for `--tone-strong`, `--tone-soft`, `--tone-border`, and `--tone-shadow`.
- In a relative-color support query, derive those tokens from `--tone` with `oklch(from ...)` for perceptual lightness shifts and `rgb(from ... / alpha)` for translucent borders and shadows.
- Use `currentColor` as the origin when an icon, badge, or border should follow the element text color.

## Accessibility

Relative colors preserve relationships, not contrast guarantees. Check generated foreground/background pairs for every allowed base color, especially if users or themes can change `--tone`.

Example: `examples/relative-color-token-palette/index.html`.

Notes:

- `rgb(from var(--tone) r g b / 0.2)` is a good fit for alpha-only variants.
- `oklch(from var(--tone) calc(l - 0.16) c h)` is a better default for lightness shifts than HSL when colors span multiple hues.
- Do not test `@supports` with a custom property; use a literal color in the feature query and assign custom-property origins inside the block.
