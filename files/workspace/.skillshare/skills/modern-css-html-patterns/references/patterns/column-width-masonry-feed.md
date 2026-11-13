# Column-width Masonry Feed

Catalog ID: `column-width-masonry-feed`

Use this when a feed, gallery, or board needs masonry-like vertical packing and
the content can follow normal DOM order down each visual column. The pattern is a
CSS multi-column layout: the container declares an ideal `column-width`, then
each card opts out of fragmentation with `break-inside: avoid`.

Avoid it when row-wise visual order is essential, such as ranked results,
timelines, keyboard-heavy task lists, or anything where users expect the next
item to sit horizontally to the right. This is not native CSS Grid masonry; do
not use it to claim support for experimental grid-lane masonry features.

Support: Baseline widely available for `column-width` and `break-inside`.

Source refs: `ev-theosoti-column-width-masonry-20260514`,
`ev-mdn-column-width-20260514`, `ev-mdn-break-inside-20260514`.

Example: `examples/column-width-masonry-feed/index.html`.

Notes:

- Start from a normal one-column list so unsupported or constrained contexts
  remain readable.
- Enhance the list with `column-width` and `column-gap`; the browser chooses the
  number of columns from the available inline size.
- Set every repeated item to `display: inline-block`, `width: 100%`, and
  `break-inside: avoid` so individual cards do not split between columns.
- Test long cards, dense card sets, very narrow widths, and keyboard/screen
  reader order before using this for production content.
