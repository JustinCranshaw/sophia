# SOP49 — adjacent note/memory presentation

This is the bounded presentation slice of SOP25: collapse only adjacent successful note/memory transcript events, preserve every raw record and action, and leave assistant prose unchanged. It proves no model concision, latency, filler reduction, human tolerance or completion of SOP25.

## Source and checks

- Base: `ce440e1bc1f15a12b581b04295cb00ed7ad299c6` (landed evidence and folder-copy work).
- First native source: `a62c946` (grouping, success/failure metadata, original actions, missing-note fallback, raw member activity IDs).
- Final boundary source: `8eaddd3` (mapper sees the full transcript and filters the active thread internally so skipped global/other-thread entries break adjacency without stealing reply origin/block).
- `python3 research/2026-10-25-conversation-follow/check-rows.py`: all **29** focused checks pass, retaining the original nine streaming/identity cases and covering grouping, append identity, raw anchors/order, strict success metadata, errors/refusals, important events, session/thread/person/checkpoint boundaries and hidden-thread stream→commit identity.
- Debug Sophia/MCP bundle passes; all **79** existing core checks pass, and the targeted release Sophia product builds (37.15s). No new test framework or dependencies. Final core/presentation/release logs are retained under `/tmp/sophia-groups-*`.

## Labeled native fixtures — no provider request

Two initial disposable notebooks were seeded using production stores by a temporary Swift helper outside the project. Every person/reply/note is visibly labeled SYNTHETIC; there is no actual model response in this exercise. Native launch used the existing debug missing-CLI fault and a huge return threshold to avoid inference. No auth/provider/prompt configuration was changed.

The helper used real note/memory/page/goal writes, with raw transcript fixtures only for explicitly labeled source/error outcomes. The page refusal came from an actual open-edit refusal through NotebookStore, then the fixture edit marker was closed. Append timing is deterministic, **not natural tool delivery**. To surface external fixture changes the app used ordinary native Keep this notebook separate or Notes correction Save actions; no private app-state test hook was added.

## Observed native results

- **Wide collapsed arrival:** three note/memory events show one collapsed row. Append one note and one memory revision: count3→5, group identity retained, New activity appears while reading away. The recorded scroll fraction stayed0.828178694; original screenshots retain the visible paragraph context. Explicit jump returns to1 and clears the badge.
- **Expanded arrival:** expansion retains its header and first revealed notes. While reading those details, another append changed count5→6, kept expansion state1, retained existing content positions and showed New activity. Notes and memory See actions remain present. A fraction change when expanding is content growth, not evidence of a jump; no follow-geometry repair was made.
- **Narrow arrival:** after clearing the prior badge and deliberately scrolling away, another note changed the collapsed count7→8. The paragraph context remains and the badge changes absent→present. The earlier narrow capture already had a badge from the wide case, so the committed fresh narrow pair is the isolated check.
- **Correction/deletion/Undo:** expanded Notes opened the existing Notes view. A native correction saved `SYNTHETIC PERSON CORRECTION: keep this update inspectable.` against the intended note. Deleting it kept the group expanded and the historical update count unchanged, with a truthful unavailable fallback; Undo restored both the original note and its correction. A second latest-note deletion was scrolled into view for `missing-note-and-undo.png`, then undone. The Notes deletion Undo remained outside the group.
- **Important outcomes:** three two-note groups remain separated by page Open/Undo, provisional-goal Review, source-error outcome and a visible note-error row. The actual open-edit refusal was inspected in its page thread. None was folded into bookkeeping.
- **Strict raw-boundary correction:** the first caller supplied already-filtered page entries, incorrectly grouping three P notes whose raw order included a global checkpoint and Q activity. The old native control shows one three-note disclosure. The final full-transcript mapper shows three standalone P note rows instead. Later Q activity followed by two adjacent P notes creates only a new two-update group. The existing P paragraphs retain identical visible positions and New activity appears; hidden Q messages do not replace the P reader.
- All native apps exited by Cmd-Q and were verified gone; no model process/request was used or left active. GUI ownership was explicitly released.

The broad Contents/action checks ran on a62c946. For these fixtures the final filtering change is behavior-equivalent; the targeted page-thread before/after and arrival checks ran on8eaddd3. Captures were inspected at original resolution. No fresh provider call was made solely to test grouping, and actual streaming preservation remains the focused identity checks plus the earlier SOP46 live evidence, not a new streaming claim here.

## Preserved boundaries

The mapper groups only explicit emitted success shapes: a note record identity, or nonnegative integer memory counters with at least one actual change, with no refusal/error marker and a known session/person origin. It matches thread/session and stops at every noneligible raw record, including filtered checkpoints and other-thread entries. A missing/deleted learning record does not rewrite history; its event remains with an unavailable label. All raw IDs/anchors survive, and member IDs—not just the shared group ID—drive activity detection.

No Session, Engine, store, prompt, reader bridge, source permission/evidence or goal behavior changed. Full follow geometry is unchanged. Disclosure state is local view state; no persistent expansion/scroll registry was added. VoiceOver/human comprehension were not tested.

## Review follow-up and main integration

The initial three-scope review at3b31536 centrally passed79 core and29 presentation checks with no BLOCK/FIX NOW. Its small test-fidelity observation is fixed: mixed note/memory fixtures now use the real Contents shape, and an explicit P[note, global memory, note] case verifies the split. There are now30 focused checks.

Landedscope48 base b69dd14 was integrated mechanically; the grouping implementation is unchanged, and all86 current core checks plus30 focused checks and debug build pass. The targeted release Sophia product passed again (15.15s). No native/provider rerun was used solely for this unrelated base integration.

One low residual remains: after an errored general-thread turn with no replied marker, a later successful checkpoint memory write can join its preceding note run because the raw checkpoint record is appended afterward. The memory detail and See action remain available and the count remains update events. The existing mapper filters client checkpoint rows, so no visible checkpoint row is claimed. Distinguishing checkpoint-origin memory would need new metadata, outside this presentation slice; revisit if observed in use.
