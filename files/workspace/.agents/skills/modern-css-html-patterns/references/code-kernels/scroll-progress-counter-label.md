# scroll-progress-counter-label

Adaptation snippet for `scroll-progress-counter-label`. Use after shortlisting from `references/index.jsonl` and `references/example-digests.md`. This is not the canonical full example; trust the linked runnable example for verification.


```css
@property --complete {
  syntax: "<integer>";
  inherits: false;
  initial-value: 0;
}

.rail {
  container-type: size;
  block-size: clamp(380px, 62svh, 560px);
  position: relative;
}

.status {
  --complete: 0;
  counter-reset: complete var(--complete);
  position: absolute;
  inset-block-start: 0;
}

@supports (animation-timeline: scroll(root block)) and (translate: 0 1cqh) {
  .status {
    animation: count-progress linear both;
    animation-timeline: scroll(root block);
    translate: 0 clamp(0px, calc(var(--complete) * 1cqh), calc(100cqh - 46px));
  }

  .status::after {
    content: counter(complete) "% complete";
  }
}

@keyframes count-progress {
  to { --complete: 100; }
}
```
