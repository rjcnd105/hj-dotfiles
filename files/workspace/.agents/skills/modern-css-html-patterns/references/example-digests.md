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

## scroll-progress-counter-label

- Shows: a scroll timeline animates a typed custom property that feeds a CSS counter and moves a label.
- Best for: decorative article progress rails, onboarding completion markers, and no-JS visual progress cues.
- Key CSS: `@property`, `animation-timeline: scroll(root block)`, `counter()`, `counter-reset`, `cqh`.
- Read full HTML when: adapting fallback text, scroll range, or the container-height label translation.

## safe-area-mobile-shell

- Shows: a mobile app shell that keeps sticky chrome and floating actions inside safe areas.
- Best for: edge-to-edge mobile screens, notch/home-indicator layouts, fixed CTAs, and bottom navigation.
- Key CSS/HTML: `viewport-fit=cover`, `env(safe-area-inset-*)`, `max()`, `calc()`, fixed/sticky controls.
- Read full HTML when: adapting simulated device insets, action placement, or safe-area spacing tokens.

## animated-gradient-text-shine

- Shows: readable text progressively enhanced into an animated clipped-gradient shine.
- Best for: short celebratory labels, approval states, and headings where the effect is decorative.
- Key CSS: `linear-gradient()`, `background-clip: text`, `background-position`, `@keyframes`, `prefers-reduced-motion`.
- Read full HTML when: tuning gradient stops, animation speed, fallback color, or reduced-motion behavior.

## relative-color-token-palette

- Shows: one base color deriving strong text, soft surface, border, shadow, and accent tokens.
- Best for: component palettes, themeable callouts, badges, and states where color relationships should stay coherent.
- Key CSS: `oklch(from ...)`, `rgb(from ... / alpha)`, `currentColor`, `calc()`, `@supports`, custom properties.
- Read full HTML when: tuning channel offsets, fallback tokens, color-space choice, or contrast checks.

## animated-conic-gradient-border

- Shows: a featured card with a rotating conic-gradient border and blurred glow layer.
- Best for: one-off hero cards, launch panels, and decorative featured surfaces.
- Key CSS: `@property`, `conic-gradient()`, `::before`, `::after`, `filter: blur()`, `@keyframes`, `prefers-reduced-motion`.
- Read full HTML when: tuning border thickness, glow opacity, gradient stops, or reduced-motion behavior.

## grid-height-transition

- Shows: a disclosure panel animating natural content height through `grid-template-rows`.
- Best for: accordions, dropdowns, and compact disclosures with dynamic content height.
- Key CSS/HTML: `button`, `aria-expanded`, `aria-controls`, `display: grid`, `grid-template-rows: 0fr/1fr`, `overflow: hidden`.
- Read full HTML when: adapting the state-sync script, clipping wrapper, transition timing, or reduced-motion fallback.

## column-width-masonry-feed

- Shows: a masonry-like feed using CSS multi-column layout and unsplit cards.
- Best for: galleries, editorial boards, and mixed-height card feeds where column-major visual flow is acceptable.
- Key CSS/HTML: `ol`, `column-width`, `column-gap`, `break-inside: avoid`, `display: inline-block`.
- Read full HTML when: tuning card width, generated column count, varied card heights, or ordering/a11y notes.
