# Animated Gradient Text Shine

Catalog ID: `animated-gradient-text-shine`

Use this when a short heading, label, or celebratory state needs a decorative sweep without extra markup or JavaScript.

Avoid it for long body copy, critical status text, or any label where the animated shine would be the only cue.

Support: `background-clip: text`, CSS gradients, and keyframe animation are widely available. Keep the readable solid text color as the base style, and only make the text transparent inside a `background-clip: text` support query.

Source refs: `ev-x-alicalimli-text-shine-20260514`, `ev-mdn-background-clip-text-20260514`, `ev-mdn-keyframes-20260514`, `ev-mdn-prefers-reduced-motion-20260514`.

## Technique

- Render real text with a normal readable `color` first.
- In `@supports`, paint a wide `linear-gradient()` on the text box and clip it to the glyphs with `background-clip: text`.
- Animate `background-position`, not layout properties, so the sweep moves without reflow.
- Stop the animation under `prefers-reduced-motion: reduce` and leave a static gradient or the solid fallback color.

## Accessibility

The shine is decorative. Do not rely on it to communicate status, availability, or selection, and test contrast across the animated gradient stops.

Example: `examples/animated-gradient-text-shine/index.html`.

Notes:

- Keep `color` outside the support query so unsupported browsers do not get invisible text.
- Pair `background-clip: text` with `-webkit-background-clip: text` and `-webkit-text-fill-color: transparent` where the target browser set needs it.
- Keep the source tweet as inspiration only; the local kernel corrects the visible `@ keyframes` spacing into valid `@keyframes` syntax.
