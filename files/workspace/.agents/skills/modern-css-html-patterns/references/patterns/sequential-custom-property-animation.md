# Sequential Custom Property Animation

Catalog ID: `sequential-custom-property-animation`

Use this when a small list or cluster should reveal in a controlled sequence without JavaScript timers.

Avoid it for critical content that must be instantly readable or for long lists where delays become frustrating.

Support: broadly available CSS custom properties and animation. Reduced-motion fallback is required.

Source refs: `ev-css-tip-sequential-animations-20260508`.

Example: `examples/sequential-custom-property-animation/index.html`.

Notes:

- Store the index in `--i` and compute delay from it.
- Keep DOM order the same as visual order.
- Use `prefers-reduced-motion: reduce` to remove delay and animation.
