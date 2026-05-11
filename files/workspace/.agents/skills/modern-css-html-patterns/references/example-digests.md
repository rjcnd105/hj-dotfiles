# Example Digests

Use this file before opening runnable HTML examples. Each heading must match a catalog ID from `references/index.jsonl`.

The digest is the token-light map from requirement to example. Open `examples/<pattern-id>/index.html` only after exactly one pattern has been chosen for adaptation, verification, or bug fixing.

## layered-shadow-border

- Shows: elevated card edge built from layered shadows and inset highlights without extra DOM.
- Best for: surface depth, hairline borders, cards that need a richer edge treatment than `border`.
- Key CSS: `box-shadow`, inset shadows, optional `color-mix()`, `@supports` fallback.
- Read full HTML when: adapting the exact shadow stack or hover treatment.

## starting-style-popover

- Shows: native popover opening with entry motion and backdrop styling.
- Best for: lightweight panels, menus, and callouts that need native open/close behavior.
- Key CSS/HTML: `popover`, `popovertarget`, `:popover-open`, `@starting-style`, `transition-behavior`, `::backdrop`.
- Read full HTML when: adapting the trigger, close control, or animation timing.

## scroll-state-sticky-header

- Shows: multiple section headers that stick sequentially and change visual state while stuck.
- Best for: grouped lists, queues, documentation sections, and dashboards with scrollable panes.
- Key CSS: `position: sticky`, `container-type: scroll-state`, `@container scroll-state(stuck: top)`.
- Stability note: sticky containers keep a fixed block size; stuck state changes use paint/composite properties instead of layout-changing padding or height.
- Read full HTML when: adapting the sequential sections or debugging sticky boundary behavior.

## container-query-card

- Shows: card layout that switches from stacked to split based on its own container width.
- Best for: reusable components that cannot rely on viewport media queries.
- Key CSS: `container-type: inline-size`, `@container`, container query units.
- Read full HTML when: adapting the component layout breakpoints.

## anchor-tooltip-popover

- Shows: native popover help text progressively positioned against an anchored trigger.
- Best for: help bubbles, tooltips, attached contextual hints, and settings affordances.
- Key CSS/HTML: `popover`, `popovertarget`, `anchor-name`, `position-anchor`, `position-area`, `@position-try`.
- Read full HTML when: adapting anchor placement, fallback placement, or popover controls.

## fluid-container-type

- Shows: headline sizing that follows component width with bounded `clamp()` values.
- Best for: cards, panels, and embedded components where viewport-based fluid type is too broad.
- Key CSS: `container-type: inline-size`, `cqi`, `clamp()`, `text-wrap: balance`.
- Read full HTML when: tuning min/max type scale or container measures.

## css-if-style-query

- Shows: experimental CSS `if()` branch guarded by complete fallback custom properties.
- Best for: tracking emerging conditional CSS syntax while keeping production visuals stable.
- Key CSS: `if()`, `style()`, custom properties, fallback-first declarations.
- Read full HTML when: testing browser-channel behavior or updating experimental syntax.

## sequential-custom-property-animation

- Shows: ordered row reveal using per-item custom-property indices.
- Best for: low-JS staggered content reveals where DOM order should remain semantic.
- Key CSS: `--i`, `animation-delay`, `calc()`, `prefers-reduced-motion`.
- Read full HTML when: adapting timing, item count, or reduced-motion behavior.

## anchor-function-sidenote

- Shows: sidenotes that remain inline by default and promote to margin notes with CSS anchors on wide layouts.
- Best for: articles, documentation, annotations, and editorial side comments.
- Key CSS/HTML: `aside`, `anchor-name`, `position-anchor`, `anchor()`, wide-layout `@supports`.
- Read full HTML when: adapting note placement or inline fallback copy.

## previous-sibling-has-combinator

- Shows: styling an item before the current one using `:has(+ ...)`.
- Best for: step indicators, timelines, and compact lists where previous-state classes would be redundant.
- Key CSS: `:has()`, adjacent sibling combinator, `@supports selector()`.
- Read full HTML when: adapting selector scope or list semantics.

## cross-document-view-transition

- Shows: same-origin multi-page navigation opt-in with `@view-transition`.
- Best for: MPA detail/list transitions where normal links must remain the fallback.
- Key CSS/HTML: `@view-transition { navigation: auto; }`, same-origin links, `::view-transition-old(root)`, `::view-transition-new(root)`.
- Read full HTML when: adapting both pages or changing transition keyframes.
