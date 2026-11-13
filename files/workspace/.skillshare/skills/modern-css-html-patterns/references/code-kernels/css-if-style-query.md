# css-if-style-query

```css
.notice {
  --tone: success;
  --fallback-bg: #eef8f1;
  --fallback-border: #8fc8a1;
  --fallback-ink: #17462a;

  color: var(--fallback-ink);
  border: 1px solid var(--fallback-border);
  background: var(--fallback-bg);
}

.notice[data-tone="warning"] {
  --tone: warning;
  --fallback-bg: #fff7e6;
  --fallback-border: #d6a94f;
  --fallback-ink: #5b3d0b;
}

@supports (color: if(style(--tone: success): green; else: blue)) {
  .notice {
    color: if(style(--tone: success): #17462a; else: #5b3d0b);
    border-color: if(style(--tone: success): #8fc8a1; else: #d6a94f);
    background: if(style(--tone: success): #eef8f1; else: #fff7e6);
  }
}
```

