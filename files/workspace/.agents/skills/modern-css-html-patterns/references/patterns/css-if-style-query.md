# CSS if() Branch With Static Fallback

Catalog ID: `css-if-style-query`

Use this only for experiments or progressive enhancement where the fallback is already complete.

Avoid it for production-critical behavior until the target browser set explicitly supports CSS `if()`.

Support: recorded as experimental and non-Baseline. The catalog marks this pattern as `limited-fallback-only`.

Source refs: `ev-css-tip-if-trick-20260508`, `ev-mdn-css-if-20260508`.

Example: `examples/css-if-style-query/index.html`.

Notes:

- Put production styles outside the experimental branch.
- Wrap the branch in `@supports`.
- Keep comments or docs close to the code because the syntax may still change.
