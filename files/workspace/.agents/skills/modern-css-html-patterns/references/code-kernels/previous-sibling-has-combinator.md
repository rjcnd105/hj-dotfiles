# previous-sibling-has-combinator

```html
<ol class="steps">
  <li>Draft</li>
  <li>Review</li>
  <li class="current">Ship</li>
  <li>Archive</li>
</ol>
```

```css
.current {
  border-color: #2f6f7e;
}

@supports selector(li:has(+ li)) {
  .steps > li:has(+ .current) {
    border-color: #8bbf9f;
    background: #f0f8f3;
  }
}
```

