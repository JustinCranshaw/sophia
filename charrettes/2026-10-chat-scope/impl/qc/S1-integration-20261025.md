# S1 integration verification — October 25, 2026

Status: implementation and native checks complete; independent exact-head follow-up is pending after the review fix below. This file records current observations separately from the historical October 20 reports retained beside it. It does not close SOP-31, SOP-38, attribution work, or S2–S7.

[Parent work: SOP-40](https://linear.app/decomposer/issue/SOP-40/integrate-the-existing-page-conversations-and-durable-undo). Reused the five existing S1 commits ending at `d683c75` on a new branch from current main. The original dirty checkout and original S1 branch/worktree remain untouched. Integrated main through `84ed001` (debug UX harness, SOP-27 exact duplicate handling and current-turn reset, SOP-19 canonical library identity). The reset occurs at actual queued turn dispatch rather than enqueue, so another thread cannot reset a reply still running.

The current Hide Book direction supersedes the historical Gate B instruction to reveal the book: a write preserves visibility and selection; only Open selects its page and opens the book. PLAN and app README reflect that narrow integration change. No S2–S7 feature is included.

## Current central checks

- Swift 6.2.3; official installed Claude Code 2.1.304 at `~/.local/bin/claude`. No adapter, SDK, Node or dependency was added.
- Debug app and MCP bundle built after integration with current main.
- All 54 core checks passed, retaining the 14 original S1 cases and Library identity case, and adding the no-op/external-edit and unknown-provenance preservation regressions below. [Output](s1-integration-core-20261025.log).
- Current `swift run sophia-checks --live /tmp/sophia-s1-live-20261025` exited 0. [Output](s1-integration-live-20261025.log). Actual emitted model was `claude-fable-5-1`, auth source `none`; this is Sophia's CLI default, separate from the required Opus review model. Actual page-origin revision and new R creation reached MCP with exact markers, hashes and P ownership. Previous bytes, checkpoint, briefing and confirmed-link reading were checked. LiveRunner does not establish UI routing or focus. Billing corroboration remains inconclusive.
- Final debug app/MCP bundle and release product build passed after the recovery narrowing (release: 13.29 seconds).

## Native observations

UI actions went only through the debug driver, with captured trees and PNGs. Libraries were copied from the explicitly synthetic, reduced Fourier fixture. An explicit huge return threshold prevented old fixture timestamps from triggering catch-up; these are not delayed-return or real-human observations.

1. Real normal P question: one answer, one P-tagged replied; quit/relaunch displayed the question once.
2. Real P long answer and queued Q question: both finished in their originating pages once. Goals and Notes kept Q named. While Q updated offscreen, P's native scroll fraction stayed exactly `0.636617749825297` across captures. This is a symmetric offscreen-streaming check of the scenario.
3. Real R creation from P: immutable file `1-5-windowing-and-spectral-leakage.md`, write owner P. Hidden book stayed hidden; selected P, unsent draft and caret survived. Typing a suffix after completion appended at the retained caret. Only explicit Open selected R and opened the book. [Preserved capture](s1-native-20261025/hidden-book-draft.png). The same test repeated from Contents, with write owner `""`, preserved Contents selection, hidden book, draft and caret; only explicit Open selected R. [Contents capture](s1-native-20261025/contents-draft.png).
4. Seeded personal P edit remained undoable after actual Q messages and relaunch; native Undo restored its exact previous bytes. A separate real P revision then survived a Q question and relaunch with Undo; Undo restored the byte-exact pre-revision page, with no P Undo-of-Undo. Independent R Undo remained correctly eligible.
5. Before the final recovery-contract narrowing below, native launches of copied recovery-revision/new fixtures retained exactly one recovered record across two opens. Both already contained one at copy time: these are repeat-open checks, not fresh crashes. External-overwrite/copy-only stayed at zero; their actual page UI offered no Undo. The new orphan appeared unfiled with “Undo recovered change” and no conversation write card; the recovered revision offered the same control. [Orphan capture](s1-native-20261025/recovered-page.png). Multi-edit controls released edits separately; undoing the second permission restored only its protection, retained the first permission, and offered no older Undo. Capture: `/tmp/sophia-s1-native-multi/results/1792907703310807000-e686c1.png`.
6. Finish for now immediately followed by a new P question produced one answer/completion, no connection error; the new checkpoint belongs to Contents and reply belongs to P.
7. A real model write against the open whole-page editor was refused with reason `open`, with no release action. Native click/type inserted personal wording plus a temporary token; Cmd-Z removed the temporary token only, Cmd-Return saved the personal wording. Capture: `/tmp/sophia-s1-native-main/results/1792908464110101000-1c132f.png`. A subsequent real protected-line revision was refused, quoting the actual edit; [permission capture](s1-native-20261025/protected-person-text.png). Release changed neither page bytes nor ordinary-message count and started no turn. The next explicit message applied the released change successfully.

All native app instances were quit through Cmd-Q at the current boundary; the personal app was left alone. Evidence remains under `/tmp/sophia-s1-native-*`.

## Review fix and accelerated return

The initial independent Opus review found one medium FIX NOW: the internal briefing process stops, but `contextLine` omitted its purpose-bearing text when rebuilding the next Contents conversation. Added a narrow briefing branch without changing message classification or schemas, plus assertions in the existing context check: the offer reaches Contents, stays out of P, and is excluded after clear. All 52 checks and debug/release builds passed again.

An actual native return with an explicitly accelerated **one-second** threshold then generated a welcome-back briefing. Its two offered options included predicting a short moving average near Nyquist. The person replied only “The second option, please.” The new Contents process continued with a 3-point moving-average/Nyquist prediction, without the task being restated. Capture: `/tmp/sophia-s1-native-main/results/1792909378617102000-6c0bac.png`. This supports offer continuity, not delayed retention or mastery. The model's two-option wording is not evidence that companion single-offer quality is solved.

## Bounded recovery correction

The independent lead initially deferred an identical-revision/external-edit edge. A separate disposable diagnostic against the pre-fix production core confirmed it: one recovered record, Undo offered, and outside wording lost after Undo. The integration owner treated this as FIX NOW because DATA-MODEL explicitly excludes outside changes from recovery/Undo; this does not retroactively change the reviewer's original disposition.

A byte-identical request is now recorded as the latest write with `unchanged: true`, without rewriting the page. Its redundant previous version is removed, with removal failures propagated. It has no Undo, and model/tool/card text labels it unchanged. No journal or extra record kind was added. A separate explicitly synthetic fixture prepared through the production store displayed [PAGE UNCHANGED with no Undo controls](s1-native-20261025/unchanged-card.png) in the actual app; no model was called for that card check. The focused production check proves no-op → outside edit → reopen creates no recovery or Undo and retains outside bytes. Under the final contract below, a genuine later copy/write cutoff is indexed as unknown with both versions preserved, without destructive Undo. Existing genuine recovery and page protection checks remain intact.

## Final recovery contract and native verification

A further source trace showed that copy-success/write-failure (or a crash after the copy) followed by outside editing has the same hash evidence as a genuine unrecorded Sophia revision. An outside-added orphan is equally ambiguous. The integration owner approved a narrower promise rather than adding a write-ahead journal: unknown disk states remain visible and inspectable, but inferred records never authorize destructive Undo. Normal recorded writes/edits retain durable one-way Undo. Genuine crash-before-entry restoration is manual, not automatic. PLAN, DATA-MODEL, app README and SOP-40 acceptance now state that tradeoff explicitly. Historical October 20 reports and earlier observations above are not proof of the final behavior.

Current production checks reject Undo for old recovered markers and outside-added orphans, preserve current and previous bytes across attempted Undo and idempotent reopen, and cover copy-success/write-failure followed by outside edits. Existing normal write/edit/release Undo checks remain in place. All 54 checks pass.

Actual native checks on the final behavior:

- An [old recovered revision](s1-native-20261025/unknown-revision.png) shows unknown authorship, no Undo, and Previous version.
- The [read-only previous-version sheet](s1-native-20261025/previous-version.png) fits a 900-wide window, displays selectable raw Markdown and offers Copy Markdown. Copy matched the exact previous body; closing inspection/copy left both current and previous files byte-identical. No restoration action is supplied.
- The old orphan and a [fresh outside-added page](s1-native-20261025/outside-added.png) remain visible/unfiled with unknown authorship and no deletion Undo.
- A normal recorded R write still offers Undo (`/tmp/sophia-s1-native-main/results/1792911144611134000-1d27d0.png`). No additional provider calls were needed for these checks.

Default image previews appeared to omit sidebar text, but original PNG inspection and the root's independent Vision OCR confirmed the text in the immutable source. No UI or capture code was changed based on that preview artifact. A case-sensitive test selector initially missed “Synthetic recovered page”; the native row existed and was then selected correctly. Neither was treated as a product failure.

## Pending before merge

- Fresh exact-head adaptive follow-up of the approved recovery narrowing, previous fixes and final evidence, with consolidated review comment.
- This work does not claim to fix every return or attribution issue; the automatic crash-before-entry Undo promise has explicitly been removed.
