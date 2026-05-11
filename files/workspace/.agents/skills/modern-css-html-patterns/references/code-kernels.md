# Code Kernels

Use this file after shortlisting from `index.jsonl` and `example-digests.md`, before opening a full runnable example. Each section is intentionally smaller than the full HTML and gives the core CSS/HTML needed for first-pass code suggestions.

These kernels are adaptation snippets, not canonical full examples. If a kernel conflicts with the runnable example, trust the runnable example, fix the kernel, and run the validator.

## layered-shadow-border

```css
.surface {
  border-radius: 8px;
  background: #fbfcfd;
  box-shadow:
    inset 0 0 0 1px rgba(255, 255, 255, 0.95),
    inset 0 -1px 0 rgba(16, 24, 40, 0.08),
    0 1px 2px rgba(16, 24, 40, 0.08),
    0 18px 44px rgba(16, 24, 40, 0.16);
}

@supports (color: color-mix(in oklab, white, black)) {
  .surface {
    box-shadow:
      inset 0 0 0 1px color-mix(in oklab, white 92%, transparent),
      inset 0 -1px 0 color-mix(in oklab, #111827 12%, transparent),
      0 1px 2px color-mix(in oklab, #111827 8%, transparent),
      0 18px 44px color-mix(in oklab, #111827 17%, transparent);
  }
}
```

## starting-style-popover

```html
<button popovertarget="details-popover">Open details</button>
<aside id="details-popover" popover>
  <h2>Platform primitive first</h2>
  <button popovertarget="details-popover" popovertargetaction="hide">Close</button>
</aside>
```

```css
[popover] {
  opacity: 0;
  transform: translateY(10px) scale(0.98);
  transition: opacity 180ms ease, transform 180ms ease;
}

[popover]:popover-open {
  opacity: 1;
  transform: translateY(0) scale(1);
}

@starting-style {
  [popover]:popover-open {
    opacity: 0;
    transform: translateY(10px) scale(0.98);
  }
}

@supports (transition-behavior: allow-discrete) {
  [popover] {
    transition:
      opacity 180ms ease,
      transform 180ms ease,
      overlay 180ms ease allow-discrete,
      display 180ms ease allow-discrete;
  }
}
```

## scroll-state-sticky-header

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

## container-query-card

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

## anchor-tooltip-popover

```html
<button class="help" popovertarget="hint" aria-label="Show format guidance">?</button>
<div id="hint" popover>Use JSON when another system imports the export.</div>
```

```css
.help {
  anchor-name: --help-trigger;
}

[popover] {
  position: fixed;
  inset: auto 24px 24px auto;
  margin: 0;
}

@supports (anchor-name: --x) {
  [popover] {
    position-anchor: --help-trigger;
    position-area: top;
    justify-self: anchor-center;
    margin-block-end: 10px;
  }
}
```

## fluid-container-type

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

## css-if-style-query

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

## sequential-custom-property-animation

```html
<ul class="stack">
  <li style="--i: 0">Source</li>
  <li style="--i: 1">Catalog</li>
  <li style="--i: 2">Example</li>
</ul>
```

```css
.stack > li {
  --step-delay: calc(var(--i) * 85ms);
  animation: reveal 460ms cubic-bezier(0.2, 0.8, 0.2, 1) both;
  animation-delay: var(--step-delay);
}

@keyframes reveal {
  from { opacity: 0; transform: translateY(12px); }
  to { opacity: 1; transform: translateY(0); }
}

@media (prefers-reduced-motion: reduce) {
  .stack > li {
    animation: none;
  }
}
```

## anchor-function-sidenote

```html
<p>
  The note starts in the reading flow
  <sup class="note-marker" aria-hidden="true">1</sup>.
</p>
<aside class="sidenote">1. This remains inline without anchor support.</aside>
```

```css
.note-marker {
  anchor-name: --sidenote-one;
}

.sidenote {
  display: block;
  margin-block: 8px 22px;
}

@media (min-width: 860px) {
  @supports (top: anchor(--sidenote-one top, 0px)) {
    .sidenote {
      position: absolute;
      position-anchor: --sidenote-one;
      inset-inline-start: calc(100% + 36px);
      top: anchor(--sidenote-one top, 0px);
      width: 220px;
      margin: 0;
    }
  }
}
```

## previous-sibling-has-combinator

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

## cross-document-view-transition

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

## scroll-progress-counter-label

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
