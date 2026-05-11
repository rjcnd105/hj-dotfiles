# anchor-function-sidenote

```html
<p>
  The note starts in the reading flow
  <sup class="note-marker" aria-hidden="true">1</sup>.
</p>
<aside class="sidenote">1. This remains inline without anchor support.</aside>
```

```css
.note-marker {
  anchor-name: --sidenote-one;
}

.sidenote {
  display: block;
  margin-block: 8px 22px;
}

@media (min-width: 860px) {
  @supports (top: anchor(--sidenote-one top, 0px)) {
    .sidenote {
      position: absolute;
      position-anchor: --sidenote-one;
      inset-inline-start: calc(100% + 36px);
      top: anchor(--sidenote-one top, 0px);
      width: 220px;
      margin: 0;
    }
  }
}
```

