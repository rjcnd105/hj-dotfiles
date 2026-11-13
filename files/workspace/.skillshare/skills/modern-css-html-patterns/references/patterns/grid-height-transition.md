# Grid Height Transition

Catalog ID: `grid-height-transition`

Use this when an accordion, disclosure, or dropdown needs to animate between collapsed and dynamic-content height without hardcoded `max-height`.

Avoid it when the content is virtualized, extremely long, or when the disclosure state must be handled by a richer native primitive such as `<details>` plus application state.

Support: CSS Grid and `grid-template-rows` are widely available; MDN records compatible `grid-template-rows` lists as animatable, but target browsers should still verify the `0fr` to `1fr` disclosure pattern. Reduced-motion fallback should remove the transition.

Source refs: `ev-theosoti-height-transition-20260514`, `ev-mdn-grid-template-rows-20260514`.

## Technique

- Wrap the dynamic content in a grid container.
- Collapse with `grid-template-rows: 0fr`.
- Expand with `grid-template-rows: 1fr`.
- Put `overflow: hidden` on the inner content wrapper so the row track clips during the transition.
- Keep the control state in real markup; the example uses a button and a small script to sync `aria-expanded`, `aria-hidden`, and `inert`.

## Accessibility

Keep the toggle reachable, connect it with `aria-controls`, and hide the collapsed region from assistive technology when the panel is closed. Remove the transition under `prefers-reduced-motion`.

Example: `examples/grid-height-transition/index.html`.

Notes:

- This avoids arbitrary `max-height` values and the timing drift they cause.
- The inner wrapper is still required because the grid row clips the child, not arbitrary descendants.
- `calc-size(auto)` is intentionally not the primary pattern because current support is narrower.
