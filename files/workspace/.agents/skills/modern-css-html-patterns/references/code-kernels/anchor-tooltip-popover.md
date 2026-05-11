# anchor-tooltip-popover

Adaptation snippet for `anchor-tooltip-popover`. Use after shortlisting from `references/index.jsonl` and `references/example-digests.md`. This is not the canonical full example; trust the linked runnable example for verification.


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

