# C4 adversarial findings

Cold review against scenarios 2, 4, 9 and 10. Sources read, in the brief's order: `briefs/scenarios.md`, `C3/interaction-spec.md` ("spec"), `C4/decision-brief.md` ("DB"), `C4/proposed-edits/*.md` ("DM-edit" = DATA-MODEL.md.md, "ED-edit" = EDITING.md.md), `C4/slices.md`, and the code listed in the brief. All line numbers are from those files as of 2026-10-19. Nothing was run; every finding comes from tracing text and source. **Confirmed** means I traced it to a contradiction, or to a lost, duplicated or misattributed record or context. **Suspected** means it is plausible but depends on implementation the edits leave unspecified.

## Confirmed

### 1. Edit, release, undo and refusal entries land in the wrong thread
- **Scenarios:** 9, 4 (also 8).
- **Severity:** wrong but fixable.
- **Sequence:**
  - DB:23-25 and DM-edit:14 list the entries the app stamps with `page`: messages, `stopped`, `goal_noted`, `clear` and WebSearch. `isPersonMessage` excludes entries with a `purpose` (NotebookStore.swift:190-192).
  - So `edit_page`, `release_edit` (PageEdits.swift:181-185, :302), `undo_page` (NotebookStore.swift:494) and `undo_release` (PageEdits.swift:311) are never stamped. By DB:22 they belong to Contents.
  - Scenario 9: the person clicks Undo on P's banner while in P. "You undid the change to 1.3" (ConversationView.swift:191-194) appears in Contents, not in P.
  - Scenario 8 variant: the edit marker and its Undo also appear in Contents. Spec:59 and ED-edit:29 say they appear in "the edited page's conversation".
  - DB:212 tells "interrupted" to ignore `edit_page` and `release_edit` among T's entries. That assumes they are in T, which they are not.
  - A refused `write_page` is stamped by sophia-mcp with the thread the request came from (DB:24). A revision of P refused while Sophia is talking in Q therefore shows its release card in Q. Spec:59 says "Refusals … appear in the edited page's thread".
- **Evidence to confirm:** a fixture with an untagged `edit_page` on P plus the S1 partition check (case 1) puts the edit in Contents.
- **Minimal fix:** stamp these entries by `file`, or name them in the stamping rule.

### 2. "Interrupted" fires on finished replies and misses cut-off ones
- **Scenarios:** 10, 4.
- **Severity:** wrong but fixable.
- **Rule (DB:211-213):** a message is interrupted if the last T entry before T's next person message is not Sophia's (edits and releases aside).
- **(a) Contents after every checkpoint.** Each checkpoint appends untagged entries, which therefore belong to Contents:
  - the `checkpoint` entry (NotebookSession.swift:295);
  - a `memory` tool entry from `setMemory` (Memory.swift:78);
  - `briefing_dropped` and `briefing_failed` entries.

  The latest Contents person message then reads "Sophia's reply was interrupted · Ask again", although it was answered. "Ask again" resends an answered message.
- **(b) Turns that end in a tool call.** sophia-mcp stamps its entries with T. Prompts.swift:101 tells Sophia not to write again after a tool ("at most add a sentence"), so turns that end on `write_page` or `note` are normal. Scenario 4: P holds m1, then s1, then W_R (page P), and the turn ends. P's m1 shows as interrupted.
- **(c) False negative.** Sophia writes s1 ("I'll put this on a new page"), the app crashes during the `write_page`, and the last P entry is s1. Nothing shows "interrupted", against spec:65. DB:76's check ("P's tail shows interrupted" after a crash between W1's file and its entry) and DM-edit:43 ("its thread shows Sophia's reply as interrupted") are false whenever text preceded the tool call.
- **Evidence to confirm:** an S4 case 1 fixture with a trailing checkpoint entry in Contents, and another whose P tail ends with `write_page`.
- **Minimal fix:** define interrupted by turn completion, not by the role of the last entry.

### 3. Sophia receives the person's message twice when a thread's engine starts
- **Scenarios:** 2, 10.
- **Severity:** wrong but fixable.
- **Sequence:**
  - `send` appends the person entry (NotebookSession.swift:214) before `ensureEngine` (:223).
  - DB:126 and :166 say a new engine starts with "the carried exchanges, then the word-for-word window", which is T's entries after `through`. The window therefore already holds the message.
  - The same text is then sent as the user turn (:225).
  - This happens on every first send after a relaunch or a checkpoint, and always for a queued message. In scenario 2, Q's message is appended while P streams and Q's engine starts only at dispatch (:323-325).
  - The same holds for "Ask again" after relaunch (DB:215): M is in the rebuilt window and is resent.
  - **Variant:** P's turn finishes and fires the 30-entry trigger while Q's message is queued. The checkpoint's `through` then covers Q's message, so it arrives once in Q's carried 6 and again as the message.
- **Evidence to confirm:** S1 case 8's built context for Q, with Q's pending message in the fixture.
- **Minimal fix:** build the window up to, but excluding, the message being sent.

### 4. A revision of page T made from another thread never reaches T's thread
- **Scenario:** 2.
- **Severity:** wrong but fixable.
- **Sequence:**
  - In scenario 2 ("where does the answer go?"), Sophia in P's thread revises Q (W: file Q, page P).
  - Q's engine was started earlier in the sitting, with Q's old body in its system prompt (DB:164).
  - On Q's next turn, `bookChanges` reports only `edit_page`, `release_edit`, `undo_release` and undos of edits (Prompts.swift:197-213).
  - `elsewhere(Q)` lists X=P only for "a `write_page` to X's file" (DB:181), and W is a write to Q's file. Sophia in Q is told "1.3, 1 exchange" and nothing about Q changing.
  - She can now revise Q from the stale body. Person-edit protection doesn't cover Sophia's own text, so the revision made from P's thread is silently replaced. Only the latest write is undoable.
- **Evidence to confirm:** an S6 case 3 variant in which P's thread writes Q; inspect Q's prefix.
- **Minimal fix:** include in T's prefix any write to T's file since `cursor(T)`.

### 5. The "Elsewhere" line misattributes activity
- **Scenarios:** 2, 4.
- **Severity:** wrong but fixable.
- **(a)** In Q's thread Sophia revises P (W: file P, page Q). On Q's next send, `cursor(Q)` falls before W, and X=P qualifies through "a `write_page` to X's file" (DB:181). Sophia hears "Elsewhere since your last turn here: 1.3, 0 exchanges; Sophia revised 1.3", but she made that change herself in Q.
- **(b)** Scenario 4 while the person is in Q:
  - P holds m1, the person's Q message (appended mid-turn, as in finding 3), then W_R (file R, page P).
  - On Q's next turn, P's only person message precedes `cursor(Q)`, so P gets no line.
  - R qualifies through the write to R's file, so the line names "1.5", R's empty thread, and the only verb defined is "revised", for a page that was created.
- **Evidence to confirm:** the `elsewhere(Q)` output on these two fixtures.
- **Minimal fix:** attribute writes by their `page` tag and exclude T's own writes.

### 6. A queued message's prefix is built before the turn it waits on finishes
- **Scenario:** 2.
- **Severity:** wrong but fixable.
- **Sequence:**
  - `outgoing`, including `bookChanges` and the future `elsewhere`, is assembled at send time (NotebookSession.swift:212-213) and stored in `queued` (:218).
  - DB:132 and slices S1 ("`queued` carries its thread") keep that design.
  - In scenario 2 the person sends in Q while P is still streaming, before P's `write_page`. Q's turn is dispatched after P's turn with a prefix that doesn't mention the revision.
  - Q learns about it only on the following turn, as "1.3, 0 exchanges; Sophia revised 1.3", because P's person message precedes `cursor(Q)`.
- **Evidence to confirm:** the S1 live case; print the outgoing text for Q.
- **Minimal fix:** compute the prefix at dispatch.

### 7. A goal recorded in P's turn cites the person's queued message in Q
- **Scenario:** 2.
- **Severity:** wrong but fixable.
- **Sequence:**
  - With `canSend` widened (DB:132), Q's message is appended while P's turn runs.
  - If P's turn then calls `set_goal`, `writeGoal` sets `refs` to the notebook-wide latest person message (NotebookStore.swift:543-547), which is Q's. It also matches `quote` against person messages notebook-wide.
  - The goal's evidence points into a thread where the aim was never discussed.
- **Evidence to confirm:** a fixture with interleaved P and Q messages, then `writeGoal`.
- **Minimal fix:** limit refs and quotes to the calling thread's messages.

### 8. The pointer card cannot stay above the message as spec:10 requires
- **Scenario:** 2.
- **Severity:** wrong but fixable.
- **Sequence:**
  - Spec:10 says that when the person sends in T, the card "stays above that message", and that "nothing is stored".
  - DB:233 says "the thread the person arrived from is held in memory".
  - The person arrives in Q from P, sends, goes to Contents, then returns to Q, or relaunches. The X that the kept card names is gone, so the card disappears or re-derives from the new origin.
- **Evidence to confirm:** an S6 pointer-card case across a relaunch.
- **Minimal fix:** derive the kept card from the entry before the person's message in some other thread, or drop "stays".

### 9. Writing a page can still move the person's conversation
- **Scenario:** 4.
- **Severity:** wrong but fixable.
- **Sequence:**
  - `showWrittenPage` (NotebookSession.swift:334-341) sets `place = .page(file)` in two cases:
    - the default case, which includes a write from the Contents thread;
    - when the book is hidden (`case .page(f) where f != file: if !bookShown`).
  - Because selecting a page now selects its thread (spec:8), the conversation moves to R. Spec:53 says "The conversation stays put".
  - Neither slice S1 nor S6 lists changing this function.
- **Evidence to confirm:** by hand, hide the book on P and have Sophia write R.
- **Minimal fix:** never change `place` on a write.

### 10. Undoing a new page after talking on it hides that conversation
- **Scenarios:** 9, 4.
- **Severity:** wrong but fixable.
- **Sequence:**
  - R's creation stays undoable "until the next write to R … whatever is said in any thread" (spec:39, DB:85-89).
  - The person opens R, talks for an hour (entries tagged R), then clicks R's banner Undo, which is still offered.
  - `undoPageWrite` removes R's file and its notebook.json entry (NotebookStore.swift:483-492), and the person is sent to Contents (NotebookSession.swift:351).
  - R's thread now has no page to select. Its persisted exchanges are shown nowhere, only through `recall(words:)`. This is against spec:64 ("each thread shows exactly what was persisted").
- **Evidence to confirm:** S1 case 7 extended with person messages tagged R before the undo.
- **Minimal fix:** end a new page's undo when its own thread has a person message, or keep showing orphaned threads.

### 11. A crash during a checkpoint duplicates notes
- **Scenario:** 10.
- **Severity:** wrong but fixable.
- **Sequence:**
  - `finishRequest` appends each learning record (NotebookSession.swift:289-290) and sets memory (:293) before the `checkpoint` entry (:295).
  - If the app crashes between them, `through` doesn't move (NotebookStore.swift:201-210).
  - The next checkpoint covers the same messages, with the same `quoteEntries`, so the quotes verify again. That checkpoint can be the 30-entry trigger (DB:115), a clear (DB:51) or the catch-up.
  - RecordChecks has no duplicate check. The duplicated `attempt` and `read` records stand.
  - C4 adds two checkpoint triggers per sitting, which widens this window.
- **Evidence to confirm:** a fixture with notes appended and no checkpoint entry, then run the checkpoint path.
- **Minimal fix:** write the checkpoint entry atomically with its records, or skip records whose `session` and quote already exist.

### 12. A malformed or fully rejected checkpoint still moves the marker
- **Scenario:** 10 (and every automatic checkpoint).
- **Severity:** breaks the design (the marker claims notes that don't exist).
- **Sequence:**
  - DB:115 says "A failed checkpoint writes no entry (NotebookSession.swift:282-283)". That branch handles only a turn error (`failed`).
  - A reply that doesn't parse, or whose records are all rejected, falls through to :286-297. It writes a `checkpoint` entry with `kept: []` and moves `through`.
  - Every engine is then stopped (DB:127). Each thread is rebuilt with only the carried 6, and the words above them have no notes.
  - This contradicts spec:29 ("If notes fail, nothing moves") and the marker's "before this, her notes".
- **Evidence to confirm:** an S7 case 2 fixture with an unparsable reply.
- **Minimal fix:** treat `!parsed` (and perhaps empty `kept` when messages existed) as failed.

### 13. Contents shows amber and Sophia says "I couldn't reopen" when there was nothing to reopen
- **Scenario:** 10.
- **Severity:** wrong but fixable.
- **Sequence:**
  - `rebuiltAfterRelaunch` (DB:188-192) counts any untagged role-`sophia` or role-`person` entry after `through` from an earlier launch.
  - The return briefing qualifies. It is role `sophia`, untagged, and written after the catch-up checkpoint (NotebookSession.swift:313), by a one-shot engine that Contents never had.
  - The person's `edit_page` and `release_edit` entries also qualify (role `person`, untagged; see finding 1).
  - So after a quick relaunch following a briefing or an edit, Contents turns amber, and Sophia's first Contents reply opens with the reconstruction line.
- **Evidence to confirm:** an S4 case 2 fixture containing only a briefing after `through`.
- **Minimal fix:** count only messages (`isPersonMessage`, and Sophia entries without `purpose`) tagged to T.

### 14. A message sent during a clear's checkpoint is hidden above the divider but answered below it
- **Scenario:** 10 (clear boundary).
- **Severity:** wrong but fixable.
- **Sequence:**
  - On ⇧⌘N, DB:51 orders: checkpoint, then `clear`. While the checkpoint runs, `canSend` is true (NotebookSession.swift:194), so the person can type in T.
  - M is appended (tagged T) before the `clear`.
  - M is shown collapsed under "Earlier on this page" (DB:236), and "nothing before the clear is carried or sent" (DB:59).
  - Yet M is dispatched as the first message of the new conversation (:323-325), so Sophia's reply appears below the divider with its question hidden above.
- **Crash variant:** a crash after the checkpoint entry and before `clear` silently drops the clear.
- **Evidence to confirm:** an S2 case: append M between `through` and the clear.
- **Minimal fix:** append `clear` before running the checkpoint, or block sending in T until the clear completes.

### 15. A crash inside Undo leaves a page with no file and nothing to restore it
- **Scenarios:** 10, 9.
- **Severity:** wrong but fixable (pre-existing code that C4 now relies on).
- **Sequence:**
  - `undoPageWrite` removes the page (NotebookStore.swift:480) and then moves `.previous.md` into place (:481).
  - If the app crashes between the two, P is listed in notebook.json with no file, and its text exists only in `.previous.md`.
  - The derived undo's hash check fails, so no Undo is offered. `recoverOrphanPages` skips `.previous.md` (:387).
  - DM-edit:51 claims the checks cover crashes during writes, but not this one.
- **Evidence to confirm:** an S1 crash case with the page deleted and `.previous.md` present.
- **Minimal fix:** use an atomic replace (`replaceItemAt`).

### 16. A page write that the transcript never records contradicts AGENTS.md
- **Scenario:** 10.
- **Severity:** wrong but fixable.
- **Sequence:**
  - DM-edit:43 says "A write cut off before its entry is kept on the page but can't be undone".
  - A new page cut off the same way is recovered as unfiled (NotebookStore.swift:384-393), with no entry, no Undo and no "Started from".
  - AGENTS.md: "Every page write must be recorded and undoable."
- **Evidence to confirm:** S1 case 3 already produces the state.
- **Minimal fix:** record the recovered write on open, or state the exception in AGENTS.md.

### 17. Several slice checks can't exercise the code they gate
- **Scenarios:** all.
- **Severity:** wrong but fixable.
- **Why:**
  - `sophia-checks` depends only on `SophiaCore` (Package.swift), and LiveRun drives `ClaudeEngine` directly (LiveRun.swift:30-42).
  - `NotebookSession`, which holds queuing, `canSend`, `engines`, the clear order, stopping engines, the auto trigger and the once-only amber prefix, is in the `Sophia` app target and can't be imported.
  - `sophia-reader-checks` depends only on `SophiaReader`.
- **Checks that can only pass by reimplementing the logic inside the check:**
  - S1 case 9 ("no session id written by" a checkpoint): no checkpoint runs, so it passes trivially.
  - S1 live case ("the Q message waits").
  - S2 case 3 (failed checkpoint before a clear).
  - S4 case 2 ("prefix line once") and S4's live "quit; relaunch".
  - S7 cases 1-3.
  - S3 ("P's composer receives it quoted").
- **Evidence to confirm:** try writing S7 case 1 in `sophia-checks/main.swift`. It won't compile against `NotebookSession`.
- **Minimal fix:** move the session logic into SophiaCore, or label these as by-hand checks.

### 18. S1 case 8 passes when the thread block is missing
- **Scenario:** 2.
- **Severity:** wrong but fixable.
- **Sequence:** "A string present only in P's thread never appears in Q's built context" also holds if `Prompts.context` omits the window entirely. There is no positive check that Q's own string appears.
- **Evidence to confirm:** read the check.
- **Minimal fix:** also assert that Q's string is present.

### 19. The auto-checkpoint threshold is stated three ways
- **Scenario:** all (S7).
- **Severity:** unclear.
- **The statements:**
  - DB:115: "30 or more".
  - DB:120: "The 31st entry fires the trigger".
  - slices S7 case 1: "The 30th entry triggers".
  - DM-edit:64: "has 30".
- **Evidence to confirm:** the texts disagree as quoted.
- **Minimal fix:** pick one.

## Suspected

### S-a. Exits of stopped engines may reset the live turn
- **Scenario:** 2/10.
- **Severity:** wrong but fixable.
- **Sequence:**
  - DB:127 stops every engine when a checkpoint finishes. `stop()` terminates the process up to 3 s later (ClaudeEngine.swift:104-108).
  - Meanwhile the queued message's new engine is already responding.
  - Today's `.exited` handler isn't specific to an engine. It clears `isResponding`, `streaming` and `queued`, and shows "The connection to Claude Code closed" (NotebookSession.swift:174-185).
  - The edits don't say how events are routed per engine.
- **Evidence to confirm:** a by-hand checkpoint followed by an immediate send.

### S-b. A clear while a reply streams
- **Scenario:** 2/10.
- **Severity:** unclear.
- **Sequence:**
  - `writeNotes` returns false while `isResponding` is true (:256), so "the clear still happens" (DB:53) mid-turn.
  - T's remaining reply entries then land after `clear` and open the "new conversation" without their question.
  - Whether ⇧⌘N is disabled while a reply runs is unspecified.

### S-c. More engine launches widen an unlocked notebook.json race
- **Scenario:** 4/10.
- **Severity:** wrong but fixable.
- **Sequence:**
  - Every sophia-mcp start runs `recoverOrphanPages`, which writes notebook.json without the lock (NotebookStore.swift:40, :384-393).
  - Per-thread engines that restart after each checkpoint mean more sophia-mcp starts.
  - A start that reads notebook.json just before another process writes R's page and files it in Chapter 1 can write back stale metadata. R's chapter filing is lost.

### S-d. The Contents marker is spelled two ways
- **Scenario:** 10.
- **Severity:** unclear.
- **Sequence:**
  - DB:125 keys Contents as `""`, and sophia-mcp takes a third argument.
  - If the Contents engine launches sophia-mcp with `""`, its entries carry `page: ""`, while DB:22 says Contents entries have no `page`.
  - Filters keyed on the field's absence would then drop Contents tool entries.

### S-e. A torn transcript line loses the next entry
- **Scenario:** 10.
- **Severity:** wrong but fixable.
- **Sequence:**
  - A partial last line, with no newline, is followed by `append` writing the next entry onto the same line (NotebookStore.swift:81-90).
  - `readLines` drops the merged line (:68-71), losing a good entry, and `nextID` can reuse its id.
  - This needs a crash part-way through a write, which is unlikely for small appends.

### S-f. A rebuilt page thread may not get its notes
- **Scenario:** 10.
- **Severity:** wrong but fixable.
- **Sequence:**
  - DB:165 gives a page thread only the notes whose refs contain `p:f`.
  - The checkpoint request lists messages with ids but no page (Prompts.swift:142-145), and no slice changes it, so checkpoint notes on P's derivation will mostly cite `t-` ids.
  - After a relaunch, P's rebuild then lacks its notes, while the amber line says "picked up from my notes".
- **Evidence to confirm:** run a live checkpoint on tagged P messages and count `p:` refs.

### S-g. The pointer card on a first visit is undefined
- **Scenario:** 2.
- **Severity:** unclear.
- **Sequence:**
  - For a thread with no turn (Q in scenario 2), "since T's last turn" (spec:10, DB:233) is undefined.
  - Read as "ever", the card appears on every first visit to any page after any activity elsewhere.

## Unrequired additions

None confirmed. Each stored addition (`page`, `clear`, `hash`) traces to a named scenario.

## Second pass

This is a cold re-read of the revised `C4/decision-brief.md` ("DB2"), `C4/proposed-edits/*.md` ("DM2" = DATA-MODEL.md.md) and `C4/slices.md` ("SL2"). The C3 spec is unchanged. Line numbers are from the revised files. As before, I read no rounds.md or qc/ file and ran nothing.

### Status of the original 19

| # | Status | Why |
|---|---|---|
| 1 | Resolved | DB2:40-49 stamps edit, release, refusal and undo entries by `file`. One residue: undoing a new page tags the `undo_page` line to R's thread, which no longer exists, so that line is shown nowhere. |
| 2 | Resolved | The `replied` entry (DB2:91-101, :158-172); the crash between the last text and turn end is an accepted limitation. It introduces N1. |
| 3 | Resolved | DB2:180-182 and SL2 S1 case 9. |
| 4 | Resolved for writes from other threads (DB2:250-252). | An undo of a page's own-thread revision is still unreported (N5). |
| 5 | Partly | Attribution now follows the page tag (DB2:254), but recovered writes and non-message entries now produce "Elsewhere" lines (N3, N4). |
| 6 | Resolved | DB2:210: the prefix is built at dispatch. |
| 7 | Resolved | DB2:288. It introduces N7. |
| 8 | Partly | The kept card is now derived from storage (DB2:293), but it can name a thread the person didn't come from, or a recovered write (N8). |
| 9 | Resolved | DB2:212; checked only by hand (SL2:85). |
| 10 | Resolved | DB2:140-142, condition 4. |
| 11 | Partly | Only an `attempt` whose quote entry *and text* are identical is skipped (DB2:188). A retried model call rarely repeats its read text word for word; reads and other kinds are an accepted limitation (DB2:190). |
| 12 | Partly | Unparsable replies now fail (DB2:184), but a reply whose records are all rejected still moves the marker with `kept: []`, as an accepted limitation (DB2:186). |
| 13 | Resolved | DB2:263-269. |
| 14 | Resolved | DB2:73-80. It introduces N9. |
| 15 | Partly | Revision undo now uses `replaceItemAt` (DB2:148). Undo of a *new* page still removes the file before notebook.json (NotebookStore.swift:483-492), so a crash in between leaves a listed page with no file. Recovery checks only files that exist (DB2:115). |
| 16 | Partly | Recovered writes are now recorded and undoable (DB2:114-125), but Undo of one recorded after an outside change restores the wrong version (N2). |
| 17 | Partly | The derivations move into SophiaCore and are checkable. The `NotebookSession` wiring has no check at all, by hand or otherwise (N10). |
| 18 | Resolved | SL2 S1 case 9 asserts that Q's own string is present. |
| 19 | Resolved | One threshold: 30 or more (DB2:192; SL2 S7 case 1). |

### New confirmed findings

#### N1. A queued message shows "interrupted · Ask again" while it waits
- **Scenarios:** 2 (also the return catch-up).
- **Severity:** wrong but fixable.
- **Sequence:**
  1. P streams. The person sends M in Q; it is appended, tagged Q, and waits (DB2:209-210).
  2. The interrupted rule (DB2:159-162) holds for M: it has a `page` key, no `replied` or `stopped` in Q follows it, and no turn is *running* in Q (a queued turn is not running).
  3. So Q shows "Sophia's reply was interrupted · Ask again" for as long as P streams. The same happens to a message typed during catch-up notes, which app/README.md:62 says "waits for the notes".
  4. "Ask again" resends M through a new turn (DB2:166) while M is still queued. M is then answered twice, or the resend jumps the one-turn-at-a-time queue.
- **Evidence to confirm:** an `isInterrupted` fixture with M appended in Q and no running turn in Q.
- **Minimal fix:** treat a queued message as running.

#### N2. Undo of a recovered write after an outside change restores the version before the last recorded write
- **Scenario:** 10.
- **Severity:** wrong but fixable (it loses text).
- **Sequence:**
  1. Sophia revises P (W0). `.previous.md` holds the bytes from before W0, and the page holds W0's bytes (NotebookStore.swift:422-425).
  2. P is changed outside the app. DB2:125 says recovery "also records a page changed outside the app".
  3. On open, a recovered entry `{revised, hash(X)}` is appended (DB2:115-119), and it is undoable: its hash matches, and `.previous.md` exists and differs (DB2:136-139).
  4. "Undo the last change" (DB2:123) puts back the bytes from before W0. W0's text now exists nowhere on disk.
- **Unaffected case:** a crash after W1's page write is handled correctly, because `.previous.md` was copied first.
- **Evidence to confirm:** an S1 case: W0, then overwrite the file, reopen and undo; the page equals the bytes from before W0, not W0's.
- **Minimal fix:** don't offer Undo on a recovered write unless `.previous.md`'s hash equals the expected hash of the latest recorded entry.

#### N3. Recovered writes are reported as Sophia's revisions and steer the pointer card
- **Scenarios:** 10, 2.
- **Severity:** wrong but fixable.
- **Sequence:**
  - A recovered entry is `tool: "write_page"`, non-refused, with `page: <file>` (DB2:117).
  - `elsewhere(T)` emits "Sophia revised <title>" for every non-refused `write_page` tagged X (DB2:254).
  - The kept pointer card's X is "the thread of the latest person message or `write_page` before M tagged other than T" (DB2:293).
  - So after a crash and relaunch, the first message in Q tells Sophia "Elsewhere since your last turn here: 1.3, 0 exchanges; Sophia revised 1.3". The kept card reads "Continuing from 1.3" although the person came from somewhere else.
  - DB2:121 says such a write's author is unknown.
- **Evidence to confirm:** `elsewhere(Q)` and `pointer(for:)` on a fixture holding one recovered entry.
- **Minimal fix:** exclude `recovered` entries from both.

#### N4. "Elsewhere" counts threads that had no conversation
- **Scenario:** 2.
- **Severity:** wrong but fixable.
- **Sequence:**
  - `elsewhere(T)` lists "every other thread X with entries tagged X after `cursor(T)`" (DB2:254).
  - Edits, releases, refusals, undos and recovered writes are now tagged with their page (DB2:45-47).
  - So if the person edits a line on Q while talking in P, P's next prefix carries both the hunk (bookChanges) and "1.4, 0 exchanges".
  - A refused write to P requested from Q makes P count as "active" for every other thread.
  - Spec:25 asks for one line per other thread *active*, meaning talked in.
- **Evidence to confirm:** an `elsewhere(P)` fixture whose only Q entry is an `edit_page`.
- **Minimal fix:** count only messages and non-refused, non-recovered writes.

#### N5. An undo of Sophia's own revision isn't reported to that thread
- **Scenario:** 9.
- **Severity:** wrong but fixable.
- **Sequence:**
  1. In P's thread Sophia revises P (W0, tagged P).
  2. The person goes to Q and talks. Later, still in the same sitting, they click "Undo Sophia's change" on P's banner. The new rule allows this indefinitely (DB2:136-140).
  3. They return to P and send.
  4. P's engine is still alive and believes W0 stands, and nothing in the prefix says otherwise:
     - the this-page line covers only writes "tagged with another thread X" and their undos (DB2:251-252);
     - `bookChanges` reports undos only of the person's edits (Prompts.swift:210).
  5. Her next revision of P can silently restore W0's text.
- **Change from the old rule:** before, Undo ended at the next message, so it could only happen just before the message that followed it. It can now be separated from that message by any amount of activity.
- **Evidence to confirm:** a `turnPrefix(P)` fixture holding W0 (tagged P) and an `undo_page` of W0.
- **Minimal fix:** report every `undo_page` on T's file since `cursor(T)`.

#### N6. The page-notes rule misses quote-only attempts
- **Scenario:** 10 (a rebuild after relaunch).
- **Severity:** wrong but fixable.
- **Sequence:**
  - A page's notes are those whose `refs` contain `p:f`, or a `t-` id tagged f (DB2:233).
  - An `attempt` needs only a verified `quote` (DATA-MODEL.md:154). `writeNote` stores the message id in `quote.entry`, not in `refs` (NotebookStore.swift:567-571).
  - So the record of the person's swapped-sums attempt on P, with an empty or page-free `refs`, is not given to P's rebuilt thread. That is exactly the material the amber line says she "picked up from my notes".
- **Evidence to confirm:** a context fixture with an attempt whose `quote.entry` is a P message and whose `refs` is empty.
- **Minimal fix:** match `quote.entry` as well as `refs`.

#### N7. A thread-scoped quote can't cite R's originating exchange
- **Scenario:** 4.
- **Severity:** wrong but fixable.
- **Sequence:**
  - R's context carries its originating exchange word for word, and those messages are tagged P (DB2:235).
  - `writeNote` now matches a quote "by session and thread" (DB2:288; DM2:76).
  - When Sophia, in R, notes an attempt quoting the person's question from that exchange, the store finds no match in R's thread. The quote is dropped and the record becomes a paraphrase or is rejected.
- **Evidence to confirm:** `writeNote` from thread R quoting the originating P message.
- **Minimal fix:** allow quotes from R's originating exchange, or from the session.

#### N8. The kept pointer card can name a thread the person didn't come from
- **Scenario:** 2.
- **Severity:** wrong but fixable.
- **Sequence:**
  1. The person talks in P, then goes to Contents, then from Contents to Q. Spec:10's on-arrival card is computed against X = Contents, which has no activity, so no card shows.
  2. They send M in Q.
  3. The derived kept card (DB2:293) picks "the latest person message or `write_page` before M tagged other than T". That is P's message, which is after Q's previous person message.
  4. A "Continuing from 1.3" card now appears above M that was never shown on arrival.
- **Evidence to confirm:** a `pointer(for:)` fixture with P activity, an arrival from Contents, then M in Q.
- **Minimal fix:** store nothing, but derive the card from the person's last *message* before M in another thread only (not writes), and show the same derivation on arrival.

#### N9. A clear whose checkpoint fails or is cut off leaves Sophia with neither the words nor notes, and says nothing
- **Scenario:** 10 (clear boundary).
- **Severity:** unclear.
- **Sequence:**
  1. ⇧⌘N appends `clear`, then runs the checkpoint (DB2:73-76).
  2. If the checkpoint fails (DB2:184), or the app crashes before it runs, T's pre-clear messages are unnoted and excluded from T's context (DB2:180-181).
  3. The retry comes only from End session, a return after 6 h, or another thread reaching 30. T now has 0 messages, so T's own trigger can't fire (DB2:192).
  4. `rebuiltAfterRelaunch(T)` needs a message after the clear (DB2:263-267), so there is no amber and no notice.
  5. The person asked to keep what she learned (#s5), and for that period she has none of it.
- **Evidence to confirm:** fixture: messages in T, then `clear`, then no checkpoint entry; build T's context.
- **Minimal fix:** retry a pending clear's checkpoint on T's next dispatch.

#### N10. The NotebookSession wiring has no check
- **Scenarios:** 10, 2 (slices).
- **Severity:** wrong but fixable.
- **Sequence:**
  - SL2:16 says what stays in NotebookSession "is checked by hand and labelled so". The only by-hand items are SL2:84-85 (S1), :128 (S3), :158 (S4) and :179 (S5).
  - Nothing checks that:
    - `replied` is appended at a successful `.turnDone` (SL2:56);
    - `recoverUnrecordedWrites` and `recoverOrphanPages` are called when the app opens a notebook (SL2:38; S1 case 3 calls them directly);
    - `shouldCheckpoint` is called and the checkpoint runs before the next dispatch (S7);
    - a stopped engine's `.exited` is ignored (SL2:55);
    - ⇧⌘N is disabled during a turn.
  - Consequence: S4 case 1 passes on fixtures while the app never writes `replied`. In that build, every message in the app would read "interrupted".
- **Evidence to confirm:** remove the `replied` append; `swift run sophia-checks` still passes.
- **Minimal fix:** add by-hand or live steps for each of these.

### New suspected

- **Ns-a. A refusal may disable recovery (scenario 10).**
  - Expected bytes come from "the latest `write_page`, `edit_page`, `undo_page` or recovered entry" (DB2:106; DM2:58), and pages "whose latest entry has no hash are skipped".
  - Refused `write_page` entries carry no hash. If they count as "latest", then a refusal followed by a write that a crash cut off before its entry goes unrecorded and un-undoable.
- **Ns-b. Proposal-era pages may get a deleting Undo (scenario 10, legacy).**
  - Pages accepted from proposals may have no `write_page` entry, and the legacy fixture's decision entries carry no `file` (sophia-checks/main.swift:381-391).
  - If so, the first open writes a recovered *new-page* entry for each one (DB2:115, "no entry at all"). Condition 4 holds because legacy messages are untagged, so "Undo the last change" deletes the page.
  - This contradicts DB2:123 ("Legacy pages … are skipped").
- **Ns-c. The duplicate skip may be too narrow to work (scenario 10).**
  - DB2:188 says "quote entry and text equal". If "text" means Sophia's read rather than the quote, a retried checkpoint will rarely match.
  - SL2 S2 case 5 passes with an identical fixture text either way.
- **Ns-d. Rebuilt context drops tool events (scenarios 4, 10).**
  - A rebuilt window contains only messages (DB2:180), so `write_page` cards, refusals and releases from before `cursor(T)` aren't in it.
  - After a relaunch, Sophia in P may not know she created R, or that her change to the person's line was refused and then released, unless her text said so.

## Third pass

This is a cold re-read of the final `C4/decision-brief.md` ("DB3"), `C4/proposed-edits/*.md` ("DM3" = DATA-MODEL.md.md) and `C4/slices.md` ("SL3"). The C3 spec is unchanged. Line numbers are from the final files. As before, I read no rounds.md or qc/ file and ran nothing.

### Status of N1–N10 and the partly resolved originals

| Item | Status | Why |
|---|---|---|
| N1 | Resolved | A queued message counts as pending, and "Ask again" is hidden while a turn is pending (DB3:120-128; SL3 S4 case 1; S1 by-hand 3). |
| N2 | Resolved | A change made outside the app is no longer recorded (DB3:91-95). A recovered revision is undoable only when `.previous.md` matches the hash recorded before it (DB3:106; SL3 S1 case 4). |
| N3 | Resolved | Recovered writes never count in "Elsewhere" or the pointer card (DB3:98, :194). |
| N4 | Resolved | Only person messages and real writes make a thread active (DB3:194; SL3 S6 case 4). |
| N5 | Resolved | Any undo of a `write_page` on T's file is reported to T (DB3:191; SL3 S1 case 13). |
| N6 | Resolved | `quote.entry` now counts (DB3:175). |
| N7 | Resolved | Quotes match the thread first, then the session (DB3:198; SL3 S1 case 14). |
| N8 | Accepted, stated honestly | The card is derived the same way before and after sending, from person messages only (DB3:200-203). This changes spec:10's wording, and that is flagged to the operator. |
| N9 | Resolved for Sophia's context | Pre-clear messages no checkpoint has covered stay word for word (DB3:70). The divider text now disagrees with her context (T1). |
| N10 | Resolved | Each piece of NotebookSession wiring has a by-hand step with an exact observable (SL3:19, S1 by-hand 1-5, S2 by-hand 1-2, S4 by-hand 1-3, S7 by-hand). S4 is gated on `replied` being written (SL3:139). |
| #5 | Resolved | Same as N3 and N4. |
| #8 | Accepted, stated honestly | Same as N8. |
| #11 | Accepted, stated honestly | Records can repeat after a crash mid-checkpoint, and the person can delete them (DB3:149, :260). |
| #12 | Accepted, stated honestly | An all-rejected checkpoint moves the marker, and the reasons are shown (DB3:148, :261). |
| #15 | Resolved, with a stated limitation | Revision undo is atomic. New-page undo now writes notebook.json, then removes the file, so a page can no longer be listed with no file. A crash after the removal leaves no `undo_page` entry; that is stated (DB3:115-118, :262). |
| #16 | Resolved for app writes | A write cut off by a crash is recorded and undoable. Changes made outside the app are explicitly out of scope (DB3:94-95, :247). See T2 for one ordering error in the text. |
| #17 | Resolved | Decisions are now SophiaCore functions. The wiring is checked by hand (SL3:11-21). |

### New problems that break the design

#### T1. After a clear whose notes failed or were cut off, the divider says something Sophia's context contradicts (confirmed)
- **Scenario:** 10, at the clear boundary.
- **Sequence:**
  1. ⇧⌘N appends `clear` (DB3:63-66) and draws spec:33's divider: "New conversation · Sophia has your words from here on · before this, her notes ›".
  2. The checkpoint then fails, or the app quits before it ends.
  3. DB3:70 and DM3:28 keep T's unnoted pre-clear messages word for word, and DB3:72 puts the marker *above* the divider.
  4. Those same messages are collapsed under "Earlier on this page" (DM3:39: "A thread's entries before its latest `clear`").
- **What the person sees:** two dividers making opposite claims. The clear divider says her words start below it; the marker says they start above it.
- **What Sophia receives:** the collapsed exchange, word for word. S2 by-hand 2 expects exactly this: "Sophia's reply shows she still has the pre-clear exchange".
- **What it contradicts:**
  - spec:23 ("After a clear, nothing before the clear is carried");
  - spec:33 ("That thread's context becomes page, notes and memory").

  DB3:222 flags the spec:23 reading to the operator, but nothing reconciles the divider text or the collapse.
- **Evidence to confirm:** S2 new case 2 plus the S2 snapshot of that fixture.
- **Minimal fix:** in that state, either show the clear divider without "Sophia has your words from here on" and keep the pre-clear messages expanded, or keep the checkpoint's failure from completing the clear.

#### T2. As written, recovery never records a new page that a crash cut off (confirmed; text order)
- **Scenario:** 10.
- **Sequence:**
  - `NotebookStore.open` "runs `recoverOrphanPages` and then appends" a recovered entry. Case 2 is "the page file appears in neither notebook.json nor the transcript" (DB3:89-92; the same order at DM3:61-63).
  - The new-page write order is file, then entry, then notebook.json (DB3:86). A crash after the file write leaves a page file with no entry and no listing.
  - `recoverOrphanPages` runs first and adds that file to notebook.json (NotebookStore.swift:384-393).
  - So case 2's condition is false by the time it is checked. The page is listed unfiled with no record and no Undo.
- **What it contradicts:** AGENTS.md's "every page write must be recorded and undoable", which `recovered` exists to satisfy (DB3:21, :265).
- **Evidence to confirm:** SL3 S1 case 6 ("A new page file with no entry and not in notebook.json: `open` records a recovered new page") fails if `open` is implemented in the stated order.
- **Minimal fix:** evaluate case 2 against notebook.json as it was before `recoverOrphanPages` ran, or apply the two steps in the opposite order.

No other new problem rises to "breaks the design". Lower-severity items were not recorded, as the brief asked.
