# Scroll-State Sticky Header

Catalog ID: `scroll-state-sticky-header`

Use this when one or more sticky section headers should visually react to being stuck without a scroll listener.

Avoid it when the state must drive business logic or analytics; this is a styling state, not application state.

Support: cataloged as Baseline 2026 target. Older browsers keep the sticky fallback.

Source refs: `ev-x-kara-scroll-state-20260508`, `ev-mdn-scroll-state-queries-20260508`.

Example: `examples/scroll-state-sticky-header/index.html`.

Notes:

- Start with a complete sticky header style.
- Put `container-type: scroll-state` on each sticky `.section-header`.
- Style a descendant wrapper from `@container <name> scroll-state(stuck: top)`.
- Keep the sticky container's block size stable. Do not animate padding, height, or other layout-affecting properties at the stuck boundary; use paint/composite changes such as color, shadow, or transform on descendants.
- Give later sequential headers an equal or higher stacking layer so each incoming header cleanly replaces the previous stuck header.
- Keep scrollable regions keyboard reachable when they are not the page scroll.
