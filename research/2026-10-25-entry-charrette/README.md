# Entry and first-inquiry native comparison — October 25, 2026

Internal implementation walkthrough, not a human usability study. Standard Mara Chen (Design), Marcus Webb (Product), and Imani Blackwood (CEO) were enacted sequentially because all native agent slots were occupied. Each opening was written separately before cross-digests. The same integrator enacted all voices; these are not independent agents or independent human judgments.

Decision: carry a question or supplied material into an unsent conversation, with optional notebook name. Keep the existing book toggle; empty notebooks begin hidden, manually opened books stack below conversation when two readable columns cannot fit. Preserve drafts per notebook/thread within the current window.

## Comparison and revision

Naming-first control at 900: the person supplies a container title, then must enter the question. Question-first prototype carries the exact fungi question, but initially inherited a visible empty book that squeezed the composer to about 100 points; creating another notebook also replaced the old unsent draft. Mara blocked readability; Marcus blocked draft loss; Imani allowed only the smallest local state/layout correction. The revised artifact uses existing adaptive layouts and a window-local draft dictionary. At 900, manual Book places it below the conversation; at 1440 it remains beside. Explicit book choices survive notebook switches.

Default title initially truncated the fungi question mid-word. Root and Mara requested a sentence/word boundary refinement. Current derivation uses the first sentence/question, caps at 64 characters at a whitespace boundary, sanitizes path separators/dot names, and checks filesystem collisions. It does not generate an AI title or promise rename.

## Earlier observations

- Same fungi question in control and prototype; Continue retains exact input and sends nothing.
- Unsent fungi draft survives creating music notebook; music multiline attempt returns separately.
- Cancel/reopen preserves entry input.
- Actual explicit one-off request received two sentences; no page or goal created. Switching away/back leaves sent composer empty.
- Debug package and all 54 current core checks pass. Release build passed on the UI source before the independent attribution/Retry merges; the final integrated release on c870044 also passed.

## Boundaries

No intake modes, mandatory goal, curriculum, required page, title model call, rename feature, draft service, session ledger, or provider/authentication change. Drafts are window-local; remembered book choices last for the running app. Neither promises relaunch persistence. Saved transcript carries sent questions through relaunch. No claim of human preference, learning, retention, or demand.

## Final observed checks on c870044

Current main attribution/Retry integrated cleanly; debug package and all 56 core checks pass. Native material fixture (synthetic, not model-written) renders staff/tab and Fourier math at 900 and 1440, including a separately scrollable narrow book. A 2,809-character multiline passage is retained byte-for-byte in the unsent composer, whose visible height stays bounded. The generated fungi title now ends at its first question. Explicit native send of a material-led request yields a substantive distinction, no page/goal; response is longer than requested. A vague interest receives suggested ways in and a clarifier, no page. It presumptively refers to a “first page” despite no page request; this is unresolved companion wording, not evidence that all arrival behavior is solved. Finish, quit and immediate reopen retain the early no-page inquiry and reply with empty composer. This is continuity, not genuine delayed return.

All native interaction used the debug harness driving actual controls. Fixture setup was outside the app while closed; input/model exchanges are actual, scripted/internal walkthroughs, not people learning. The one-off answer occurred on the preceding integrated attribution source; populated material and vague/return checks on c870044. No provider access or default-model route changed, and no billing conclusion is possible from these observations.

## Convergent exit

Mara: the earlier readability blocker is resolved; current narrow/wide math/music and bounded-passage artifacts support this small composition. The shorter title answers the mechanical clipping objection. Human preference remains untested.

Marcus: unsent separation, sent clearing, one-off/no-page, material and vague starts, and early reopen have concrete observations. Window-local unsent retention is the stated contract. Overlong and presumptive page wording remain companion follow-up, not hidden successes.

Imani: retain the two SwiftUI file change and explicit user control. Cut title AI, rename, onboarding modes, persistent drafts, a new canvas and scroll state machinery. The demonstrated failures justify these local changes; no broad product outcome is claimed.

The integrator separately enacted all three voices and inspected every final PNG at original detail. No independent human or delegated design evaluation is claimed. Earlier blockers were tested and revised; broader efficacy belongs to first-time people and a genuine later return.


## Review-driven verification

The initial Opus adaptive review on c870044 requested four bounded fixes: minimum-height book allocation, a draft stranded when a newly created page is undone, hidden empty default being remembered as explicit choice, and filename byte length. All are addressed locally in SophiaApp.swift. The narrow book now leaves at least 300 points for conversation; the Undo transition moves the page draft visibly into Contents, appending to existing unsent text rather than overwriting it. Explicit toolbar Hide/Show and page/Open actions are remembered; an untouched empty-hidden default does not persist after the first page exists. Titles stay within 240 UTF-8 bytes before the collision suffix.

Native checks on the revised working tree: 900×600 with tall composer before/after; 1280×800 Hide Book and Hide Sidebar retain usable layout and choices; switching away/back preserves explicit Hide, then explicit sidebar page opening replaces it. A labeled fixture extracted from a previously recorded S1 write demonstrates native Undo retains both an existing Contents draft and the removed page's draft, unsent and visible. An actual new Sophia page remains hidden during the write; switching away/back now shows the populated book. A 64-family-emoji title creates a 225-byte folder successfully. These checks introduced no new provider route. The native entry TextEditor applies AppKit smart quotes while inserting ASCII quotes; the observed field value was already transformed before Continue, and carriage into the composer preserved that value. The exact 2,809-character claim applies only to the tested passage, not a guarantee about native text substitution.
