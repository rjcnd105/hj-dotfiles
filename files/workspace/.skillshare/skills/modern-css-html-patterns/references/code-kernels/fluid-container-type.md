# fluid-container-type

```css
.story {
  container-type: inline-size;
}

.story h1 {
  font-size: 2.25rem;
  line-height: 1.05;
  text-wrap: balance;
}

@supports (font-size: 1cqi) {
  .story h1 {
    font-size: clamp(1.75rem, 10cqi, 4.5rem);
  }
}
```

