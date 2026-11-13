# stepped-fluid-sizing-round

```css
.card {
  --title-fluid: clamp(1.35rem, 1rem + 2vw, 2.5rem);
  --gap-fluid: clamp(0.85rem, 0.5rem + 1.1vw, 1.5rem);
  --media-fluid: clamp(9rem, 22vw, 18rem);
  gap: var(--gap-fluid);
  padding: var(--gap-fluid);
}

.card h2 {
  font-size: var(--title-fluid);
}

.card__media {
  block-size: var(--media-fluid);
}

@supports (font-size: round(1rem, 1px)) {
  .card {
    gap: round(nearest, var(--gap-fluid), 0.25rem);
    padding: round(up, var(--gap-fluid), 0.25rem);
  }

  .card h2 {
    font-size: round(down, var(--title-fluid), 0.125rem);
  }

  .card__media {
    block-size: round(nearest, var(--media-fluid), 0.5rem);
  }
}
```
