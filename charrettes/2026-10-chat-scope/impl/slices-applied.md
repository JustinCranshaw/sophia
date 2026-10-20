# Page-owned conversations: applied implementation slices

Gate A deliverable · 2026-10-19 · awaiting Justin's approval. No implementation is authorized by silence.

This replaces S1–S7 of `charrettes/2026-10-chat-scope/C4/slices.md` for implementation. The operator decisions and applied review govern older material (`qc/gate2.md:5–16,42–51`; `qc/review.md:20–30`). The specification is DATA-MODEL.md, PLAN.md §4–5, SOPHIA.md and EDITING.md. AGENTS.md is locked. All line citations below refer to the files read on this date, relative to the project root; `qc/`, `briefs/` and `impl/` abbreviate paths under `charrettes/2026-10-chat-scope/`.

The eleven scenarios use the disposable Fourier fixture in `charrettes/2026-10-chat-scope/briefs/scenarios.md:5–40,42–70`. P is `1-3-convolution-theorem.md`, Q is `1-4-sampling.md`, and R is `1-5-windowing.md`. Scenario 10's request for a resume-failure announcement is superseded by silent reconstruction (`PLAN.md:191–199`). Scenario 6 stays one conversation on P; it adds no subthread machinery.

## Shared implementation and evidence contract

- The orchestrator writes briefs, reads diffs and checks, runs verification, and records QC; it does not implement code. After Gate A, launch one Opus implementer for each slice, followed by a fresh independent Opus reviewer at its boundary. Give the reviewer the brief, specification and actual diff, not the implementer's summary. Require findings with file/line citations and a concrete failure scenario. Send confirmed findings to the implementer; allow at most two fix rounds, then stop if unresolved. Do not silently substitute another model or execution route.
- **Execution prerequisite:** the current collaboration tool exposes GPT models, not `model: "opus"` or `subagent_type: "gk"`. No implementation agent has been launched. The requested Opus Agent facility must be available before S1 can begin; Gate A approval alone does not supply that capability.
- Before each slice, snapshot `app/Sources` and `app/Package.swift` under `charrettes/2026-10-chat-scope/snapshots/app-before-S<n>/`, preserving the `Sources/` tree and package file. Source inspection on this date confirmed that `git rev-parse --show-toplevel` fails because the project is not a repository. Justin subsequently offered to initialize it. Recheck before implementation; if it becomes a repository, use an isolated branch and per-slice commits instead, preserving any pre-existing work.
- Write `impl/briefs/S<n>.md` before launching its implementer: exact slice scope, current doc lines, allowed files, commands, checks, observables and evidence categories. Write `impl/qc/S<n>.md` after review: orchestrator-observed commands/output and source inspection, separately attributed implementer/reviewer reports, remaining risks, untested behavior and by-hand checks for Justin.
- All new deterministic cases are named functions in the existing `app/Sources/sophia-checks/main.swift`, invoked by its normal executable. Each case below names its specification bullet or scenario and must call the production function it claims to verify. `sophia-checks` depends only on SophiaCore (`app/Package.swift:15–16`); its passing result cannot establish NotebookSession wiring. Reader cases stay in the existing reader-check executable. No framework, separate harness or new command-line mode.
- Preserve every existing check and its strength. If an existing assertion conflicts with the applied specification, identify it and stop rather than weaken/delete it to get green. The orchestrator reads the new checks and the code they call, then independently runs the required commands.
- Runtime storage remains the existing notebook files. Only the specified transcript additions—`page`, `clear`, `hash`, `replied`, `recovered`—are introduced; do not add a new learning-record kind, stored cursor, summary, session map, retry ledger, navigation/dismissal state or undo state (`DATA-MODEL.md:31–44,111–141,147–167,315`). Derived values and queues below are in memory. Flag a need for more storage and stop.
- All page operations retain store checks and notebook locking. Sophia cannot delete pages, overwrite protected person text, or confirm/complete/drop goals (`AGENTS.md:36–45`; `DATA-MODEL.md:143–167,221–257`). A person's explicit Undo remains the specified exception that removes a newly written page.
- Nothing in the new visible flow explains checkpoints, notes status, provider sessions, context or tokens. No amber state, context marker, subtitle, ⌘L, pointer card, permanent authorship tag or special new-page undo window. Plain edit/refusal/release entries required by EDITING.md remain. Where the current UI says “End session”, use ordinary action wording such as “Finish for now”; keep the internal `endSession()` trigger. This follows the user's stricter visible-language rule; no new control is added.
- Do not carry forward S5's ring or “Go to the open question ⇧⌘J”: the applied return contract specifies one “Continue on …” link (`PLAN.md:226`), not these extra controls. The only transient row indication is for a reply completed offscreen (`PLAN.md:224`).
- Update `app/README.md` only for behavior or commands actually changed in that slice. The four applied specification docs already describe the intended behavior; do not edit them to excuse an implementation mismatch. Record exact doc changes in QC. No AGENTS.md edits.

### Commands and their limits

Run from `app/`, using `app/README.md:10–42,62`:

```sh
scripts/make-app.sh debug
swift run sophia-checks
swift run sophia-reader-checks
swift run sophia-checks --live <empty-disposable-directory>
SOPHIA_LIBRARY=<disposable-library> build/Sophia.app/Contents/MacOS/Sophia
SOPHIA_RETURN_GAP=1 SOPHIA_LIBRARY=<disposable-library> build/Sophia.app/Contents/MacOS/Sophia
```

The build and core checks are required at every slice. Run the reader checks whenever reader code/resources change (required in S3); use the documented `--scroll-spike` if changing editor scrolling. The documented `SOPHIA_SNAPSHOT` variables may capture appearance, but snapshots do not establish focus, selection, keyboard behavior or routing. Replace angle-bracket placeholders with the actual disposable paths and record those paths in QC.

Extend existing `LiveRun.swift` under `--live` for the live cases below; do not invent flags. Keep existing live assertions. LiveRun drives ClaudeEngine, not NotebookSession: label that limitation every time. Use only the existing unmodified Claude binary and the person's login, with the existing billing guard; no credential inspection/copying/logging, API fallback, provider outreach or unrelated external messages. The requested model runs are authorized; use non-sensitive material and avoid research calls for these fixtures. Record actual launched engine/version evidence without treating login as billing attribution. Missing billing corroboration is inconclusive.

## S1 — Page threads, durable undo, and stable selection

**Contract.** Every entry goes to its correct thread; each thread starts with the specified stored material; writes preserve selection/focus; Undo is one-way and page-local across messages and relaunch. References: `DATA-MODEL.md:114–127,130–167,227,232–254,273–287,335–342,345–346`; `PLAN.md:191–199,222–224`; `SOPHIA.md:64–70,82–86`; `EDITING.md:34,42–56,64–70`. Scenarios 2, 3, 4, 8, 9 and 10.

**SophiaCore additions/changes.**

- Add `NotebookStore.thread(of:)`, `threadEntries(for:)`, `window(for:before:)`, `carried(for:before:)`, `cursor(for:before:)` and `notes(for:)`. `before` is the outgoing message ID, excluded from reconstruction. Window uses the transcript position of `through`, not the later checkpoint entry; carried material is at most six person/Sophia messages. Purpose-bearing entries are not messages. Honor any existing clear from the outset.
- Add `creatingExchange(for:)` as a derived query shared by context and the later S6 card. Bound it to the creating turn, exclude recovered writes, and retain it after checkpoints. The creating exchange is the specified exception to ordinary cross-thread word isolation; it is not an excuse to include the origin thread's whole history. Do not reintroduce pre-clear words into a cleared destination thread (`DATA-MODEL.md:138,140,278`).
- Add `latestPageAction(for:)`, `isUndoable(_:)`, `isReleaseUndoable(_:)`; all use one latest-action definition including writes, edits, releases, undo-page and undo-release. Resolve releases to their edited file. Recheck eligibility under the lock when acting, not just while drawing a button. An undo itself never offers Undo.
- Change `writePage`, `editPage`, `undoPageWrite`, `releaseEdits` and `undoRelease` to stamp the specified thread/hash fields. A successful write takes the originating thread; a refused write takes its target page. Revision/edit Undo takes its target; new-page Undo takes the originating conversation. Hash actual full page bytes. Releases do not acquire an invented hash field.
- Change `uniqueFile` to exclude names ever used in the transcript, including undone pages. Preserve filenames through title revisions and chapter moves. Change new-page save order to file → entry → notebook.json; revision to previous copy → atomic page write → entry. New-page Undo is metadata → file removal → entry; revision/edit Undo replaces in one step.
- Add `NotebookStore.open(url:)` as the app opening path: under the lock, compare against metadata/transcript as found at launch, record recoverable writes first, then list orphan pages as unfiled. Move recovery out of the plain initializer so an MCP process cannot normalize metadata ahead of recovery. Preserve legacy draft handling after this ordering. Reopening is idempotent; no-hash legacy writes are not recovered or offered Undo.
- Make transcript append separate a torn last line from the next entry. Preserve existing parsing/locking behavior.
- Add thread inputs to `writeGoal`/`writeNote`: goals cite the latest person message in their origin; notes locate quotes in that thread first, then the same app session. The note quota remains per app launch.
- Add `Config.page` to ClaudeEngine and pass `[notebook, session, page]` to sophia-mcp. Bind event handling to immutable engine identity and originating thread. Add `stopRequested` to `.exited`, set before stopping; an old engine's exit cannot clear a replacement engine.
- Add `Prompts.context(...thread:before:)` and pure `Prompts.turnPrefix(...)`. Context contains standing material, the selected thread's page/notes, creating exchange, carried messages and later messages, with the specified write/refusal/release lines. Prefix carries page edits, releases, undos and this-page changes since the last turn in that thread. No private provider-state claims.
- Extract `finishCheckpoint(...) -> .failed | .saved` into the store and use it for existing manual/return checkpoints: validate before mutation; error, unreadable reply and all-rejected nonempty notes fail without notes/memory/entry; valid empty notes succeed. Checkpoint prompt labels message pages and includes records since the previous checkpoint entry across sessions. Do not persist rejected-record reasons. S2 adds the complete clear/failure matrix; safety is not deferred.
- Add `nextStep(thread:...)` as the dispatch decision used by the app and LiveRun, with existing pending-request handling. Add the automatic 30-message condition only in S7. Add `isPending` so queued/running ownership is explicit; S4 builds interruption rendering on it.

**Files.** `app/Sources/SophiaCore/{NotebookStore,PageEdits,Memory,Prompts,ClaudeEngine}.swift`, `app/Sources/sophia-mcp/main.swift`, `app/Sources/Sophia/{NotebookSession,ConversationView,BookView,SidebarView}.swift`, existing core/live checks and `app/README.md`. Change `RecordChecks.swift` only if the existing parser/validation cannot express the required checkpoint result. No new dependencies.

**NotebookSession wiring.** Open via `NotebookStore.open`. Track the active conversation independently of Goals/Notes book selection. Selecting P/Q/Contents chooses that conversation; opening Goals/Notes keeps it and its named composer. Keep engines by thread in memory, with a separate short-lived checkpoint/briefing process; never store or resume provider IDs. Serialize model work and queue messages with immutable message/thread identity so Q can wait while P answers. Route streamed text, WebSearch, tool results, goals and completion to their origin. Append exactly one `replied` on normal user-turn completion; errors do not get it, explicit stops get `stopped`, internal requests do not complete a user turn. Clear all thread processes after a successful checkpoint; suppress expected exits by engine identity. Remove `lastWrites`/`lastReleases` eligibility caches. Both banner and entry Undo use the store predicate and correct author/action label. `showWrittenPage` reveals a hidden book without changing selection or taking composer focus; supply Open on the result card. Open-section refusals have no release button; permission cards say it applies on the next message. No automatic turn on release. Preserve text-editor/composer ⌘Z.

**New sophia-checks cases.**

| Case name | Required assertion and specification |
|---|---|
| `verificationInterleavedThreadOwnership` | Exercise production stamping for person/Sophia/tool/client paths, including WebSearch, goal_noted, note, set_chapter, about_you/link, memory, stopped/replied, edits/refusals/releases/undos and checkpoint/briefing. Legacy/no-page and empty-page entries are Contents; action entries target their page; successful cross-page writes retain origin. `DATA-MODEL.md:335`. |
| `verificationUndoAcrossScopesAndReopen` | P's write/edit/new-page Undo survives messages in P and Q and `open`; no special new-page window. A stale UI action after another writer changes P is rejected under lock. `DATA-MODEL.md:337`; scenario 9. |
| `verificationLatestReleaseAndOneWayUndo` | Edit → release leaves only release undoable; Undo leaves no undoable action; a later write disables the earlier release. Both predicates agree. `DATA-MODEL.md:345`. |
| `verificationRecoveredRevisionBeforeEntry` | Copy/page without entry recovers once, restores exact prior bytes, disables old Undo; include a revision after a prior undo and repeated opens. `DATA-MODEL.md:338`. |
| `verificationRecoveredNewPageBeforeUnfiled` | New file absent from launch metadata/transcript gets recovered entry before unfiled listing; file with a write entry but absent metadata only gets listed. `DATA-MODEL.md:338`. |
| `verificationExternalAndCopyOnlyChanges` | Outside overwrite with untouched previous copy records nothing/offers no Undo; copy-only crash offers no no-op Undo; no-hash proposal-era fixture remains compatible. `DATA-MODEL.md:338–339`. |
| `verificationAtomicUndoAndNewPageCutoff` | Production revision/edit Undo preserves a present canonical file and exact restored hash; represent pre/post atomic boundaries. New-page removal cut after metadata is rediscovered unfiled and still undoable; cut after file removal does not fabricate recovery. `DATA-MODEL.md:340,165`. Do not claim a fixture simulates an OS crash. |
| `verificationNeverReuseUndoneFilename` | Undo a new page after conversation in it; its messages remain; same-title creation gets a different file; title/chapter changes retain identity. `DATA-MODEL.md:343`. |
| `verificationWindowUsesThroughPosition` | Message between through and checkpoint stays verbatim; outgoing message occurs only as the turn; foreign words excluded except the creating exchange; purpose entries excluded from six-message count. `DATA-MODEL.md:336`. |
| `scenario2PageContextAndBookChanges` | Page body and relevant notes by page/message/quote references reach the right context. Prefix includes P's edit hunk, cross-thread revision of Q, and Undo of Sophia's Q revision; excludes recovered writes as conversation activity. Scenario 2; `DATA-MODEL.md:273–287`. |
| `scenario3GoalAndNoteQuoteOwnership` | P goal cites P despite a later queued Q message; R note may quote same-session creating P message; quota stays notebook-session-wide. Scenario 3; `DATA-MODEL.md:227`. |
| `verificationCheckpointValidationBeforeMutation` | Malformed/error/all-rejected replies leave both logs and memory unchanged; valid empty reply advances through. `DATA-MODEL.md:342`. |
| `scenario10TornTranscriptAppend` | Append after an incomplete last JSON line remains individually parseable and cannot merge with that fragment. Scenario 10. |
| `scenario10IntentionalEngineExit` | Exercise real ClaudeEngine Process lifecycle with `/usr/bin/true`: stop requested versus ordinary exit flags differ. Verify MCP launch arguments include immutable page and no resume argument. Scenario 10; `PLAN.md:199`. |

**Live addition.** Use Config.page P to revise P through actual MCP. Inspect the saved entry for origin P, hash and correct bytes; have a P-origin turn write R and verify its entry still says P. This does not verify the app's selection or `replied` wiring.

**By hand at Gate B (all remain pending until Justin reports).**

1. Send on P; after normal completion inspect the transcript: exactly one `replied` tagged P after that turn. Reopen and find the same messages once. S4 will add the interruption affordance; do not claim its absence here proves detection.
2. While P streams, select Q and send. Q's message appears once; P's remaining text stays in P; Q is answered after P. Reopen both: no misfiled entry. Goals/Notes keep the named active conversation.
3. Hide the book on P, type in the composer while Sophia writes R. The book reappears with P still selected, P still named above the composer, typed text/caret retained, and an Open R action in P's conversation. Repeat from Contents.
4. Revise P, send on Q, reopen P and relaunch: the same latest action has Undo. Undo once: original bytes restored and no Undo of that Undo. Release a protected edit: only “Undo permission to change your edit” remains, in both banner and applicable marker.
5. On disposable copies while the app is closed, reproduce revision-copy-plus-new-bytes and new-orphan-file states. Reopen: one recovered entry per cut-off write and eligible Undo; new file is also unfiled. Repeat open: no duplicate. Outside overwrite/copy-only variants offer no Undo. Recovered entries never appear as Sophia's conversation activity.
6. Finish for now, then send immediately. The message waits, then receives one reply; no spurious “connection closed” from the stopped engine. Inspect checkpoint page `""` and the user's reply page independently.
7. Open P's section editor, request a conflicting write, then commit and request a protected-line rewrite. Open refusal offers no release; protected refusal quotes the edit and reason. Release changes no page and launches no turn; next message carries permission. ⌘Z affects focused text only.

**Gate B:** stop after S1 implementation, independent review, orchestrator checks and `impl/qc/S1.md`. Present the exact fixture paths and these observables; wait for Justin's explicit continuation.

## S2 — Fresh start, reading history, recall and checkpoint failure

**Contract.** Clear waits for successful notes, happens only between turns, and folds only its own earlier history. No pre-clear word is resent, even as carried material. A failed clear leaves history and unsent text intact. References: `DATA-MODEL.md:128,138–139,230–254,336,342–344`; `PLAN.md:228–230`; `SOPHIA.md:83,88–99`. Scenarios 5 and 11.

**SophiaCore additions/changes.** Add `clearThread(_:session:)` as the locked append of the existing clear shape, called only after `.saved`; add pure `freshStartOutcome(checkpoint:waiting:)`, used by NotebookSession so success/failure/send ordering is exercisable in core checks. Add `history(for:)` deriving pre-clear/current entries without new persistence. Complete `finishCheckpoint` tests for mixed accepted/rejected notes and memory; validation failure must precede any memory change. Extend existing `recall(ids:page:words:limit:)` so page selects both relevant notes and tagged person messages, including folded history and an undone page's retained conversation. Page + words filters messages together; unrelated matches do not leak in. Do not add a message record kind or copy history into learning records.

**Files.** Core NotebookStore, Memory, Prompts, RecordChecks only as needed; NotebookSession, ConversationView and SophiaApp for command/shortcut wiring; sophia-mcp's recall schema text; existing checks/LiveRun and README.

**NotebookSession wiring.** Bind ⇧⌘N and the page/Contents action to the same between-turn eligibility. Capture the target when invoked. Retain composer text during the operation; a send attempted during clear stays in memory, not as a pre-clear transcript message. On `.saved`, stop/invalidate all old thread processes, append clear, then append/dispatch any waiting message to its captured thread. On `.failed`, append no clear/person message, keep the draft unsent, and show “Couldn't start fresh. Your message hasn't been sent.” Selection changes do not retarget pending work or lose its draft. Ordinary checkpoint sends already stored after through remain in their own window. Remove checkpoint activity/rejection UI and stored rejected reasons; only the requested fresh-start action has an underway/failure indication. Reading folded/older entries never changes the destination or model window. Add date separators/loading older history as reading affordances only.

**New sophia-checks cases.**

- `verificationClearExcludesAllEarlierWords`: before-through carried and after-through window messages before clear are both excluded; writes/refusals/releases and originating exchange cannot bypass this boundary. `DATA-MODEL.md:343`.
- `verificationClearWaitsAndFailedDraftIsUnsent`: invoke the production clear/dispatch outcome functions for success, parse failure, turn error and all-rejected records; assert no clear or queued person entry on failure and clear precedes person entry on success. `DATA-MODEL.md:342–343`.
- `verificationEmptyVersusAllRejectedCheckpoint`: empty notes succeeds, nonempty all-rejected fails even with plausible memory; mixed accepted/rejected succeeds, stores only valid records, stores no rejection reasons; failed variants preserve memory/log bytes/through. `DATA-MODEL.md:342`.
- `verificationCheckpointAcrossThreadsAndSessions`: prompt labels pages, contains already-noted records since the prior checkpoint, spans app launches, ignores edit entries as attempts, does not offer covered messages again, does not consume a message that arrived after captured through. `DATA-MODEL.md:232–243,334,336`.
- `scenario5RecallFoldedPageHistory`: page + words finds the exact P attempt, excludes Q's same-word attempt, and still retrieves words after clear or new-page Undo. `DATA-MODEL.md:57,155,343–344`.
- `scenario11HistoryReadingDoesNotClear`: derived history/date grouping changes neither transcript nor context boundaries; only an actual clear folds earlier entries. `PLAN.md:230`.

**Live additions.** Retrieve the earlier 2.2 zero-padding exchange through `recall(page:)`. On P, checkpoint then clear and ask to continue the unfinished derivation: record whether the open step survives in notes (`DATA-MODEL.md:344`). This is distinct from S7's automatic-checkpoint test.

**By hand.**

1. While a reply runs or a message waits, menu action is disabled and ⇧⌘N appends no clear. Between turns it is enabled, with the correct P/Contents wording.
2. Start fresh, type/send a draft while it runs: draft stays visible until success; transcript orders checkpoint → clear → person message, all with correct ownership. Earlier text is folded and expands in place; the composer still names P.
3. Interrupt the fresh-start model process in a disposable run without closing the app: no clear/new person entry, original conversation remains, exact draft remains unsent and the specified failure sentence appears. Quit/relaunch during another pending clear: no false clear; pre-clear history remains. Do not promise unsaved composer text survives a process crash.
4. Follow an old source link and return; it reveals/loads its exchange, including folded history, and offers a way back. Reading it neither clears the conversation nor changes what the next send includes. No checkpoint boundary, session fold or context explanation appears.

## S3 — Ask Sophia about a selected passage

**Contract.** Selection on P is quoted into P's composer; normal selection/copy, editor behavior and page-owned send remain intact. References: `PLAN.md:222,224,232`; `EDITING.md:34,92`; scenario 1 (`briefs/scenarios.md:44`).

**SophiaCore additions/changes.** No new core abstraction is warranted for a WebKit selection action. Use S1's thread-aware append/dispatch path. The core case below covers its persistence endpoint, not native selection.

**Files.** `SophiaReader/MarkdownReader.swift` and the existing Reader scripts for selection messages; `sophia-reader-checks/ReaderChecks.swift`; BookView, NotebookSession, ConversationView as needed for the composer quote; existing core checks and README.

**NotebookSession wiring.** Validate the reader event against the originating displayed file, capture P, bring P's named composer into focus with the selected quote, and preserve other unsent text. Selection alone saves no transcript entry or page edit. Sending uses the ordinary P path; a subsequent revision does not change selection. Keep the bridge restricted; the event is text, not executable content.

**New checks.** `scenario1SelectedQuoteUsesPageThread` in sophia-checks calls the production append/context path with a quoted P selection and asserts P ownership and byte-preserved quote. In reader checks, exercise real WebKit selection delivery of text and section and reject invalid events; retain existing selection/copy, no-op edit, CSP and byte-identity checks. Passing core checks alone says nothing about the reader-to-composer connection.

**By hand.** Select the fixture's “is a sinc” sentence in P and choose Ask Sophia about this. P's composer contains that exact quote plus the question; sending creates one P person entry. Sophia's revision stays on P, with the normal Undo. Double-click still selects a word; copy works; ⌘Z targets composer/editor text. Run all core checks, reader checks and app build.

## S4 — Interrupted replies and Ask again

**Contract.** A tagged person message is interrupted only without a following same-thread completion/stop and without running/queued work. Ask again continues saved effects without another person entry. All reconstruction is silent. References: `DATA-MODEL.md:129,141,341–342,347`; `PLAN.md:161,199`; `SOPHIA.md:84–86,103`. Scenario 10. Depends on Gate B's observed `replied` wiring.

**SophiaCore additions/changes.** Add `isInterrupted(_:queued:running:)` using S1's pending identity and same-thread completion, and `retryDispatch(for:queued:running:)` returning the existing message identity/text only when eligible. NotebookSession uses this decision rather than its normal append-new-message path. Extend `Prompts.turnPrefix` for a retry with the existing partial text and page outcomes, instructing inspection before any repeated write. Reuse existing message ID and page; no retry record or stored state. No `rebuiltAfterRelaunch` function, amber state or rebuild prefix.

**Files.** NotebookStore, Prompts, NotebookSession, ConversationView; existing checks/LiveRun and README.

**NotebookSession wiring.** Supply actual queue/running identities to detection; hide interruption while either is pending. Ask again captures the interrupted message ID, dispatches its existing text once without appending a new person message, and preserves earlier partial replies. Append replied only on successful completion. Explicit Stop is not an interrupted reply. Late exits from intentionally stopped engines cannot mark the replacement turn interrupted.

**New sophia-checks cases.**

- `verificationInterruptedCompletionAndQueue`: write_page + replied is complete; text then unfinished tool without replied is interrupted; stopped is not; queued/running messages are not; legacy untagged messages are not; unrelated thread completions and internal checkpoints cannot finish this turn. A Contents turn completed after internal records remains complete. `DATA-MODEL.md:341–342`.
- `verificationRetryRetainsSavedEffects`: rebuilt prompt excludes duplicate outgoing text, includes persisted partial response and successful write outcome, and identifies the page to inspect before repeating work; do not count recovered entries as Sophia activity. `DATA-MODEL.md:347`.
- `scenario10RetryDoesNotAppendPersonMessage`: exercise the production retry dispatch decision with the existing ID; a successful retry is followed by one same-thread replied and no new person entry. App button behavior remains a by-hand check.

**Live addition.** Cut a turn after a confirmed page write but before normal completion, rebuild and retry the existing request. Assert no duplicate page/new-person entry, inspect tools and bytes, and retain the transcript excerpt. Prompt inspection alone cannot pass `DATA-MODEL.md:347`.

**By hand.** Force-quit mid-reply after persisted text, reopen P: interruption appears on that exchange; Q/Contents remain normal. Ask again yields one continuation, no new person entry, no duplicate saved page and one replied. Repeat with a queued Q message: it shows no interruption while waiting, but an unanswered persisted message becomes interrupted after crash/relaunch. No rebuild announcement or context/status decoration appears.

## S5 — Return briefing and the unresolved exchange

**Contract.** After six hours, catch-up notes precede a short grounded Contents briefing and one link to the unresolved exchange, whoever asked it. A person opening Q before reading it sees it once above the book; empty/short-gap returns do not redirect. References: `DATA-MODEL.md:232–245,273–289`; `PLAN.md:226,230`; `SOPHIA.md:103`. Scenario 7.

**SophiaCore additions/changes.** Reuse `isReturn(after:now:)`, making sure its latest-message test counts briefings and ignores tool/edit timestamps. Add `continuationTarget(for:)` to follow the briefing's existing valid refs through notes to the relevant message/thread; do not manufacture a last-Sophia-question heuristic or store a target. Add pure `returnDisposition(briefing:didNavigate:)` for nonempty/empty briefing and intervening explicit navigation so it is tested without SwiftUI. Resolve malformed/unresolvable references without invented links. If valid evidence cannot identify the required unresolved exchange, report the fixture/failure rather than adding storage or guessing.

**Files.** NotebookStore, Prompts if necessary for existing briefing format; NotebookSession, ConversationView, BookView and SidebarView only for existing navigation; checks/LiveRun and README.

**NotebookSession wiring.** Catch-up uses the separate process and the common finishCheckpoint result. Never treat failed catch-up as successful notes. Preserve a waiting user message and retry failed notes on the next turn without hiding the failure behind a false through. A nonempty briefing selects Contents unless the person has explicitly navigated during return; then display the same briefing once above that book until dismissed. Use in-memory seen/dismissed state. Empty briefing shows nothing and preserves the available selection; no new persisted last-page state. The link reveals even folded history and uses S2's way back. Queued sends keep their original destination. No ring, shortcut, extra briefing message or mandatory exercise.

**New sophia-checks cases.**

- `scenario7SixHourReturnBoundary`: just below/at/above six hours; latest person/Sophia/briefing counts, edits/tools do not. `DATA-MODEL.md:244`.
- `scenario7BriefingTargetsEitherSpeaker`: briefing refs resolve a person objection and a Sophia derivation question, including a folded target; no unrelated “latest question” fallback; invalid refs do not invent a destination. `PLAN.md:226`.
- `scenario7EmptyBriefingAndEarlyNavigation`: production disposition preserves selection for empty/short-gap return and explicit Q navigation; otherwise routes nonempty briefing to Contents. Validate word limit/grounded refs and no rejected-record persistence. `DATA-MODEL.md:245,249–254`.
- `scenario7CatchUpBeforeBriefing`: current checkpoint decision/through flow covers unnoted messages across threads before requesting briefing, without treating failure as saved. `DATA-MODEL.md:236,240–244`.

**By hand.** Launch the disposable fixture with `SOPHIA_RETURN_GAP=1`: inspect catch-up then briefing in Contents and click Continue on 1.3; P's exact unresolved exchange is visible, even if folded. Repeat, opening Q before the briefing arrives: Q stays selected, its composer remains Q, one briefing appears above the book and dismissal removes it. Empty and short-gap variants show no briefing/redirect. Type while catch-up runs: one message is eventually answered in its captured thread.

## S6 — Write cards, Started from, and Elsewhere

**Contract.** Write results remain in their originating conversation with Open. A page's Started from card and model context retain the bounded creating exchange after checkpoints. Cross-thread awareness contains activity lines, never ordinary foreign dialogue. References: `DATA-MODEL.md:115,120–125,138,140,273–287,346`; `PLAN.md:224,230`; `SOPHIA.md:84–85`. Scenarios 2 and 4.

**SophiaCore additions/changes.** Complete S1's `creatingExchange(for:)` for UI consumption and add `elsewhere(for:before:)`, using the current thread's previous-turn cursor and attributing activity to the conversation where it happened. Notes citing a page or its messages remain available. Derive one line per other active conversation; a write creating R from P names P's activity, not a conversation on R. Edits, refusals, undos and recovered writes alone are not conversation activity. No pointer query.

**Files.** NotebookStore, Prompts, NotebookSession, ConversationView, SidebarView; existing checks/LiveRun and README.

**NotebookSession wiring.** Render Started from using the shared query; its source link targets the original exchange and expands folded history through S2 navigation. Write cards expose Open without automatic selection/focus change. Include Elsewhere lines in the model turn prefix. A reply completed while another thread is shown marks its origin row; showing that conversation clears the indication, and relaunch does not restore it. Do not add a separate persisted write-target dot or navigation-history pointer.

**New sophia-checks cases.**

- `verificationCreatingExchangeSurvivesCheckpoint`: R retains its source exchange in built context/card after checkpoint and reopen; ordinary foreign dialogue stays absent. R's own later clear still excludes pre-clear verbatim context. `DATA-MODEL.md:343,346`.
- `verificationCreatingFirstLineIsBounded`: first Sophia text in the creating turn may precede or follow the write; never take text after the next person message. Tool-only turn shows question alone; legacy/recovered-only page has no invented card. `DATA-MODEL.md:140,346`.
- `scenario4ElsewhereNamesOrigin`: Q sees P's new-page activity, not R as a newly active conversation; Q's own write to P is not foreign activity. Purpose-only edit/refusal/undo/recovery entries do not mark activity. `DATA-MODEL.md:285–287`.
- `scenario2ElsewhereContainsNoForeignWords`: one line per active origin since Q's prior turn; no duplicated foreign message text; cursor on first turn follows the stored through boundary. `DATA-MODEL.md:282–287`.

**Live addition.** After P creates R and a checkpoint succeeds, start a fresh R process and ask about the originating leakage question. Inspect supplied context and actual continuation; retain evidence separately from any inference about what the model remembered.

**By hand.** Create R while talking on P; remain on P and use Open R. Started from quotes the correct bounded exchange; its link opens P at that exchange, including after clear, with a way back. Repeat after checkpoint and relaunch: card remains. With a tool-only creating turn, no later unrelated answer appears on it. Finish a P reply while viewing Q: only P's row gains the transient indication, cleared on showing P and absent after relaunch. No pointer card appears when switching pages.

## S7 — Automatic checkpoint at 30 messages and the owned derivation test

**Contract.** After a completed turn, 30 or more person/Sophia messages in that thread since both through and latest clear trigger the notebook-wide checkpoint. The separate process validates notes, advances through only on success, and ends old thread processes so future context follows the saved notes. References: `DATA-MODEL.md:138,232–243,342,348`; `PLAN.md:185,191–199`; scenario 11 (`briefs/scenarios.md:67–70`). Keep threshold 30.

**SophiaCore additions/changes.** Extend production `nextStep(thread:...)` to return `.checkpoint` at 30 messages after a turn ends. Count person/Sophia messages without purpose, not tools, writes, edits, completion markers or briefing. Bound by through and clear, excluding the carried six. A failed finishCheckpoint leaves the triggering window eligible; the next user turn retries once through normal dispatch, not a tight automatic retry loop. Use the same helper from app and LiveRun.

**Files.** NotebookStore, NotebookSession, existing checks/LiveRun and README. Change Prompts only if required for the specified existing checkpoint content, without retuning companion instructions to make the experiment pass.

**NotebookSession wiring.** On normal turn completion, record replied, evaluate nextStep, and perform any needed checkpoint before dispatching a waiting user turn. Freeze through at request creation; a message arriving later remains verbatim in its correct thread. On success, invalidate every old thread engine before the next send; expected exits cannot clear queued work or produce connection errors. On failure, preserve history/memory/through and queued text; avoid a silent deadlock or repeated background retry loop. Nothing visible announces automatic notes, counts or context boundaries.

**New sophia-checks cases.**

- `scenario11AutomaticThreshold29_30_31`: call actual nextStep at 29, 30 and 31 after completed turns, for a page and Contents; no trigger during an unfinished turn. `DATA-MODEL.md:237,348`.
- `scenario11ThresholdCountsOnlyWindowMessages`: exclude carried six, pre-clear and pre-through words, edits, tools, writes, replies' completion records and briefings; P's count does not substitute for Q's. `DATA-MODEL.md:137–138,237`.
- `verificationAutomaticFailureKeepsWindow`: failed/error/all-rejected checkpoint leaves nextStep eligible on the next turn; empty valid checkpoint advances; no false completion or immediate retry loop in the dispatch decision. `DATA-MODEL.md:342`.
- `verificationQueuedMessageAcrossAutomaticCheckpoint`: a message appended after captured through stays in the proper window, is not duplicated as current-turn context and is pending rather than interrupted. `DATA-MODEL.md:336,342`.

**By hand.** Start with the disposable P fixture at 29 messages. Finish the next exchange; inspect a checkpoint after its replied and before the next Sophia user-turn response. Send on Q during it: exactly one Q response follows; both P and Q rebuild on their next send, and no connection-closed error appears. Conversation appearance is continuous with no internal boundary. A failing checkpoint preserves the draft/queued message and the next turn retries; record actual behavior rather than inferring it from core checks.

**Owned live test after S7.** Extend the existing LiveRun with a disposable Fourier notebook and the production nextStep/finishCheckpoint/context code. Drive a substantive DTFT convolution derivation over enough real messages to cross 30 naturally; do not lower the threshold or replace the inquiry with an initialization probe. Include the fixture's earlier swapped-sums attempt and a later open step. Let the automatic decision run the checkpoint, then ask exactly “why is that step valid?” in the rebuilt P conversation.

Record under `impl/qc/S7.md` the actual notebook path, engine/version evidence, message/through/checkpoint IDs, relevant transcript excerpts, supplied context boundaries, emitted tools and timestamps. Evaluate whether the answer correctly justifies the actual open step (including the conditions for exchanging sums when that is the step, not merely a generic theorem recital). Report whether Sophia spontaneously uses `recall`/`read_page` before asking for repetition. Then request one exact older attempt outside the carried six and verify an actual `recall` result returns those words. Distinguish this directed retrieval from spontaneous recall. Record checkpoint elapsed time and delay from the follow-up send to first text and completed answer.

The orchestrator must read the mathematical response and retrieval evidence; an implementer's “passed” is insufficient. Report a wrong/ambiguous next step, lost referent, missing recall or unavailable timing as a failure/inconclusive observation, with the excerpt. Do not tune 30 or introduce provider resumption in response. LiveRun proves the core/engine path; the by-hand observation above separately verifies the app's automatic trigger.

## Gates and completion report

Gate A stops here with this file. No source edit, build, test, model run or slice snapshot has been performed in this reconciliation pass.

After explicit Gate A approval and availability of the requested Opus facility, do S1 and stop at Gate B for Justin's by-hand results and explicit continuation. After Gate B, run S2–S7 sequentially with the same implementer/reviewer/read/run/QC cycle, without another routine approval stop. Stop if a slice remains wrong after two fix rounds, a locked constraint would change, a required capability/check is unavailable, or a storage extension appears necessary.

At Gate C, stop after S7 and report only: implementation by slice with observed check output; exact remaining by-hand observables; untested behavior; any code/specification disagreement; and the owned derivation-test result. A check not run is not passed. No provider-session map or resume experiment is included.
