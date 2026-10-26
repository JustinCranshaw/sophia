# SOP59 — notebook orientation and reading

Controlled native observations on October 25, 2026; no product-provider requests were made. Source began at `4acf077` and final UI was `6d8b325`, including the docs-only `f021981` main integration. Fixtures, commands, original-resolution screenshots and design transcripts are retained under `/tmp/sophia-sop59-control`. The original checkout and previously user-used SOP57 demo were untouched.

## Resulting behavior

Notebook selection opens Home on the first click. Startup also opens the first notebook’s Home; new-notebook creation separately retains its exact starting material unsent. Home uses existing contents and person-confirmed working goals, optional clearly historical saved inquiry, and an explicitly generic companion approach. It does not generate a purpose, reuse private working memory, or add persistence. Weak greetings are not presented as an introduction.

Goals and notes are management sheets; About you is explicitly shared across the Library. Existing correction, confirmation, evidence and link controls remain available. Management does not change the selected page’s conversation or draft. The conversation header identifies the page even in compact reading mode. No thread routing, migration or transcript ownership was changed.

Almanac dates come only from recorded preparation metadata, with unknown dates shown honestly. Preparation/settings belong to its Home, while a waiting entry has a global actionable indicator. Routine authored-write banners are replaced by contextual page-header Undo. Unknown-author, refusal, error, kept-edit and permission information remains explicit; focused-text ⌘Z is unchanged.

## Rendered design loop

Official Claude Code `2.1.310`, explicitly selected `claude-opus-5-5`, facilitated the standard convergent Mara Chen / Marcus Webb / Imani Blackwood charrette. Lead and each substantive child voice exposed actual `claude-opus-5-5` model metadata, independently checked by the implementer. This was separate from the later code review. Child resume was unsupported: subsequent rounds used exactly three replacement executions of the same personas, with carried decisions and the other voices’ digests, rather than claiming persistent child execution.

The initial native prototype was inspected by all three. Their concrete blockers led to first-click empty Home, a shared About you sheet without a notebook composer, and conditional Almanac Retry matching failure guidance. Revised native renders were inspected again. The remaining empty-first startup gap led to the one-line explicit Home startup; new-notebook unsent-material behavior was then verified independently. Current-brand typography/palette remained unchanged; parallel branding options were not applied. Final startup/new-inquiry renders received a third bounded critique: all three voices closed their blockers with no dissent. Actual child message models in that closure were independently verified as `claude-opus-5-5`, as was the successful lead’s canonical model/first-party metadata. Optional taste suggestions were not expanded into more scope.

Representative actual captures: [Home 900](sop59-images/home-900.png), [Home 1280](sop59-images/home-1280.png), [page conversation](sop59-images/page-chat.png), [shared About you](sop59-images/shared-about.png), [Notes](sop59-images/notes-settings.png), [Goals](sop59-images/goals-settings.png), [dated Almanac](sop59-images/almanac.png), [Almanac failure](sop59-images/almanac-error.png), [unknown author](sop59-images/unknown-author.png), [empty startup](sop59-images/empty-startup.png), [new inquiry unsent](sop59-images/new-inquiry.png). The Almanac overflow image is from initial prototype `c91f1a9`; its dated-page layout is unchanged. Other final-layout images are `dcb2ece`; startup/new inquiry are `6d8b325`.

## Observed native interactions

All notebooks were fresh, synthetic disposable fixtures. Controlled replies came from a labeled Python fake CLI, not Claude or a network service. Missing-CLI injection used the existing debug-only path.

- Baseline P/Q selection already routed messages and drafts correctly; this change addresses visible context, not a reproduced routing defect. A delayed controlled P reply completed while Q and its exact draft remained selected; its transcript reply belonged only to P.
- Notes → Correct → Save correction worked through existing native controls. Goal Review preserved selected P and its draft; an externally revised proposal made old Confirm refuse, then latest Confirm succeeded. Final conversation deep-actions opened the same Notes/Goals sheets while retaining the exact P draft.
- A visibly typed unsaved page edit survived opening/closing shared About you while disk bytes stayed unchanged. Explicit commit wrote it once; contextual Undo restored the exact original bytes. No keyboard Undo interception was introduced.
- Empty first-click Home and empty-first startup displayed orientation. Controlled Send expanded history. New creation carried `SYNTHETIC UI CHECK: Why can a held note cross the beat?` byte-for-byte into an unsent composer, with no provider call.
- Recorded Almanac fixture dates were October 21/23/25 while page modification times were deliberately 2020. Private memory was visible only in explicit Notes, not repurposed on Home.
- Unknown-provenance page changes retained their explicit warning and lacked destructive inferred Undo.

Driver failures were retained as diagnostics: native segmented AX press and guessed coordinates did not establish Notes navigation. The bounded debug driver now clicks only a unique current role/label/class/frame in the owned active window, rejecting stale/ambiguous/off-window targets. Nested sheets retain their actual window ownership. An initial new-inquiry attempt accidentally selected an unlabeled underlying composer field editor; the labeled starting-material control stayed blank. The corrected labeled-control run passed. Neither failure was claimed as product success or a product defect.

## Checks and limits

`swift run sophia-checks` passed all **108** existing checks (`final-core-checks.log`). The standalone presentation checks documented in README passed: explicit confirmed working goals; weak/page-only inquiry exclusions; exact historical words; ordinary pages undated; actual recorded Almanac dates despite unrelated mtime; undone entries excluded; unavailable dates not fabricated. Debug packaged builds passed through `startup-package.log`. Targeted release `Sophia` and `sophia-mcp` packaging passed (`final-release-package.log`), followed by strict/deep ad-hoc signature verification. This is not a release-all checker or notarization claim. The retained bundle is `/tmp/sophia-sop59-control/demo/Sophia.app`, with a separate synthetic `demo/Library` and prompt-returning `demo/Launch Sophia.command` using macOS `open -n -a ... --env SOPHIA_LIBRARY=...`; the release demo itself was not launched as another provider test.

This is controlled native integration and design evidence, not human comprehension, delayed-return, real-provider content quality, actual notification delivery, clean-Mac, signed distribution or commercial-route evidence. Drafts remain window-local, and ordinary existing source/learning/Undo behavior retains its documented limits. No personal settings, OS notification permission or authentication state was changed. The new retained demo uses a separate disposable Library; the older user-used demo is preserved.

## Independent review corrections

The official Opus5.5 adaptive three-pass code review of `443612a` identified four concrete FIX NOW items ([initial consolidated comment](https://github.com/JustinCranshaw/sophia/pull/32#issuecomment-6406588248)). The lead verified each centrally; actual lead canonical metadata and all three child message models were independently checked as `claude-opus-5-5`. Fix commit `ec547fb`:

- A successful notebook switch clears the old settings selection, preventing an empty undismissable sheet when following a Connections link. Failed notebook construction still retains the existing session. Actual controlled link-follow dismissed the sheet and showed the destination page.
- The app-menu Almanac action explicitly requests Home. This one-line call was source/build verified. The existing debug menu command enumerates items; its screenshot is not claimed as an executed menu action.
- Publication dates project the loaded transcript once, with an undone-ID set and latest valid write per run, rather than re-parsing the whole disk transcript for each date. Listed/readable pages, refused/recovered exclusions, missing-date fallback and latest-run identity are preserved. Additional focused exclusions passed.
- A window-local seen-message ID gives compact Home a truthful “New reply · Show conversation” or “Welcome back · Show conversation” affordance for new relevant messages. It does not force open history, move records, change page routing or persist unread state. Showing the history marks it seen. Native controlled ordinary reply and automatic return both preserved the hide choice, then cleared their indicator on opening. A P reply while Q was selected retained Q’s exact draft without a wrong-thread indicator.

These targeted native checks ran on the exact working-tree source committed as `ec547fb`; no actual provider was contacted. [New reply](sop59-images/new-reply.png), [automatic return](sop59-images/return-briefing.png), [settings link destination](sop59-images/settings-link-destination.png). All original failed-driver records remain separate diagnostics. Final code review must cover this correction and documentation delta at its exact head.
