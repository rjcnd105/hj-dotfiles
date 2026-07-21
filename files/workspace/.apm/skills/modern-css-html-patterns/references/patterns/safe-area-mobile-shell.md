# Mobile Safe-Area Shell

Catalog ID: `safe-area-mobile-shell`

Use this when a mobile screen opts into edge-to-edge rendering and fixed or sticky interface chrome must avoid notches, rounded corners, home indicators, and similar system UI.

Avoid it when the page is not edge-to-edge or when ordinary document flow already keeps controls away from device edges. Do not add this as a blanket reset to every component; put it at the shell, page chrome, or fixed-action boundary.

Support: `env()` is Baseline widely available. Non-zero `safe-area-inset-*` values are device and viewport dependent, and desktop browsers usually resolve them to `0`.

Source refs: `ev-polypane-safe-area-insets-20260513`, `ev-mdn-env-safe-area-20260513`, `ev-mdn-viewport-fit-20260513`.

Example: `examples/safe-area-mobile-shell/index.html`.

Notes:

- Opt into edge-to-edge layout with `<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">`.
- Add normal spacing plus the safe-area value. The inset is not visual margin; it only describes space occupied by device UI.
- Keep fallback declarations usable when safe-area values are zero. Use `env(..., 0px)` and avoid making tap targets depend on a non-zero inset.
- Reserve `safe-area-max-inset-*` for a separate limited-support pattern. This pattern uses the dynamic `safe-area-inset-*` values only.
