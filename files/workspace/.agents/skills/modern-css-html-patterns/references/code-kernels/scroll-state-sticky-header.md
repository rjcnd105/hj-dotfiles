# scroll-state-sticky-header

```html
<section class="section">
  <header class="section-header">
    <div class="header-shell">
      <h2>Build queue</h2>
      <span class="count">4 items</span>
    </div>
  </header>
  <div class="items">...</div>
</section>
```

```css
.section-header {
  position: sticky;
  top: 0;
  z-index: var(--sticky-layer, 1);
  block-size: 64px;
  container-type: scroll-state;
  container-name: sticky-hd;
}

.header-shell {
  min-block-size: 64px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  transition: background-color 180ms ease, box-shadow 180ms ease;
}

@container sticky-hd scroll-state(stuck: top) {
  .header-shell {
    background: #102a43;
    color: #fff;
    box-shadow: 0 12px 24px rgba(15, 23, 42, 0.22);
  }
}
```

