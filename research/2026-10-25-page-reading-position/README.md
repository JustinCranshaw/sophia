# Page reading position — October 25 native check

SOP-23 changes only the PageView identity boundary. Baseline 2918366 and fixed 1017640 were packaged separately. Every selected/returned different page starts at its beginning, unless following an explicit section link; reselecting the same page keeps the same identity. The key includes notebook URL and filename. No scroll registry or persistent position is added.

## Fixtures and observed navigation

Disposable whitelisted copies of the October 24 model-generated guitar pages and the S1 Fourier notebook were used. The Fourier notebook includes labeled earlier synthetic records plus the real model-written windowing page. Original studies and the personal app were not changed. For Open testing, the historical practice-card tool record’s origin was reassigned to the long-page thread in the disposable copy: this is a labeled navigation fixture, not an observed original model turn. Page bytes stayed unchanged. Position A/B are explicitly synthetic linked notebooks sharing `shared.md`; the links are labeled confirmed fixtures. No auth/config files were copied.

| Native case | Baseline | Fixed |
|---|---:|---:|
| Long guitar page → shorter practice card via sidebar | short book scroll 0.57675; title/staff omitted |0; title, personal reminder and staff/tab visible |
| Long guitar page scrolled 850pt → practice-card Open |0.75421; title omitted |0 |
| Return to prior guitar page | inherited prior reader |0, deliberate return policy |
| Direct linked other notebook, same filename |1 (bottom) |0 |
| Explicit section link to Position A | not used as baseline claim |0.82056; Target section visible at top |
| Another math page selected | not used as baseline claim |0 |

The original issue and this check concern a page already scrolled partway down, not a precise 50% threshold. Waiting for the WebKit body to finish sizing matters: scrolling immediately after initial mount can constrain against its temporary short height. Captures were inspected at original resolution.

## Same-page editing and revision

The actual model-written windowing page was read partway down and edited using native CmdE, type and CmdReturn. A real `edit_page` record was written; the reader stayed in the nearby Why-other-windows/table/DFT material rather than resetting to title. Baseline comparison once showed equivalent source/render reflow: baseline fraction 0.678→0.839; fixed0.699→0.850. Fractions change with document height and are not pixel preservation. No broader editor change was made.

Existing `sophia-reader-checks --scroll-spike` passed: caret stayed visible; surrounding growth/shrink/below-editor revisions moved editor and caret 0pt and kept editor text. These are the existing reader checks, separate from the native app observations.

One explicit native composer request asked Sophia to preserve all current lines and append one final line to the same page. The real MCP `write_page` record t-0225 is `revised:true`, without refusal; current lines exactly preserve all previous lines and contain the requested append. The visible book content and position before/after are identical; normalized fraction 0.62147→0.60841 reflects extra document height. The remaining model response was still active when normal CmdQ was used for the next GUI handoff, so it was canceled during shutdown. This verifies delivered revision/reading position, not a completed assistant reply or latency benchmark. Provider route/default were unchanged; no billing conclusion follows.

## Verification and limits

Debug app/MCP packaging, release Sophia build and 57 core checks passed on 1017640. No new test framework. The app was quit and GUI released after checking. These are scripted internal native interactions, not a human study. Returning pages intentionally restart rather than restore a stored historical offset. Same-page editor reflow remains existing behavior; no exact-pixel claim is made.
