# QC: product and design review (fresh session)

Reviewed: `review/product-design.md`, written 2026-10-19 by a fresh session from the prompt in this run.

**Result: accepted.** Every citation checked against the current docs holds (DATA-MODEL.md:128, 138–141, 150–167, 230–254, 273–287; PLAN.md:222; SOPHIA.md:66, 82–85, 102; EDITING.md:46, 50–58, 64, 70, 89–93; C3/interaction-spec.md:9–13, 45–55; C4/decision-brief.md:63–74; gate2.md:13). No finding rests on cut material. No proposal adds a file, record type, setting, mode, or person-managed control.

## Findings confirmed by inspection

- **P1** (blocks): DATA-MODEL.md:240–241 lets an all-rejected checkpoint count as success; with the gate-2 clear ordering that lets a clear proceed with no notes. Also confirmed: kinds listed at :230 (`follow_up`, `background`) are absent from the acceptance list at :248 (pre-existing); :254 "shows the person what it dropped" contradicts :238 "Nothing about it is shown to the person" (introduced at gate 2).
- **P3** (blocks): gate2.md:13 lists "undo" among undoable actions, but undo consumes `.previous.md` (NotebookStore.undoPageWrite moves it into place). DATA-MODEL.md:158 omits releases from the latest-action test while :167 makes releases undoable, so two Undos can be live.
- **D1** (blocks): PLAN.md:222 "a new page opens it", SOPHIA.md:66 "sees it beside the conversation", and C3/interaction-spec.md:53 "The conversation stays put … Open" are three different behaviours; the C3 rule was not carried into the docs at gate 2.
- **P2, P4, D2–D7**: gaps where C3 had a rule the applied docs lack, or wording the reviewer tightened. All verified against the cited lines.

## Operator questions carried forward

1. Undo: one-way, one opportunity (recommended) or reversible.
2. Return: land on Contents (recommended) or restore the last page.
3. New page written by Sophia: conversation stays put with Open (recommended) or selection jumps.

## Applied (2026-10-19, after Justin said "fix what needs fixing")

The three questions were settled with the recommended answers: undo is one way; return lands on Contents; a write by Sophia never changes the selection. Edits applied by the orchestrator:

- **DATA-MODEL.md**: clear promise narrowed ("what mattered"), fresh start offered between turns, a message typed during a failed clear stays unsent (P1, D3); "Started from" bounded to the creating turn, kept for good, with its link and the no-card case (D4); Ask again continues rather than repeats (D5); one latest-action rule including releases, undo one way (P3); all-rejected checkpoint is a failure, an empty one is valid (P1); checkpoint kinds aligned with `RecordChecks.checkpointKinds` in the code, which accepts `follow_up` and `background`; the app shows nothing about rejected records (P1); a new page's creating exchange stays in its context after a checkpoint (P2); seven verification cases added (P1, P3, P4, D4, D5).
- **PLAN.md §5**: "a new page reveals [the book] without changing what is selected"; four new paragraphs: Selection and focus (D1), Return (D2), Fresh start (D3), Reading history (D7).
- **SOPHIA.md**: a written page is opened from the conversation, where the person is doesn't change (D1); look it up with `recall` or `read_page` before asking the person to repeat (P2); the creating exchange is in hand on the new page (P2); check what a cut-off turn saved before writing again (D5).
- **EDITING.md**: open-section refusal has nothing to release; protected-line refusal shows the release marker; release acts on the next message and the card says so (D6); the banner and marker offer the latest action including releases, with labels, an older marker offers none, undo is one way, ⌘Z stays with the focused text (P3, D6).
- **qc/gate2.md:13** reworded to match.

Not done: no change to `app/`. `C4/slices.md` is further superseded by these edits; `qc/gate2.md` and this file are the amendments to read before implementing.
