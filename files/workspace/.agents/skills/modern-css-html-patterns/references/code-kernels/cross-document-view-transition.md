# cross-document-view-transition

Adaptation snippet for `cross-document-view-transition`. Use after shortlisting from `references/index.jsonl` and `references/example-digests.md`. This is not the canonical full example; trust the linked runnable example for verification.


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

