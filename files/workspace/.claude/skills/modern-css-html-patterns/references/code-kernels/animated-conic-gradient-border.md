# animated-conic-gradient-border

```html
<article class="glow-card">
  <h2>Live preview</h2>
  <p>A registered angle custom property rotates the border gradient.</p>
</article>
```

```css
@property --border-angle {
  syntax: "<angle>";
  initial-value: 0deg;
  inherits: false;
}

.glow-card {
  --border-angle: 0deg;
  position: relative;
  isolation: isolate;
  border: 1px solid rgba(44, 61, 54, 0.22);
  border-radius: 8px;
  background: #101714;
  color: white;
}

.glow-card::before,
.glow-card::after {
  content: "";
  position: absolute;
  inset: -3px;
  z-index: -1;
  border-radius: inherit;
  background:
    conic-gradient(
      from var(--border-angle),
      #f56b48,
      #f4c95d,
      #58c58b,
      #4e7be8,
      #c15dd8,
      #f56b48
    );
  animation: border-spin 4s linear infinite;
}

.glow-card::before {
  filter: blur(20px);
  opacity: 0.48;
}

@keyframes border-spin {
  to {
    --border-angle: 360deg;
  }
}

@media (prefers-reduced-motion: reduce) {
  .glow-card::before,
  .glow-card::after {
    animation: none;
  }
}
```
