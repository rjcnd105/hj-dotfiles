# grid-height-transition

```html
<button class="trigger" type="button" aria-expanded="true" aria-controls="details-panel">
  Toggle details
</button>
<section class="reveal" id="details-panel" aria-label="Details">
  <div>
    <p>Dynamic content can be any height.</p>
  </div>
</section>
```

```css
.reveal {
  display: grid;
  grid-template-rows: 0fr;
  transition: grid-template-rows 360ms ease;
}

.reveal > div {
  overflow: hidden;
}

.trigger[aria-expanded="true"] + .reveal {
  grid-template-rows: 1fr;
}

@media (prefers-reduced-motion: reduce) {
  .reveal {
    transition: none;
  }
}
```

```js
const trigger = document.querySelector(".trigger");
const panel = document.getElementById(trigger.getAttribute("aria-controls"));

trigger.addEventListener("click", () => {
  const expanded = trigger.getAttribute("aria-expanded") === "true";
  trigger.setAttribute("aria-expanded", String(!expanded));
  if (expanded) {
    panel.setAttribute("aria-hidden", "true");
    panel.setAttribute("inert", "");
  } else {
    panel.removeAttribute("aria-hidden");
    panel.removeAttribute("inert");
  }
});
```
