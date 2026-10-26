# Sophia brand decisions

A running record of brand choices the user has made. The comparison pages in this folder are history and options; this file says only what the user has decided.

## 2026-10-26 · Working mark locked: DC Trued Channel, solid, plum

**Status:** locked working mark. Design around it. Native application is being integrated in SOP-68; no release or deployment is implied.

The user, on reviewing [soft-six-refinements.html](soft-six-refinements.html): "I like the DC Trued channel, solid, plum. Let's lock this for now. We should design around it."

The user's decision covers exactly these four things:

| | |
|---|---|
| Form | DC · Trued Channel: the `<symbol id="sDC">` in [soft-six-refinements.html](soft-six-refinements.html), merged in PR #38 (`7436f98`). It has viewBox `0 0 32 32` and six paths at `scale(0.16)`. It is not the supplied Soft Six artwork (`sSS`) and not the upright variant (`sDC-u`). |
| Orientation | The page's base orientation, `data-ori="S"`. |
| Paint | Solid: one flat color, with no tonal ramp (`data-paint="S"`). |
| Color | The paired Plum values: `#6E2F55` on light grounds and `#E3A9C8` on dark grounds. |

The geometry and color values must be copied exactly. Do not redraw, retune, apply a tonal ramp to or recolor the mark. Delft, Madder, tonal, the context accents and the other forms on that page are history, not open options.

**Current specimen treatments, not separate decisions.** The source page's Plum row also shows an icon tile (light: `#6E2F55` plate with `#F4E4EC` glyph; dark: `#16171a` plate with `#E3A9C8` glyph) and a reverse (a white glyph on a `#6E2F55` square). The wordmark comparison also shows a monochrome sample. The comparison pages reuse them as specimens. The user has not chosen them, and they are not locked.

## 2026-10-26 · Palatino wordmark selected; tighter inline spacing

The user selected **Palatino** and requested tighter inline mark-to-word spacing, then asked to integrate the identity into the actual app. This supersedes the open wordmark comparison; the other faces remain historical options.

The native lockup uses the installed `Palatino-Roman` face, regular, at 13.3pt with 0.133pt tracking beside a 20pt mark. The inline gap is 4.4pt (0.22 of the mark box), reduced from the comparison's 0.30. These native sizing/placement details are the Opus charrette's implementation choices, not additional user-selected typography. The word uses native primary text color; the DC mark retains the exact solid Plum pair. A system-serif fallback is used only if Palatino is unavailable. Palatino is for the wordmark only: body and interface fonts remain unchanged.

## Native implementation treatments · replaceable

SOP-68 places one compact noninteractive lockup in the toolbar, rather than adding a tall Library masthead. Sidebar selection uses the locked Plum at the existing 0.18 opacity. Error, destructive, provisional, source and recovery semantics remain explicit and use existing system treatments.

The application icon is a charrette implementation decision, **not another user lock**: the exact DC mark in `#6E2F55` on a plain white rounded tile. It is generated from the same native path and packaged as a local `.icns`. It does not authorize changing the mark geometry or the solid Plum pair. The earlier icon-tile, reverse and monochrome studies remain specimens. The 40pt empty-Library mark and its plum New Notebook button are also replaceable implementation treatments.

The source `sDC` symbols in `sophia-wordmark-options.html` and `soft-six-refinements.html` are identical. The generated native path retains those six paths and their circular arcs; the generator is a development script, not an SVG parser shipped at runtime. Native toolbar layout is observed on macOS 26; the macOS 14/15 branch is compile-checked only, with layout unobserved.
