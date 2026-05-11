# Previous-Sibling Styling With :has(+ ...)

Catalog ID: `previous-sibling-has-combinator`

Use this when an element should style itself based on the next sibling without adding another class.

Avoid it for broad selectors over very large dynamic DOMs. Keep the selector specific and scoped.

Support: `+` is widely available; the modern part is `:has()`, cataloged as Baseline 2023.

Source refs: `ev-x-mozdevnet-next-sibling-20260508`, `ev-mdn-next-sibling-combinator-20260508`, `ev-mdn-has-selector-20260508`.

Example: `examples/previous-sibling-has-combinator/index.html`.

Notes:

- Use `@supports selector(...)` around the relational enhancement.
- Keep a direct class on the real current/active item as the fallback.
- Prefer this for small lists, steppers, breadcrumbs, and adjacent status markers.
