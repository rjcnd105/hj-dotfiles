# cross-document-view-transition

```css
@view-transition {
  navigation: auto;
}

::view-transition-old(root) {
  animation: 180ms ease both move-out;
}

::view-transition-new(root) {
  animation: 220ms ease both move-in;
}

@keyframes move-out {
  to { opacity: 0; transform: translateY(-18px); }
}

@keyframes move-in {
  from { opacity: 0; transform: translateY(18px); }
}

@media (prefers-reduced-motion: reduce) {
  ::view-transition-old(root),
  ::view-transition-new(root) {
    animation: none;
  }
}
```

