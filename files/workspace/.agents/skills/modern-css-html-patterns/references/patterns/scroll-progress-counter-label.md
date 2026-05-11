# Scroll-driven progress counter label

Catalog ID: `scroll-progress-counter-label`

Use this when progress is a visual enhancement tied to scroll position, not when the percentage is critical application state. The pattern registers an integer custom property, animates it from `0` to `100` with a scroll progress timeline, uses that value as a CSS counter, and moves the label through container query height units.

Source refs: `ev-x-jh3yy-scroll-counter-20260511`, `ev-mdn-animation-timeline-20260511`, `ev-mdn-at-property-20260511`, `ev-mdn-counter-function-20260511`, `ev-mdn-container-query-units-20260511`.

## Technique

- Start with a complete static rail and label.
- Register a typed integer custom property with `@property` so the value can interpolate.
- Inside an `@supports` guard, apply `animation-timeline: scroll(root block)` after the `animation` shorthand.
- Feed the animated value into `counter-reset: complete var(--complete)` and render it with `content: counter(complete) "% complete"`.
- Put the marker inside a definite-height query container, then translate it with `cqh`.

## Support

Support status: `limited`, `non-baseline`.

MDN currently marks `animation-timeline` as Limited availability, so the fallback is part of the pattern rather than an afterthought. `@property` and `counter()` are better supported, but they only produce the intended effect when the scroll timeline drives the typed custom property.

## Accessibility

Generated counter text is visual. Keep meaningful progress text in markup when the value matters to users or automation, and disable scroll-linked motion under `prefers-reduced-motion: reduce`.
