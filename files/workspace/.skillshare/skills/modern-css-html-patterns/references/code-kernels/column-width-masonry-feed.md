# column-width-masonry-feed

```html
<ol class="masonry-feed">
  <li class="masonry-card">Short card</li>
  <li class="masonry-card">Taller card with more content</li>
  <li class="masonry-card">Another card</li>
</ol>
```

```css
.masonry-feed {
  list-style: none;
  margin: 0;
  padding: 0;
  display: grid;
  gap: 1rem;
}

.masonry-card {
  break-inside: avoid;
}

@supports (column-width: 16rem) {
  .masonry-feed {
    display: block;
    column-width: 16rem;
    column-gap: 1rem;
  }

  .masonry-card {
    display: inline-block;
    width: 100%;
    margin-block: 0 1rem;
  }
}
```
