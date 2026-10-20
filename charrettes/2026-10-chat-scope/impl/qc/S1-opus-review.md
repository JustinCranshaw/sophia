I found no blocking defect in the S1 foundations. Engine identity and queueing, write and recovery order, the one-way latest-action rule, and checkpoint validation before saving all match the spec. I found two Medium-High and two Medium source defects, plus four Low ones.

This review is source inspection only, of the diff and the current files around it. I ran no build, check, live run or app session. I have not read `impl/qc/S1.md`, `lead-findings.md` or any implementer report.

## Findings

**F1 · Medium-High: one release click on a refusal naming several edits can only be partly undone**
- **Where:** `PageEdits.swift:299-309` writes one `release_edit` entry per edit. `NotebookStore.swift:587-589` (`isReleaseUndoable`) only accepts the latest page action. `NotebookSession.swift:381-387` and `ConversationView.swift:376-380` undo whatever is still undoable.
- **Trigger:**
  1. Sophia's revision of P drops lines from two separate person edits, e1 and e2, so the refusal's `edits` is `[e1, e2]`.
  2. The person clicks "Let Sophia change this", which writes r1(e1) and then r2(e2).
  3. They then click Undo on the banner or the card. Only r2 is latest, so only `undo_release(r2)` is written.
- **Consequence:** e1 stays released. The latest action is now an `undo_release`, so no further Undo is offered. The card goes back to "Let Sophia change this", which would release e2 again. Sophia's next message only says permission for e2 was taken back, so she can still rewrite e1's lines after the person tried to withdraw permission.
- **Why it's new:** before S1, `lastReleases` undid every release from the click.
- **Spec:** EDITING.md:56 (the release "can be undone while it is the latest change"); DATA-MODEL.md:155, 167, 345.
- **Smallest fix:** treat the releases written by one `releaseEdits` call as one action. While that group is the trailing run of page actions, `isReleaseUndoable` should accept each of them, and `undoRelease` should write `undo_release` for each one under the lock. This needs no schema change.

**F2 · Medium-High: the first turn in any thread replays the whole notebook's change history**
- **Where:** `Prompts.swift:153-157`. With no earlier person message in the thread, `previous = -1`, so `bookChanges(since: 0)` and the "This page changed" / "Another conversation was active" loops scan the entire transcript.
- **Trigger:** the Fourier fixture after S1 lands. All 240 old entries have no `page`, so they count as Contents. The first send on P (scenario 1) then reports:
  - every `edit_page`, release and undo the notebook has ever had, under "Since your last reply, the person changed the book themselves";
  - every old write to P as "[Sophia app] This page changed: Saved … (revision)", because its thread is Contents, not P;
  - "Another conversation was active: Contents".
- **Consequence:** Sophia is told weeks-old changes are new. SOPHIA.md:84 tells her to re-read pages she has been told were revised, so she does unneeded `read_page` calls and may comment on old edits. This happens once per page thread, including every never-discussed page (scenario 11).
- **Spec:** DATA-MODEL.md:282-285 ("since her last turn in that thread"); slices-applied S6 ("cursor on first turn follows the stored through boundary").
- **Smallest fix:** when the thread has no earlier person message, start the scan at `max(clearPosition, cursor) + 1` for that thread instead of 0. The test `scenario2PageContextAndBookChanges` (`main.swift:780`) currently passes only because of this unbounded scan. Give Q an earlier turn in that test.

**F3 · Medium: sending in another thread during a reply can lose `goal_noted` and the book reveal**
- **Where:** `NotebookSession.swift:150-158` takes its "before" snapshot of `store.pageWrites` and `store.learning` when the tool result arrives, from the app's copy in memory. `send()` at `NotebookSession.swift:194` goes through `appendTranscript` and `locked`, which re-reads all files.
- **Trigger:**
  1. P is running, and Sophia calls `set_goal` (or `write_page`).
  2. The MCP process saves it.
  3. Before the tool result reaches the app, the person sends on Q. Scenario 2 is exactly this; an edit commit or confirming a goal does the same.
  4. The snapshot taken at the tool result already contains the new goal or write.
- **Consequence:** no `goal_noted` entry is written in P, so the goal card is missing from P's conversation. A hidden book is not revealed for a new page.
- **Why it matters for S1:** the race existed before, but S1 makes sending during another thread's reply a normal flow.
- **Spec:** DATA-MODEL.md:115, 127; PLAN.md:222, 224.
- **Smallest fix:** take the snapshot at `.toolUse`, keyed by the tool-use id. For pages, `pageWrite(toolUse:)` already exists.

**F4 · Medium: live notes now accept quotes from earlier sessions**
- **Where:** `NotebookStore.swift:698-701, 717`. `quoteEntries` is every entry in the thread from any session, plus this session's entries. The lookup also prefers an older-session match in the thread over a match in another thread from this session.
- **Trigger:** on Contents (where all old entries now land) or on P, Sophia calls `note` with words from a message in an earlier launch. The quote is kept as verified.
- **Consequence:** this goes against DATA-MODEL.md:330 ("comes from an earlier session, is removed") and the function's own unchanged comment at `NotebookStore.swift:691-692, 697`. It also reopens the "deleted attempt recreated" path that DATA-MODEL.md:261 closes.
- **Caveat:** DATA-MODEL.md:227 ("first in this conversation, then anywhere in this session") can be read either way, so the orchestrator should confirm the intent.
- **Smallest fix:** limit both the lookup and `quoteEntries` to `session == session`, searching this thread first and then the rest of the session.

**F5 · Low: the context text still says a written page appears beside the conversation**
- **Where:** `Prompts.swift:102`: "`write_page` saves a page … the person sees it beside the conversation."
- **Spec:** SOPHIA.md:66 and PLAN.md:224 now say the selection doesn't change and the person opens the page from the card. qc/review.md D1 flagged exactly this phrase.
- **Consequence:** Sophia may tell the person that a new page R is beside them while they are still looking at P.
- **Fix:** reword the sentence to "the person can open it from the conversation; where they are doesn't change."

**F6 · Low: a reply in another thread scrolls the visible conversation to the bottom**
- **Where:** `ConversationView.swift:45`, `.onChange(of: session.store.transcript.count)`.
- **Trigger:** P streams while the person reads earlier messages in Q. Every P text block, `replied` entry or tool entry jumps Q to the bottom.
- **Spec:** PLAN.md:232 ("Preserve … scroll position").
- **Fix:** key the change on `items.count` for the active thread.

**F7 · Low: queued work can get stuck**
- **Where:** `NotebookSession.swift:122-129` (the API-key billing guard) and `:205` (engine start failure).
- **Behavior:**
  - The billing guard clears `running` and `request` but never runs `dispatchNext` and leaves the queue in place. Queued threads stay blocked (`canSend` is false) until a send somewhere else retries, and that retry hits the guard again.
  - When an engine fails to start, the next queued turn is not tried either.
- **Fix:** on the billing guard, drop queued turns from dispatch; their person entries are already stored. On a start failure, keep draining the queue.

**F8 · Low: what some new checks claim versus what they test**
- `verificationInterleavedThreadOwnership` (`main.swift:619`): the WebSearch, `goal_noted`, `set_chapter`, `about_you`, `link`, `stopped` and `replied` cases only show that `appendTranscript` keeps a `page` the caller supplies. The real stamping happens in NotebookSession and sophia-mcp, which these checks can't reach. Label the check that way, and don't cite it as evidence of how those writers stamp threads.
- `verificationUndoAcrossScopesAndReopen` does not cover undoing a person's edit across threads and reopen.
- `verificationAtomicUndoAndNewPageCutoff` (`main.swift:712`) only checks states after an undo, not the moment before the atomic replace.
- The existing check that changed (`orphanPageIsListedAfterACrash`, now using `open`) is not weaker.

**Not a defect:** Contents is named "Contents" (`NotebookSession.swift:29`), where PLAN.md:224's example is "Fourier analysis · notebook conversation". The visible label is the operator's call.

## Validation still open (none observed by me)

- I did not run any command. The orchestrator's reported passes (the build, 51 checks, and `--live`) say nothing about native behavior.
- Native focus, draft and caret when a write reveals the hidden book (WKWebView insertion), scroll behavior, and how Stop, the queue and "Finish for now" behave with real processes are all untested. These are Gate B items 2, 3 and 6.
- What Claude Code does with `--tools ""` plus `--disallowedTools` for the read-only checkpoint process is unverified at runtime.
- A real crash during write, recovery or undo is represented only by synthetic file states, not observed.
- The `replied` wiring and the cross-thread routing in NotebookSession are covered by no automated check; they are by-hand items 1 and 2.
- Billing attribution is inconclusive.
