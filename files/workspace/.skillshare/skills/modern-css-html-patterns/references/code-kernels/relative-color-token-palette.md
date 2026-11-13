# relative-color-token-palette

```html
<article class="tone-card" style="--tone: #315eea">
  <strong>Primary</strong>
  <p>One base token derives surface, border, shadow, and accent colors.</p>
  <span class="badge">CurrentColor badge</span>
</article>
```

```css
.tone-card {
  --tone: #315eea;
  --tone-strong: #1e348b;
  --tone-soft: #eef3ff;
  --tone-accent: #6a57d9;
  --tone-border: rgba(49, 94, 234, 0.22);
  --tone-shadow: rgba(49, 94, 234, 0.18);

  color: var(--tone-strong);
  background: var(--tone-soft);
  border: 1px solid var(--tone-border);
  box-shadow: 0 18px 32px var(--tone-shadow);
}

.badge {
  color: var(--tone);
  border: 1px solid var(--tone-border);
  background: var(--tone-soft);
}

@supports (color: oklch(from red l c h)) {
  .tone-card {
    --tone-strong: oklch(from var(--tone) calc(l - 0.18) c h);
    --tone-soft: oklch(from var(--tone) min(calc(l + 0.44), 0.96) calc(c * 0.3) h);
    --tone-accent: oklch(from var(--tone) l c calc(h + 28));
    --tone-border: rgb(from var(--tone) r g b / 0.22);
    --tone-shadow: rgb(from var(--tone) r g b / 0.18);
  }

  .badge {
    border-color: rgb(from currentColor r g b / 0.22);
    background: oklch(from currentColor min(calc(l + 0.44), 0.96) calc(c * 0.28) h);
  }
}
```
