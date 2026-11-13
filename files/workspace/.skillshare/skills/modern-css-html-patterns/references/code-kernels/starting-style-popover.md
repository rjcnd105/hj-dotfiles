# starting-style-popover

```html
<button popovertarget="details-popover">Open details</button>
<aside id="details-popover" popover>
  <h2>Platform primitive first</h2>
  <button popovertarget="details-popover" popovertargetaction="hide">Close</button>
</aside>
```

```css
[popover] {
  opacity: 0;
  transform: translateY(10px) scale(0.98);
  transition: opacity 180ms ease, transform 180ms ease;
}

[popover]:popover-open {
  opacity: 1;
  transform: translateY(0) scale(1);
}

@starting-style {
  [popover]:popover-open {
    opacity: 0;
    transform: translateY(10px) scale(0.98);
  }
}

@supports (transition-behavior: allow-discrete) {
  [popover] {
    transition:
      opacity 180ms ease,
      transform 180ms ease,
      overlay 180ms ease allow-discrete,
      display 180ms ease allow-discrete;
  }
}
```

