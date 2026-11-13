# anchor-tooltip-popover

```html
<button class="help" popovertarget="hint" aria-label="Show format guidance">?</button>
<div id="hint" popover>Use JSON when another system imports the export.</div>
```

```css
.help {
  anchor-name: --help-trigger;
}

[popover] {
  position: fixed;
  inset: auto 24px 24px auto;
  margin: 0;
}

@supports (anchor-name: --x) {
  [popover] {
    position-anchor: --help-trigger;
    position-area: top;
    justify-self: anchor-center;
    margin-block-end: 10px;
  }
}
```

