# Fluid Container Type

Catalog ID: `fluid-container-type`

Use this when typography should scale with a component or editorial measure rather than the viewport.

Avoid it when the type must align to a global responsive scale shared across unrelated components.

Support: cataloged as Baseline 2025. The fallback uses bounded viewport-based `clamp()`.

Source refs: `ev-webdevvisuals-fluid-typography-20260508`, `ev-mdn-container-queries-20260508`, `ev-webdev-baseline-2026-20260508`.

Example: `examples/fluid-container-type/index.html`.

Notes:

- Always keep minimum and maximum values in accessible `rem` units.
- Prefer `cqi` for inline-size responsiveness inside writing-mode-aware layouts.
- Pair large display text with `text-wrap: balance` only when line breaks remain readable.
