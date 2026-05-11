# Source Details

This file makes `source_refs` durable enough for later review. Each heading must match a `source_event_id` from `logs/ingest.jsonl` and `references/source-seeds.jsonl`.

The JSONL rows are the machine-readable source log. This file is the human-readable retrieval note: what was actually accessible, what was extracted or reconstructed, and what should be rechecked before relying on the source again.

## ev-x-nilseller-shadow-20260508

- URL: https://x.com/nilseller/status/2051682077003960351
- Access: direct X page was recorded as accessible on 2026-05-08.
- Role: inspiration for `layered-shadow-border`.
- Durable note: keep this as visual inspiration only. The runnable example is reconstructed with local CSS and does not depend on source code from the post.
- Recheck trigger: if using this as more than visual inspiration, refetch the post or locate an independent demo/source.

## ev-x-jh3yy-anchor-nav-20260508

- URL: https://x.com/jh3yy/status/2051284375434633673
- Access: direct X page was recorded as accessible on 2026-05-08.
- Role: inspiration for anchor-positioned navigation and related anchor/popover placement ideas.
- Durable note: current catalog uses this only as inspiration for `anchor-tooltip-popover`; support claims come from MDN anchor positioning and popover docs.
- Recheck trigger: if adding a magnetic navigation example, fetch current post/demo metadata and create a separate pattern instead of overloading the tooltip pattern.

## ev-x-kara-scroll-state-20260508

- URL: https://x.com/KaraBharat/status/2051258693451457007
- Access: direct X page was recorded as accessible on 2026-05-08.
- Role: inspiration for `scroll-state-sticky-header`.
- Durable note: the indexed pattern is the technique, not a copied demo: each sticky `.section-header` gets `container-type: scroll-state` and the descendant shell is styled by `@container sticky-hd scroll-state(stuck: top)`.
- Recheck trigger: if the source becomes inaccessible, rely on the MDN scroll-state source for syntax and keep this as provenance for the sequential sticky-header idea.

## ev-x-kara-starting-style-20260508

- URL: https://x.com/KaraBharat/status/2048628680524738969
- Access: direct X page was recorded as accessible on 2026-05-08.
- Role: inspiration for `starting-style-popover`.
- Durable note: support and syntax are grounded in MDN `@starting-style` and Popover API docs. The local example is a reconstructed practical popover transition.
- Recheck trigger: re-open the post only if the visual motion details need to match the original inspiration more closely.

## ev-x-kara-container-query-20260508

- URL: https://x.com/KaraBharat/status/2048409378315993507
- Access: direct X page was recorded as accessible on 2026-05-08.
- Role: inspiration for `container-query-card`.
- Durable note: the example demonstrates component-owned responsive layout using `container-type: inline-size`; support comes from MDN container query docs.
- Recheck trigger: if adding another container query variant, check whether it is distinct from the card layout before adding a new catalog entry.

## ev-webdevvisuals-fluid-typography-20260508

- URL: https://www.webdevvisuals.com/visuals/css-fluid-typography
- Access: article page was recorded as accessible on 2026-05-08.
- Role: article inspiration for `fluid-container-type`.
- Durable note: the local example uses bounded `clamp()` plus container query units so type follows component width rather than viewport width.
- Recheck trigger: if the site structure changes, use the cataloged CSS features and MDN container-query support source to preserve the pattern.

## ev-css-tip-if-trick-20260508

- URL: https://css-tip.com/if-trick/
- Access: article page was recorded as accessible on 2026-05-08.
- Role: article inspiration for `css-if-style-query`.
- Durable note: the catalog intentionally marks this fallback-first and experimental. Production behavior must remain outside the unsupported `if()` branch.
- Recheck trigger: recheck MDN/browser support before recommending `if()` for production code.

## ev-css-tip-tooltip-anchor-20260508

- URL: https://css-tip.com/tooltip-anchor-3/
- Access: article page was recorded as accessible on 2026-05-08.
- Role: article inspiration for `anchor-tooltip-popover`.
- Durable note: the local example combines native popover behavior with progressive CSS anchor positioning. It must remain usable without anchor positioning.
- Recheck trigger: before copying placement syntax into production, recheck MDN anchor positioning support and syntax.

## ev-css-tip-sequential-animations-20260508

- URL: https://css-tip.com/sequential-animations/
- Access: article page was recorded as accessible on 2026-05-08.
- Role: article inspiration for `sequential-custom-property-animation`.
- Durable note: the pattern is the indexed custom-property delay approach, with `prefers-reduced-motion` as a required fallback.
- Recheck trigger: none unless expanding the pattern to scroll-driven or timeline-driven animation.

## ev-mdn-container-queries-20260508

- URL: https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_container_queries
- Access: MDN page was recorded as accessible on 2026-05-08.
- Role: support source for `container-query-card` and `fluid-container-type`.
- Durable note: use for container query syntax, container query units, and support caveats.
- Recheck trigger: any time `baseline_target`, `browserslist_query`, or support caveats for container queries are updated.

## ev-mdn-starting-style-20260508

- URL: https://developer.mozilla.org/en-US/docs/Web/CSS/@starting-style
- Access: MDN page was recorded as accessible on 2026-05-08.
- Role: support source for `starting-style-popover`.
- Durable note: use for `@starting-style` syntax and entry-transition constraints.
- Recheck trigger: if updating discrete transition, `overlay`, or `display` transition behavior.

## ev-mdn-popover-api-20260508

- URL: https://developer.mozilla.org/en-US/docs/Web/API/Popover_API
- Access: MDN page was recorded as accessible on 2026-05-08.
- Role: support source for popover-based examples.
- Durable note: use for native trigger semantics, popover state, and accessibility expectations.
- Recheck trigger: if changing popover examples to use dialog-like behavior, focus management, or custom close behavior.

## ev-mdn-anchor-positioning-20260508

- URL: https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_anchor_positioning
- Access: MDN page was recorded as accessible on 2026-05-08.
- Role: support source for `anchor-tooltip-popover`.
- Durable note: anchor positioning remains uneven enough that examples need fallback placement and support guards.
- Recheck trigger: before broadening support status beyond `limited`.

## ev-mdn-scroll-state-queries-20260508

- URL: https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_conditional_rules/Container_scroll-state_queries
- Access: MDN page was recorded as accessible on 2026-05-08.
- Role: support source for `scroll-state-sticky-header`.
- Durable note: use for `container-type: scroll-state`, `scroll-state(stuck: top)`, and sticky/snapped/scrollable state-query syntax.
- Recheck trigger: before changing `baseline_target: baseline-2026` or using scroll-state as more than visual state.

## ev-mdn-css-if-20260508

- URL: https://developer.mozilla.org/en-US/docs/Web/CSS/if
- Access: MDN page was recorded as accessible on 2026-05-08.
- Role: support source for `css-if-style-query`.
- Durable note: keep `if()` examples experimental until MDN and target browsers show stable support.
- Recheck trigger: any production recommendation or support-status upgrade.

## ev-mdn-cascade-layers-20260508

- URL: https://developer.mozilla.org/en-US/docs/Web/CSS/@layer
- Access: MDN page was recorded as accessible on 2026-05-08.
- Role: support source for cascade-layer use in examples.
- Durable note: used as broad modern CSS support grounding, not as the primary visual effect source.
- Recheck trigger: low priority; cascade layers are mature relative to the other indexed features.

## ev-webdev-baseline-2026-20260508

- URL: https://web.dev/baseline/2026
- Access: web.dev page was recorded as accessible on 2026-05-08.
- Role: broad Baseline 2026 label source.
- Durable note: use only for broad target labeling. Feature-specific support should still point to MDN or equivalent primary docs.
- Recheck trigger: before changing any pattern to or from `baseline-2026`.

## ev-webdev-baseline-browserslist-20260508

- URL: https://web.dev/articles/use-baseline-with-browserslist
- Access: web.dev page was recorded as accessible on 2026-05-08.
- Role: support source for Baseline-flavored Browserslist query syntax.
- Durable note: use for `baseline widely available`, `baseline 2024`, `baseline 2025`, and similar query policy.
- Recheck trigger: if Browserslist Baseline syntax changes.

## ev-codepen-cloudflare-20260508

- URL: https://codepen.io/
- Access: direct access returned Cloudflare 403 on 2026-05-08.
- Role: rejected source event.
- Durable note: CodePen was intentionally not used as verified source code because access was blocked.
- Recheck trigger: if a future source relies on a specific CodePen, record that exact URL as a new event rather than reusing this generic access check.

## ev-x-s3thompson-anchor-sidenote-20260508

- URL: https://x.com/s3ththompson/status/2052477576484987292
- Access: direct X returned 403; fxtwitter metadata exposed enough text to identify the anchor-function sidenote idea.
- Role: inspiration for `anchor-function-sidenote`.
- Durable note: the source is partial. The durable technical basis is MDN `anchor()` plus the local fallback-first sidenote example.
- Recheck trigger: if using this as anything beyond inspiration, refetch source metadata or find an independently accessible demo.

## ev-mdn-anchor-function-20260508

- URL: https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Values/anchor
- Access: MDN page was recorded as accessible on 2026-05-08.
- Role: support source for `anchor-function-sidenote`.
- Durable note: use for `anchor()` syntax and fallback argument behavior.
- Recheck trigger: before changing support status or exact anchor positioning syntax.

## ev-x-mozdevnet-next-sibling-20260508

- URL: https://x.com/MozDevNet/status/2052584361791574177
- Access: direct X returned 403; fxtwitter metadata exposed a MDN post and media alt text showing the previous-sibling `:has(+ ...)` pattern.
- Role: inspiration for `previous-sibling-has-combinator`.
- Durable note: treat this as a discovery pointer. The technical source of truth is the MDN next-sibling combinator page plus MDN `:has()`.
- Recheck trigger: none unless quoting or reproducing the social post itself.

## ev-mdn-next-sibling-combinator-20260508

- URL: https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Selectors/Next-sibling_combinator
- Access: MDN page was recorded as accessible on 2026-05-08.
- Role: example/support source for `previous-sibling-has-combinator`.
- Durable note: use for the previous-sibling selection shape with `:has(+ ...)`.
- Recheck trigger: low priority unless selector support or examples change.

## ev-mdn-has-selector-20260508

- URL: https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Selectors/:has
- Access: MDN page was recorded as accessible on 2026-05-08.
- Role: support source for `previous-sibling-has-combinator`.
- Durable note: use for relational selector support and performance caveats.
- Recheck trigger: if broadening usage to large dynamic DOMs.

## ev-mdn-view-transition-at-rule-20260508

- URL: https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/At-rules/@view-transition
- Access: MDN page was recorded as accessible on 2026-05-08.
- Role: support and example source for `cross-document-view-transition`.
- Durable note: the pattern requires same-origin navigation and remains `limited`; unsupported browsers should get normal navigation.
- Recheck trigger: before changing support status or adding browser-specific caveats.

## ev-x-jh3yy-scroll-counter-20260511

- URL: https://x.com/jh3yy/status/1880430184299442180
- Access: direct X returned 403 on 2026-05-11; fxtwitter metadata exposed the text about scroll-animating a custom property from 0 to 100, feeding `counter(complete)`, and translating a label with `1cqh`.
- Role: inspiration and reconstruction source for `scroll-progress-counter-label`.
- Durable note: treat this as a discovery pointer only. The durable technical basis is the local fallback-first example plus MDN `animation-timeline`, `@property`, `counter()`, and container query unit docs.
- Recheck trigger: if quoting or reproducing the social post itself, refetch the post or find an independently accessible demo.

## ev-mdn-animation-timeline-20260511

- URL: https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/animation-timeline
- Access: MDN page was recorded as accessible on 2026-05-11.
- Role: support source for `scroll-progress-counter-label`.
- Durable note: MDN currently marks `animation-timeline` as Limited availability; use support guards and complete static fallback labels.
- Recheck trigger: before changing the pattern from `limited` to a Baseline target or changing `scroll(root block)` syntax.

## ev-mdn-at-property-20260511

- URL: https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/At-rules/%40property
- Access: MDN page was recorded as accessible on 2026-05-11.
- Role: support source for the typed custom property used by `scroll-progress-counter-label`.
- Durable note: use for `@property --complete { syntax: "<integer>"; ... }` and custom-property interpolation requirements.
- Recheck trigger: if changing the animated custom property type or recommending this outside a progressive enhancement guard.

## ev-mdn-counter-function-20260511

- URL: https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Values/counter
- Access: MDN page was recorded as accessible on 2026-05-11.
- Role: support source for generated percent text in `scroll-progress-counter-label`.
- Durable note: the generated counter is visual; keep real status text in markup when progress is semantically important.
- Recheck trigger: low priority unless counter syntax or generated-content accessibility behavior changes.

## ev-mdn-container-query-units-20260511

- URL: https://developer.mozilla.org/en-US/docs/Web/CSS/Guides/Containment/Container_queries
- Access: MDN page was recorded as accessible on 2026-05-11.
- Role: support source for the `cqh` label translation in `scroll-progress-counter-label`.
- Durable note: `cqh` resolves against the query container height, so examples need a definite container block size.
- Recheck trigger: if changing the container from `container-type: size` to inline-only containment or relying on fallback unit resolution.
