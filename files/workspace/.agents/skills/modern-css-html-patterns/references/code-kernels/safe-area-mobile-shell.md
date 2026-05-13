# safe-area-mobile-shell

```html
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">

<style>
  :root {
    --shell-gap: 16px;
    --safe-top: 0px;
    --safe-right: 0px;
    --safe-bottom: 0px;
    --safe-left: 0px;
  }

  @supports (padding: max(0px, env(safe-area-inset-top))) {
    :root {
      --safe-top: env(safe-area-inset-top, 0px);
      --safe-right: env(safe-area-inset-right, 0px);
      --safe-bottom: env(safe-area-inset-bottom, 0px);
      --safe-left: env(safe-area-inset-left, 0px);
    }
  }

  .app-shell {
    min-block-size: 100vh;
    padding: var(--shell-gap);
    padding-block-start: max(var(--shell-gap), calc(var(--shell-gap) + var(--safe-top)));
    padding-inline-end: max(var(--shell-gap), calc(var(--shell-gap) + var(--safe-right)));
    padding-block-end: max(var(--shell-gap), calc(var(--shell-gap) + var(--safe-bottom)));
    padding-inline-start: max(var(--shell-gap), calc(var(--shell-gap) + var(--safe-left)));
  }

  .floating-action {
    position: fixed;
    inset-inline-end: var(--shell-gap);
    inset-inline-end: max(var(--shell-gap), calc(var(--shell-gap) + var(--safe-right)));
    inset-block-end: var(--shell-gap);
    inset-block-end: max(var(--shell-gap), calc(var(--shell-gap) + var(--safe-bottom)));
  }
</style>
```
