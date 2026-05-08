# Anchor Tooltip Popover

Catalog ID: `anchor-tooltip-popover`

Use this when a small native popover should visually attach to a trigger without JavaScript geometry code.

Avoid it for required instructions or validation errors. Tooltips should be supplemental, not the only way to understand a control.

Support: anchor positioning is recorded as non-Baseline/limited. Native popover behavior remains the fallback.

Source refs: `ev-x-jh3yy-anchor-nav-20260508`, `ev-css-tip-tooltip-anchor-20260508`, `ev-mdn-anchor-positioning-20260508`, `ev-mdn-popover-api-20260508`.

Example: `examples/anchor-tooltip-popover/index.html`.

Notes:

- Place production behavior in the native popover first.
- Add anchor positioning inside `@supports (anchor-name: --x)`.
- Keep text short enough that fallback placement remains acceptable.
