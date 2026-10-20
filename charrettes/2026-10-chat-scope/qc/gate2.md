# Operator gate 2: decisions and applied edits

Date: 2026-10-19. Operator: Justin. The C3 and C4 outputs were approved with simplifications; the doc edits were applied by the orchestrator after snapshotting the originals to `snapshots/`.

## Decisions

1. **Clear waits for notes.** ⇧⌘N runs the checkpoint first and writes the `clear` entry only if it succeeds. If the notes fail, nothing changes and the app says it couldn't start fresh. A message typed while the notes are being written is sent after the clear. This resolves adversarial finding T1: the view and Sophia's context can no longer disagree after a clear.
2. **Silent rebuild.** Context is always rebuilt from storage, and nothing is shown to the person about it. No amber marker, no "I couldn't reopen where we left off". Sophia's instructions tell her privately that searches and pages read in an earlier sitting are not still in hand, and to look again without remarking on it. Operator's words: the notes status is "Sophia's internal processing".
3. **Simplified, by cutting:**
   - the "Continuing from" pointer card when switching pages;
   - the in-thread marker ("Sophia has your words from here on · before this, her notes"), the "Her notes, then your words since" subtitle, and ⌘L to open the notes;
   - the special undo window for new pages.
4. **One undo rule.** The latest write, edit or release on a page can be undone until the next change to that page, by either author, whatever is said in any conversation. Undo is one way (clarified after the product and design review; the wording here first listed "undo" among undoable actions, which the one-previous-version constraint rules out). No "your line" tag.
5. **Doc edits approved** and applied to DATA-MODEL.md, PLAN.md, SOPHIA.md and EDITING.md.

Adversarial finding T2 (recovery listed unfiled pages before looking for unrecorded ones) is fixed in the DATA-MODEL.md text: recovered writes are recorded first, against notebook.json and the transcript as they were at launch.

## What was applied, and how it differs from `C4/proposed-edits/`

The proposed-edits files are C4's record and were left as written. The applied text differs from them in these places:

- **DATA-MODEL.md**
  - "Clearing a thread": the entry is written after a successful checkpoint, not before it; the sentence about unnoted pre-clear messages staying word for word is gone.
  - "The marker" paragraph is now "What Sophia has word for word", with no visible marker; it says nothing is marked for the person and older words come back through `recall`.
  - "On opening a notebook": recovered writes are recorded before unfiled pages are listed (T2).
  - Undo: the new-page condition and its "why" are removed; a new page's undo leaves its conversation in the transcript, reachable through `recall`.
  - Checkpoint triggers: "before a clear, which happens only if the checkpoint succeeds"; failure also cancels a waiting clear; "Nothing about it is shown to the person."
  - Verification: the new-page undo bullet is gone; the clear bullets match decision 1; a new-page recovery case is added.
  - The "Why" bullets drop their scenario numbers, which belong to the charrette, not the doc.
- **PLAN.md**
  - Restart row: no "says it was reconstructed".
  - §4 "Saying so" became "Not resuming": nothing shown when context is rebuilt; the instruction to look again lives in SOPHIA.md.
  - §4: "her view always follows her notes" replaces "matches the marker the person sees"; "the person sees nothing of it" added to the checkpoint sentence.
  - §5: "a new draft opens it" became "a new page opens it" in the sentence already being replaced (drafts no longer exist).
- **SOPHIA.md**
  - The "begin with: I couldn't reopen…" sentence is gone. The final paragraph says searches and pages from an earlier sitting are not in hand; look again without remarking on it.
  - The new opening paragraph adds "Older exchanges are in your notes; `recall` finds the exact words."
- **EDITING.md**: applied as proposed.

Not changed, for the operator to strike if wanted: EDITING.md Phase 3 still lists "a hairline margin mark on sections with protected lines; an Authorship toggle". It is a deferred idea in the same family as the cut "your line" tag.

## Effect on `C4/slices.md`

The slices were written for the C4 design before these decisions. If implementation is requested, brief each implementer with this file. Changes:

- **S1**: drop the new-page undo condition from `isUndoable`; add the T2 ordering to `NotebookStore.open`.
- **S2**: no marker, subtitle or ⌘L. The clear runs the checkpoint first and writes `clear` only on success; a failed checkpoint shows "couldn't start fresh"; a send during the clear waits.
- **S4**: drop `rebuiltAfterRelaunch`, the amber state and the spec:66 prefix line. Keep interrupted and Ask again.
- **S6**: drop `pointer(for:)` and the pointer card. Keep "Started from" and the Elsewhere line.
- **S3, S5, S7, S8**: unchanged.

## Evidence

- Observed directly: the four docs were snapshotted before editing; each edit was applied with exact-match replacement; a diff against the snapshots shows changes only in the intended sections (DATA-MODEL 137 changed lines, PLAN 27, SOPHIA 9, EDITING 8); a search of the four docs finds no remaining "amber", "couldn't reopen", "the marker" (other than EDITING.md's unrelated release marker), or "continuing from".
- Not done: nothing in `app/` was changed. No live run.
