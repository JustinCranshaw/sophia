# SOP51: keep unsaved page-edit recovery separate from operational errors

## Reproduced loss

In a disposable native missing-CLI run, edit a page, type the decomposed-Unicode marker, then Undo its creation. The page range no longer exists, so the app leaves the only unsaved text in `problem`. Explicit Retry clears that field and replaces it with the installation error. The recovered text disappears. `/tmp/sophia-sop7-recovery-loss-proof.json` records exact text and before/after observations; originals `89a778.png` and `5bddb1.png` below. The frozen SOP50 `a49481d` bundle was used for this audit; this operational-error path was unchanged from landed `ba58c10`. No provider request.

## Scoped behavior

A small transient Core value collection holds exact recovery strings with UUIDs and captured page/section labels. Session appends a recovery when a range has disappeared instead of putting it in the operational-error field. Multiple failed edits never replace one another. Send/Retry/error clearing does not touch the collection. No draft database, file, record schema, queue or provider changes.

A compact banner identifies temporarily kept unsaved edits. It does not open a modal automatically. Review opens a bounded, read-only/selectable sheet; Copy text copies the entire exact string, and Dismiss this edit removes only that item's UUID. Close hides the sheet without clearing its contents. The sheet plainly says to copy before closing/switching notebooks: retention is only the currently open NotebookSession, not durable storage or relaunch recovery. Normal page saving and other editor conflict behavior are unchanged. Closing an already open editor on shutdown remains the lifecycle implementation's responsibility, not a new draft-save mechanism here.

## Verification

Final integrated base `5feabba311c93eb72fa307305f92883405bc0108` includes SOP50 and SOP28. The mechanical check registration union retains its one-way pending-status Quit gate **last**. All **98 core checks** pass (97 base plus one recovery-value check); current debug app/MCP builds. Commands from repository root:

```
swift run --package-path app sophia-checks
app/scripts/make-app.sh debug
```

Logs `/tmp/sophia-sop51-final-integrated-checks.log` and `/tmp/sophia-sop51-final-integrated-build.log`. Earlier integrated SOP50 checks passed96; final registration union preserves both new navigation checks and the recovery check. The focused check retains two canonically equivalent but byte-distinct Unicode edits to the same source, leading/trailing newlines, source labels and ordering; dismissing one or reusing its stale UUID cannot remove the other. No global fixture-directory cleanup is performed.

### Native controlled proof

Disposable `/tmp/sophia-sop51-ui`, with launch-only `--without-claude` and a huge explicit return threshold. Setup uses production MCP page writes; all later user changes/actions are native. No inference, real provider, account change or auth mutation.

1. Save a question under missing-CLI failure. Edit the first developer page, type an exact decomposed-Unicode string, Undo creation, and explicitly Review. Copy returns all **71 UTF8 bytes exactly**. Original clipboard items and every type are eagerly saved only in memory and restored afterward; no previous clipboard contents are logged or stored.
2. Close the sheet, Retry the saved question, then Send a new question. Both fail through the real missing-install path. Review still shows the first recovery unchanged.
3. Fail a second edit on another page, using precomposed Unicode plus 25 lines. Both source-labeled recoveries remain. At requested 900×600 content size (capture900×652), the compact banner, operational error, composer and book remain reachable. Sheet scrolling exposes the full second text and its buttons; Copy returns all **1122 UTF8 bytes exactly**.
4. Dismiss the first recovery only: the second stays and the operational error remains. Close keeps it. Dismiss the operational error: the recovery remains. Review and dismiss the last recovery: the banner disappears. `/tmp/sophia-sop51-native-proof.json`, separate copy proof logs, and native result JSON retain observations. App66280 quit through native Cmd-Q and was verified gone.

These first component checks were run before SOP50 integration; the unchanged recovery component was then exercised on the integrated bundle with a real approval-only MCP callback and controlled fake CLI (still **no provider/fetch**). At the same requested minimum size, Allow once, Don't open, Review kept edits, Stop and composer are all visible alongside the book. Explicit Don't open and Stop retain the recovery. Captured fake75726/75727/MCP75728 and app75631 are gone, bridge removed. `/tmp/sophia-sop51-source-layout-proof.json`. The final banner wording was shortened to explicitly say “kept temporarily”; the final build verifies that text-only clarification without repeating the full native run.

### Original-resolution screenshot paths

- Loss before: `/private/tmp/sophia-sop7-recovery-ui/results/1792932713359281000-89a778.png`.
- Loss after Retry: `/private/tmp/sophia-sop7-recovery-ui/results/1792932722645207000-5bddb1.png`.
- First read-only sheet: `/private/tmp/sophia-sop51-ui/results/1792933859793726000-fd5a1e.png`.
- Minimum banner/error/composer: `/private/tmp/sophia-sop51-ui/results/1792934023523864000-3dd2b0.png`.
- Two source-labeled edits and overflow: `/private/tmp/sophia-sop51-ui/results/1792934024319708000-de3697.png`.
- One recovery left: `/private/tmp/sophia-sop51-ui/results/1792934089107941000-3a3298.png`.
- All explicitly dismissed: `/private/tmp/sophia-sop51-ui/results/1792934092307460000-8ca200.png`.
- Source decisions and recovery together: `/private/tmp/sophia-sop51-source-layout-ui/results/1792934552560716000-2b66ed.png`.

Images were inspected at original resolution. Exact copy/state evidence is separate from visual inspection. No durable recovery, human comprehension, real-provider reliability or billing/commercial claim. Parent SOP7 remains open for the separate malformed-checkpoint feedback audit.

## Independent label fix

The Opus5.5 review found that the internal zero-based range key (`§1`) was being presented for the second section, whose editor strip says `§2`. Recovery now uses the actual human label plus heading (`§2 · Second section`), retaining the special whole-page/opening labels. The focused check constructs a real page/edit range and verifies internal key versus one-based label and heading before retaining it. All98 checks and app/MCP build pass on the fixed sources (`/tmp/sophia-sop51-label-checks.log`, `/tmp/sophia-sop51-label-build.log`).

A section-specific native edit was not reached: the HTML Edit affordance was absent from the harness accessibility tree, and bounded hover/click/Tab attempts did not open an editor. No more driver attempts or expansion. `/tmp/sophia-sop51-section-native-limit.json` confirms no open edit marker and page bytes still match the setup write. This does not claim native execution of the corrected section-label branch; the earlier native whole-page/repeated-recovery/copy proof remains separate. The source mapping, actual Core range check and compiled view verify the narrow label fix. The preexisting possibility of a newly failed edit being discovered only during notebook/session closure remains outside this transient recovery slice; no durable or unseen-close recovery claim is made.
