# sequential-custom-property-animation

```html
<ul class="stack">
  <li style="--i: 0">Source</li>
  <li style="--i: 1">Catalog</li>
  <li style="--i: 2">Example</li>
</ul>
```

```css
.stack > li {
  --step-delay: calc(var(--i) * 85ms);
  animation: reveal 460ms cubic-bezier(0.2, 0.8, 0.2, 1) both;
  animation-delay: var(--step-delay);
}

@keyframes reveal {
  from { opacity: 0; transform: translateY(12px); }
  to { opacity: 1; transform: translateY(0); }
}

@media (prefers-reduced-motion: reduce) {
  .stack > li {
    animation: none;
  }
}
```

