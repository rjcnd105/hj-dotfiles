# layered-shadow-border

Adaptation snippet for `layered-shadow-border`. Use after shortlisting from `references/index.jsonl` and `references/example-digests.md`. This is not the canonical full example; trust the linked runnable example for verification.


```css
.surface {
  border-radius: 8px;
  background: #fbfcfd;
  box-shadow:
    inset 0 0 0 1px rgba(255, 255, 255, 0.95),
    inset 0 -1px 0 rgba(16, 24, 40, 0.08),
    0 1px 2px rgba(16, 24, 40, 0.08),
    0 18px 44px rgba(16, 24, 40, 0.16);
}

@supports (color: color-mix(in oklab, white, black)) {
  .surface {
    box-shadow:
      inset 0 0 0 1px color-mix(in oklab, white 92%, transparent),
      inset 0 -1px 0 color-mix(in oklab, #111827 12%, transparent),
      0 1px 2px color-mix(in oklab, #111827 8%, transparent),
      0 18px 44px color-mix(in oklab, #111827 17%, transparent);
  }
}
```

