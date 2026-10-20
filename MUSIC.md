# Music notation plan

Status: Phase 1 built and checked by machine, October 15, 2026; reading tunes in real use, VoiceOver, and the live check are open. Justin is starting music-related notebooks, so pages need staff notation, simple guitar tab, and later chord charts.

Pages keep music as text in fenced blocks, and the reader renders it locally, the same way LaTeX works: the source is the document, rendering is view-only, and the byte-exact editor works unchanged. Library choices come from outside research (October 2026, documented and anecdotal; licenses rechecked there against npm and GitHub). Recheck versions and licenses when vendoring.

## Formats and libraries

| Need | Fence | Renderer | License | Phase |
|---|---|---|---|---|
| Staff notation, simple melodic tab | ```` ```abc ```` | abcjs | MIT | 1 |
| Lyrics with chords, chord boxes | ```` ```chordpro ````, ```` ```chords ```` | a small renderer of our own, plus svguitar for boxes from ChordPro `{define: C7 base-fret 1 frets x 3 2 3 1 0}` | MIT (svguitar) | 2 |
| Guitar tab with bends, slides, hammer-ons | ```` ```alphatex ```` | alphaTab | MPL-2.0 | 3, only when a real page needs it |

Rejected: ChordSheetJS (GPL-2.0-only), VexTab (inactive), an invented chord-box syntax (ChordPro's `{define:}` already exists).

abcjs tab is a fret-number line under the staff, enabled by a render option, with tunings and capo. It has no bends, slides, hammer-ons, string choice, or tab-only view. That is enough for melodies; it is not real guitar tab.

## Phase 1: ```` ```abc ````, render-only

1. **Vendor** abcjs (the basic, no-audio build if it exists) through `reader/vendor.py`: exact version and integrity in `assets.lock.json`, upstream license, one checked-in script loaded only when a page contains an `abc` fence (as CodeMirror is), CSP unchanged. Record its size.
2. **Render after sanitizing.** markdown-it emits a placeholder element carrying the ABC text for each `abc` fence; after DOMPurify, the reader renders each placeholder with abcjs from that text and sanitizes the SVG once with DOMPurify's SVG profile (no `<style>`, no `foreignObject`). Confirm ABC titles and lyrics reach the SVG as text, never markup.
3. **Options.** An optional first line of JSON followed by `---` (the Obsidian plugin's form), allowlisted to `tablature` (instrument, tuning, capo), `scale`, and `staffwidth`; anything else is ignored. Responsive width to the text column. Colors follow `currentColor`, so dark mode works.
4. **Errors.** Never block the page: show the rendered SVG with a small collapsible list of abcjs warnings; on hard failure show the source in a bordered `pre`. Copy and accessibility keep the ABC source (`aria-label` from the tune title; source available to VoiceOver and to the copy handler, as for TeX).
5. **Editor.** With the caret inside an `abc` fence, pin a rendered preview under the block (debounced, ~300 ms, cached by source), with its warnings, matching the math preview.
6. **Warnings to Sophia.** The reader reports a page's ABC warnings to the app; the app adds one line to Sophia's next turn naming the page, section, and warnings, so she can fix the notation.
7. **SOPHIA.md.** Write music in `abc` fences; tab only via the `tablature` option and only for simple melodic lines; say when a tune is transcribed from memory rather than a source, and link the source when there is one; don't claim how it sounds beyond the notation; fix reported warnings.
8. **Docs.** app/README.md (versions, usage), DATA-MODEL.md (pages may contain `abc` fences).

*Result, October 15, 2026:* abcjs 6.7.1 (MIT, checked in the npm tarball). npm has no build without audio: `abcjs-basic-min.js` (512 KB) includes the synth, with `AudioContext` and remote soundfont URLs, and `abcjs-plugin-min.js` lacks the synth but scans the whole document for ABC. So `vendor.py` bundles just the renderer (`renderAbc`, `numberOfTunes`) from the package's own sources with the locked esbuild, into `vendor/abcjs.min.js`: 454 KB, reproducible, with no audio or network code. It and `music.js` load only for a page with an `abc` fence. abcjs writes titles and lyrics with `textContent`, always adds a `<style>` to its SVG (sanitizing drops it), and reports warnings as HTML, which the reader reads as text ("Line 4 of the tune, column 3: …"). abcjs ignores `scale` in responsive mode, so `scale` caps the width the music is drawn at, times its natural width. Sophia hears each distinct set of warnings on a page once per session, when the page has been rendered in the book; tunes in her replies render but aren't reported.

No playback in Phase 1, so no soundfont and no network question. If playback is added later, bundle one instrument (FluidR3_GM is MIT) and set abcjs's `soundFontUrl` locally.

## Checks

- Parser (`reader/check.mjs`): an `abc` fence becomes a placeholder holding its exact text; other fences are unchanged.
- Reader (`sophia-reader-checks`): a fixture tune renders an SVG with no network request; a tune with `tablature` renders a tab line; a malformed tune shows warnings and the rest of the page still renders; a tune title containing `<script>` and markup appears only as text; copying a rendered tune yields its ABC source; the editor's no-keystroke round trip on a page with an `abc` fence is byte-exact.
- Live: Sophia writes a short melody page in a disposable notebook; read it by eye, and check that a deliberately broken tune's warnings reach her next turn.

## Later phases

Phase 2 (ChordPro and chord boxes) when a notebook needs songs with chords. Phase 3 (alphaTab) only when a page needs technique-rich tab; it needs workers and font paths that may require a custom URL scheme in the reader.
