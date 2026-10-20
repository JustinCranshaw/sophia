# Implementation slices: page-owned chats

*Revised twice after the adversarial review. Revision 2 adds a by-hand step for every piece of NotebookSession wiring (N10) and moves three decisions into SophiaCore.*

**Superseded in part by operator gate 2 (2026-10-19).** Read `qc/gate2.md` before implementing: the clear waits for its notes, there is no amber state, marker, subtitle, ⌘L or pointer card, and undo has one rule. The applied docs, not these slices, are the specification where they differ.

The order is Marcus's. Commands are only those in `app/README.md`:
- `swift run sophia-checks`, plus its `--live <dir>` mode;
- `swift run sophia-reader-checks`;
- `scripts/make-app.sh`;
- the `SOPHIA_SNAPSHOT*`, `SOPHIA_LIBRARY` and `SOPHIA_RETURN_GAP` variables.

**What can be checked where.** `sophia-checks` depends only on `SophiaCore` (app/Package.swift), so every decision a check must exercise lives in SophiaCore as plain functions:
- **Derivations on `NotebookStore`:** `thread(of:)`, `window(for:before:)`, `carried(for:before:)`, `cursor(for:before:)`, `isPending`/`isInterrupted(_:queued:running:)`, `rebuiltAfterRelaunch(_:session:)`, `elsewhere(for:before:)`, `pointer(for:)`, `isUndoable(_:)`, `isReleaseUndoable(_:)`.
- **`NotebookStore.open(url:)`:** the app's only way to open a notebook. It runs `recoverOrphanPages` and the recovered-write step under the lock. sophia-mcp keeps the plain init.
- **`NotebookStore.nextStep(thread:)`:** returns `.checkpoint` or `.send`; dispatch calls it.
- **`NotebookStore.finishCheckpoint(...)`:** returns `.failed` or `.saved`.
- **`Prompts.turnPrefix(...)`:** pure.
- **`ClaudeEngine.stop()`:** sets `stopRequested`, which `.exited` carries.

What remains in NotebookSession is only wiring: calling these at the right moment, appending `replied`, ignoring an exit that carries `stopRequested`, and the ⇧⌘N enablement. Each piece has a **by-hand** step below with an exact observable. No case passes without exercising the code it names.

"New case" means a function in `app/Sources/sophia-checks/main.swift`, run by `swift run sophia-checks`. "Live case" means an addition to `app/Sources/sophia-checks/LiveRun.swift`, run by `swift run sophia-checks --live <empty-dir>`. LiveRun drives `ClaudeEngine` directly, so it cannot observe NotebookSession. "By hand" means `scripts/make-app.sh debug`, then `SOPHIA_LIBRARY=<disposable library> build/Sophia.app/Contents/MacOS/Sophia`, then reading the notebook's `transcript.jsonl` where a step says so.

Every slice ends with `scripts/make-app.sh debug` building and `swift run sophia-checks` passing, including all earlier cases. Each slice updates `app/README.md` "What this version does".

## S1: Page threads, usable on their own

**Delivers.**
- Each page and the Contents has its own conversation.
- Undo is per page and survives switching, relaunch and crashes during writes.
- Sophia gets the page, her notes on it and the thread's words.
- Writing a page never moves the conversation.

**Files.**
- `SophiaCore/NotebookStore.swift`:
  - `page` stamping;
  - `hash` on write, edit and undo;
  - new-page write order (file, entry, notebook.json);
  - new-page undo order (notebook.json, file, entry);
  - `replaceItemAt`;
  - `uniqueFile`;
  - the `append` newline;
  - `open(url:)` with both recoveries;
  - `writeGoal`/`writeNote` thread-then-session quotes;
  - derivations, `finishCheckpoint`.
- `SophiaCore/PageEdits.swift`: `page` and `hash` on edit, release and undo-release entries.
- `SophiaCore/ClaudeEngine.swift`: `Config.page`; sophia-mcp args `[notebook, session, page]`; events carry the thread; `stop()` sets `stopRequested`.
- `sophia-mcp/main.swift`: third argument; no recovery.
- `SophiaCore/Prompts.swift`:
  - `context` thread block (body; notes by `p:f`, refs or `quote.entry` tagged f; carried; window with markers; originating exchange);
  - `turnPrefix` with this-page lines;
  - `checkpoint` labels pages and lists records since the previous checkpoint.
- `Sophia/NotebookSession.swift`:
  - `NotebookStore.open`;
  - `engines[thread]` and the one-shot engine;
  - ignore exits with `stopRequested`;
  - `replied` at `.turnDone`;
  - `canSend` widened, `queued` holds an id and thread, `nextStep` before dispatch;
  - remove `lastWrites`/`lastReleases` and `claude_session`;
  - `showWrittenPage` never changes `place`.
- `Sophia/ConversationView.swift` and `Sophia/BookView.swift`: thread filter; `isUndoable`.

**New cases.**
1. Partition by thread. Untagged entries and `""` are Contents. An edit on P, a refused write to P from Q, and the undo of a P revision land in P. The undo of a new page R created from P lands in P.
2. P's write stays undoable after a message in Q and a reopen via `open(url:)` (#s9).
3. A revision W1 with the copy and the page file written but no entry; `open(url:)`. One recovered entry, undoable, which restores W0's bytes. W0 is not undoable. A second `open` adds nothing.
4. The page overwritten outside the app (`.previous.md` is untouched): `open(url:)` records nothing, and no Undo is offered (N2).
5. A copy to `.previous.md` without the write: no Undo for W0.
6. A new page file with no entry and not in notebook.json: `open` records a recovered new page. A new page with an entry but not in notebook.json: `open` lists it unfiled and records nothing.
7. A proposal-era fixture (sophia-checks/main.swift:381-391): `open` records nothing (Ns-b).
8. An undo, then a write cut off before its entry: recovered.
9. New-page undo cut after the notebook.json write: page unfiled, Undo still offered.
10. R plus a person message tagged R: R's Undo is gone. An undone file name is not reused.
11. Q's built context before M contains Q's earlier string, not P's string, and not M (findings 3, 18). It contains a marker line for a refused write in Q.
12. A message between `through` and the checkpoint entry is in the window.
13. `turnPrefix(Q)` reports P's edit as a hunk. It reports a revision of Q from P. It reports the undo of Sophia's own revision of Q made in Q (N5).
14. A goal from P's tool server cites P's message. A note in R quoting R's originating P message keeps its quote (N7).
15. A torn last line doesn't swallow the next entry.
16. A `ClaudeEngine` with `claudePath` `/usr/bin/true`: after `stop()`, `.exited` carries `stopRequested == true`; without `stop()`, false. Inferred from Process semantics; this case confirms it.

**Live case.** LiveRun with `Config.page = P` revises P; the `write_page` entry has `page: P` and `hash`.

**By hand (each gates S1):**
1. **`replied`.** Send one message on P and wait for the reply. `transcript.jsonl` has exactly one `"purpose":"replied"` line with `"page":"<P file>"` after Sophia's entry. Quit and relaunch: P shows no "interrupted".
2. **Recovery on open.** Quit; with a text editor, write new bytes to P's page file and copy the old page to `.previous.md`. That reproduces a cut-off write; doing only the overwrite reproduces an outside change. Relaunch: in the first case, `transcript.jsonl` ends with one `"recovered":true` line and P's banner offers "Undo the last change"; in the second, nothing is added and no Undo shows.
3. **Queue.** In #s2, send in Q while P streams: Q shows the message with no "interrupted", it is answered after P's reply, and the answer is in Q.
4. **Stopped engines.** Click End session, then send at once: no "The connection to Claude Code closed" appears, and the reply arrives.
5. **`place`.** Hide the book on P and have Sophia write R: the window stays on P.

**Command.** `swift run sophia-checks`; `swift run sophia-checks --live <empty-dir>`; by hand.

## S2: Clear, the marker, recall by page, and checkpoint failure

**Delivers.**
- ⇧⌘N (append `clear`, stop T's engine, checkpoint), disabled while a turn is pending.
- "Earlier on this page", the carried 6, the marker.
- `recall(page:)`.

**Files.**
- `Sophia/NotebookSession.swift`.
- `SophiaCore/NotebookStore.swift`.
- `SophiaCore/Memory.swift`.
- `Sophia/ConversationView.swift`.

**New cases.**
1. Pre-clear messages at or before `through` are neither carried nor sent.
2. Pre-clear messages after `through` (no checkpoint since) stay in the window, and the marker sits above them (N9).
3. A message appended after `clear` while its checkpoint is pending is in the new conversation.
4. `finishCheckpoint` with an unparsable reply, or with a turn error, writes nothing; the window is unchanged.
5. A parsed reply with every record rejected is saved with `kept: []` (accepted limitation).
6. `recall(page:words:)` returns the tagged message only.

**Live case.** C3 decision-brief:48 on a tagged fixture: Sophia brings back the earlier 2.2 exchange with `recall`.

**By hand.**
1. While Sophia streams, ⇧⌘N is greyed and the key does nothing. `transcript.jsonl` gets no `clear` during the turn.
2. Press ⇧⌘N, quit before the notes finish, and relaunch. Send in T: Sophia's reply shows she still has the pre-clear exchange.

**Snapshot.** `SOPHIA_SNAPSHOT=/tmp/shots SOPHIA_LIBRARY=<fixture library> build/Sophia.app/Contents/MacOS/Sophia`.

**Command.** `swift run sophia-checks`; `--live <empty-dir>`; by hand.

## S3: "Ask Sophia about this"

**Delivers.** The selection on P goes to P's thread, quoted (#s1). This is UI only.

**Files.**
- `SophiaReader/MarkdownReader.swift` and its `Reader` scripts.
- `Sophia/BookView.swift`.
- `Sophia/NotebookSession.swift`.

**New reader case.** A selection posts its text and section through the message handler.

**By hand.** Select a sentence on P and choose "Ask Sophia about this": P's composer holds the quote, and the sent message is tagged P.

**Commands.** `swift run sophia-reader-checks`; by hand.

## S4: Interrupted, Ask again, and amber after relaunch

**Gated on** S1 by-hand step 1 (`replied` is written). Without it, these cases prove nothing about the app.

**Files.**
- `SophiaCore/NotebookStore.swift`.
- `SophiaCore/Prompts.swift`.
- `Sophia/NotebookSession.swift`.
- `Sophia/ConversationView.swift`.

**New cases.**
1. `isInterrupted`:
   - a turn ending on `write_page` plus `replied`: no;
   - text with no `replied`: yes;
   - a Contents message followed by checkpoint, memory and `replied`: no;
   - legacy: no;
   - a message that is queued or has a turn running: no (N1).
2. `rebuiltAfterRelaunch`:
   - an earlier-session message after `through`: true;
   - a briefing or edit alone: false;
   - the message before `through`: false.
3. `turnPrefix(firstRebuiltTurn:)` adds the spec:66 instruction only when true.

**Live case.** A search turn in engine A. A fresh engine B with the rebuilt context and `turnPrefix(firstRebuiltTurn: true)`: B opens with the spec:66 line.

**By hand.**
1. Send on P and force-quit (⌥⌘Esc) while the reply streams. Relaunch: P shows "Sophia's reply was interrupted · Ask again", and the marker is amber.
2. Click Ask again: exactly one new reply; `transcript.jsonl` gains no new person entry.
3. Send again: the "couldn't reopen" line does not repeat.

**Command.** `swift run sophia-checks`; `--live <empty-dir>`; by hand.

## S5: Briefing in Contents and the open question

**Delivers.**
- The briefing in Contents.
- "Go to the open question ⇧⌘J".
- The ring.
- The banner (#s7, #s7b).

**Files.**
- `Sophia/NotebookSession.swift`.
- `Sophia/ConversationView.swift`.
- `Sophia/BookView.swift`.
- `Sophia/SidebarView.swift`.
- `SophiaCore/NotebookStore.swift`.

**New case.** The open-question derivation.

**By hand.** Launch with `SOPHIA_RETURN_GAP=1 SOPHIA_LIBRARY=<disposable library>`. The briefing shows in Contents, and ⇧⌘J opens the question highlighted.

**Command.** `swift run sophia-checks`; by hand.

## S6: Cards and the Elsewhere line

**Delivers.**
- Write cards and the target dot.
- "Started from".
- The derived pointer card.
- `elsewhere(T)`.

**Files.**
- `Sophia/ConversationView.swift`.
- `Sophia/SidebarView.swift`.
- `SophiaCore/NotebookStore.swift`.
- `SophiaCore/Prompts.swift`.

**New cases.**
1. "Started from" quotes the creating exchange.
2. R carries it until the next checkpoint.
3. In #s4, `elsewhere(Q)` names P with "Sophia wrote a new page: 1.5" and never R.
4. Q's own write to P is not elsewhere. An edit, refusal, undo or recovered write alone never makes a thread active (N3, N4).
5. The pointer card for M in Q, after the person talked in P and then passed through Contents, names P both on arrival and kept. It still does after a reopen. A thread touched only by Sophia's writes gives no card (N8).
6. With no person message in the thread, the card counts from `through`.

**Live case.** #s4: R's first turn has the originating exchange.

**By hand.** Talk in P, open Q, send: the "Continuing from 1.3" card shows before and after sending.

**Command.** `swift run sophia-checks`; `--live <empty-dir>`; by hand.

## S7: Automatic checkpoint (one threshold)

**Delivers.** `nextStep(thread:)` returns `.checkpoint` when, after a turn ended in T, T has 30 or more messages in its window.

**Files.**
- `Sophia/NotebookSession.swift`.
- `SophiaCore/NotebookStore.swift`.

**New cases.**
1. `nextStep` at 29, 30 and 31 messages.
2. After a failed `finishCheckpoint`, `nextStep` still returns `.checkpoint`.
3. Markers don't count toward the 30.

**Live case.** A checkpoint request on 30 messages; LiveRun prints the latency.

**By hand.** A disposable library with T at 29 messages. Send once. In `transcript.jsonl`, a `checkpoint` entry appears before the next Sophia entry in T.

**Command.** `swift run sophia-checks`; `--live <empty-dir>`; by hand.

## S8 (gated): Thread-to-provider-session map

**Build only if both hold:**
- the sentinel live cases show fresh context reaching a resumed session and a bad id failing detectably;
- a `--live` #s7 quit-and-relaunch loses the swapped-sums step.

**Delivers.**
- `claude_sessions` in notebook.json.
- Resume-failure detection, feeding the S4 amber path.

**Live cases** (added whether or not S8 is built):
1. A sentinel in `--append-system-prompt`.
2. A changed `--system-prompt`.
3. A fake id.

**Command.** `swift run sophia-checks --live <empty-dir>`.
