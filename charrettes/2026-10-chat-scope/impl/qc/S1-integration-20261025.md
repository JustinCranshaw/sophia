# S1 integration verification — October 25, 2026

Status: implementation integrated; independent review and the remaining native checks below are pending. This file records current observations separately from the historical October 20 reports retained beside it. It does not close SOP-31, SOP-38, attribution work, or S2–S7.

[Parent work: SOP-40](https://linear.app/decomposer/issue/SOP-40/integrate-the-existing-page-conversations-and-durable-undo). Reused the five existing S1 commits ending at `d683c75` on a new branch from current main. The original dirty checkout and original S1 branch/worktree remain untouched. Integrated main through `84ed001` (debug UX harness, SOP-27 exact duplicate handling and current-turn reset, SOP-19 canonical library identity). The reset occurs at actual queued turn dispatch rather than enqueue, so another thread cannot reset a reply still running.

The current Hide Book direction supersedes the historical Gate B instruction to reveal the book: a write preserves visibility and selection; only Open selects its page and opens the book. PLAN and app README reflect that narrow integration change. No S2–S7 feature is included.

## Current central checks

- Swift 6.2.3; official installed Claude Code 2.1.304 at `~/.local/bin/claude`. No adapter, SDK, Node or dependency was added.
- Debug app and MCP bundle built after integration with current main.
- All 52 core checks passed, retaining the 14 S1 cases and the new Library identity case. [Output](s1-integration-core-20261025.log).
- Current `swift run sophia-checks --live /tmp/sophia-s1-live-20261025` exited 0. [Output](s1-integration-live-20261025.log). Actual emitted model was `claude-fable-5-1`, auth source `none`; this is Sophia's CLI default, separate from the required Opus review model. Actual page-origin revision and new R creation reached MCP with exact markers, hashes and P ownership. Previous bytes, checkpoint, briefing and confirmed-link reading were checked. LiveRunner does not establish UI routing or focus. Billing corroboration remains inconclusive.
- Release build is in progress at initial review freeze.

## Native observations so far

UI actions went only through the debug driver, with captured trees and PNGs. Libraries were copied from the explicitly synthetic, reduced Fourier fixture. An explicit huge return threshold prevented old fixture timestamps from triggering catch-up; these are not delayed-return or real-human observations.

1. Real normal P question: one answer, one P-tagged replied; quit/relaunch displayed the question once.
2. Real P long answer and queued Q question: both finished in their originating pages once. Goals and Notes kept Q named. While Q updated offscreen, P's native scroll fraction stayed exactly `0.636617749825297` across captures. This is a symmetric offscreen-streaming check of the scenario.
3. Real R creation from P: immutable file `1-5-windowing-and-spectral-leakage.md`, write owner P. Hidden book stayed hidden; selected P, unsent draft and caret survived. Typing a suffix after completion appended at the retained caret. Only explicit Open selected R and opened the book. Capture: `/tmp/sophia-s1-native-main/results/1792908055643728000-45095e.png`.
4. Seeded personal P edit remained undoable after actual Q messages and relaunch; native Undo restored its exact previous bytes. A separate real P revision then survived a Q question and relaunch with Undo; Undo restored the byte-exact pre-revision page, with no P Undo-of-Undo. Independent R Undo remained correctly eligible.
5. Native launches of copied recovery-revision/new fixtures retained exactly one recovered record across two opens. Both already contained one at copy time: these are repeat-open checks, not fresh crashes. External-overwrite/copy-only stayed at zero. Multi-edit controls released edits separately; undoing the second permission restored only its protection, retained the first permission, and offered no older Undo. Capture: `/tmp/sophia-s1-native-multi/results/1792907703310807000-e686c1.png`.
6. Finish for now immediately followed by a new P question produced one answer/completion, no connection error; the new checkpoint belongs to Contents and reply belongs to P.
7. A real model write against the open whole-page editor was refused with reason `open`, with no release action. Native click/type inserted personal wording plus a temporary token; Cmd-Z removed the temporary token only, Cmd-Return saved the personal wording. Capture: `/tmp/sophia-s1-native-main/results/1792908464110101000-1c132f.png`.

All native app instances were quit through Cmd-Q at the current boundary; the personal app was left alone. Evidence remains under `/tmp/sophia-s1-native-*`.

## Pending before merge

- Repeat new R creation from Contents with hidden-book, selection, draft/caret checks.
- Real protected-person-line refusal quoting the edit; release applies to next message and initiates no model turn.
- Inspect recovered/new and outside/copy-only page UI for appropriate Undo and no recovered-write conversation card.
- Final release build, exact-head independent review, final evidence reconciliation and reopening check.
