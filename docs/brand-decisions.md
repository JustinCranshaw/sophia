# Sophia brand decisions

A running record of brand choices the user has made. The comparison pages in this folder are history and options; this file says only what the user has decided.

## 2026-10-26 · Working mark locked: DC Trued Channel, solid, plum

**Status:** locked working mark. Design around it. Not applied to the Mac app, the app icon or any release.

The user, on reviewing [soft-six-refinements.html](soft-six-refinements.html): "I like the DC Trued channel, solid, plum. Let's lock this for now. We should design around it."

The user's decision covers exactly these four things:

| | |
|---|---|
| Form | DC · Trued Channel: the `<symbol id="sDC">` in [soft-six-refinements.html](soft-six-refinements.html), merged in PR #38 (`7436f98`). It has viewBox `0 0 32 32` and six paths at `scale(0.16)`. It is not the supplied Soft Six artwork (`sSS`) and not the upright variant (`sDC-u`). |
| Orientation | The page's base orientation, `data-ori="S"`. |
| Paint | Solid: one flat color, with no tonal ramp (`data-paint="S"`). |
| Color | The paired Plum values: `#6E2F55` on light grounds and `#E3A9C8` on dark grounds. |

The geometry and color values must be copied exactly. Do not redraw, retune, apply a tonal ramp to or recolor the mark. Delft, Madder, tonal, the context accents and the other forms on that page are history, not open options.

**Current specimen treatments, not separate decisions.** The source page's Plum row also shows an icon tile (light: `#6E2F55` plate with `#F4E4EC` glyph; dark: `#16171a` plate with `#E3A9C8` glyph) and a reverse (a white glyph on a `#6E2F55` square). The comparison pages reuse them as specimens. The user has not chosen them, and they are not locked.

## Open · Wordmark typeface

The user asked to update the font for the "Sophia" wordmark that sits beside the mark. Candidates are compared in [sophia-wordmark-options.html](sophia-wordmark-options.html), each against the locked mark. The user has not chosen one.

The choice concerns only the wordmark. Body and UI type are outside it. In the app source today, book, page and title text uses SwiftUI's system serif (`design: .serif`), and the reader's base style is `-apple-system` with `ui-serif` for book text (`app/Sources/SophiaReader/Reader/reader.css`).
