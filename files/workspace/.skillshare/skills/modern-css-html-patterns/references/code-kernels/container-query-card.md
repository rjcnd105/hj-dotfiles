# container-query-card

```html
<article class="card">
  <div class="media" aria-hidden="true"></div>
  <div class="copy">
    <h2>Layout follows the card</h2>
    <p>The base layout is stacked.</p>
  </div>
</article>
```

```css
.card {
  container-type: inline-size;
  display: grid;
  gap: 18px;
}

@container (min-width: 34rem) {
  .card {
    grid-template-columns: minmax(180px, 0.8fr) minmax(0, 1fr);
  }

  .media {
    min-height: 260px;
  }
}
```

