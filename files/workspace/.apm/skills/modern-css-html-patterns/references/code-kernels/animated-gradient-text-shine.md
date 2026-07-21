# animated-gradient-text-shine

```html
<h1 class="shine-text">Release approved</h1>
```

```css
.shine-text {
  color: #24513d;
}

@supports ((background-clip: text) or (-webkit-background-clip: text)) {
  .shine-text {
    background:
      linear-gradient(
        110deg,
        rgba(36, 81, 61, 0.42) 18%,
        rgba(224, 97, 73, 0.96) 42%,
        rgba(255, 248, 216, 0.98) 50%,
        rgba(224, 97, 73, 0.96) 58%,
        rgba(36, 81, 61, 0.42) 82%
      );
    background-size: 220% 100%;
    background-position: 0 center;
    background-clip: text;
    -webkit-background-clip: text;
    color: transparent;
    -webkit-text-fill-color: transparent;
    animation: text-shine 2.8s linear infinite;
  }
}

@keyframes text-shine {
  to {
    background-position: 220% center;
  }
}

@media (prefers-reduced-motion: reduce) {
  .shine-text {
    animation: none;
    background-position: 100% center;
  }
}
```
