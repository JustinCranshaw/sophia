# Design decision: data, context and recovery for page-owned chats

*Revised twice after the adversarial review (`adversarial-findings.md`); see "Revision 1" and "Revision 2" in `rounds.md`.*

**Decision:** No new file and no new record type. Everything else the C3 spec shows is derived from the transcript and the files on disk when a thread is shown or a message is dispatched:
- thread membership, the marker, the carried exchanges;
- the pointer and "Started from" cards, the "Elsewhere" line;
- undo, "interrupted", the amber marker, the open-question link.

Sophia's context is always rebuilt from storage when a thread's engine starts. One engine runs per thread touched since the last checkpoint, and one turn at a time across the notebook. No provider session id is stored. A thread-to-session map is deferred behind the sentinel test.

## What is stored, and why

| Stored thing | Where | Requiring scenario | Simpler option rejected |
|---|---|---|---|
| `page` (the entry's thread, by file name) | transcript entries | #s2, #s4, #s5, #s8, #s9, #s11; spec:11 | By position: `send()` appends before queueing (NotebookSession.swift:214-221). Leaving out the third argument: sophia-mcp writes its own entries |
| `page: ""` for new Contents entries | transcript entries | #s10: the cutover that keeps legacy messages from reading as "interrupted" | Absent-only: legacy and new Contents entries would be indistinguishable |
| `clear` | client purpose | #s5, spec:33 | A new `session`: a session is a launch and scopes quotes and the note quota (DATA-MODEL.md:190) |
| `replied` | client purpose | #s10 (spec:65, a cut-off reply) and #s4 (a turn ending on `write_page` is finished) | The last entry's role; "any Sophia entry after M"; an in-memory flag (lost in the crash itself) |
| `hash` on `write_page`, `edit_page`, `undo_page` | transcript entries | #s10, spec:67: a derived Undo must not be offered for overwritten bytes, and a cut-off write must be detectable | File mtime against `at` (`at` is whole seconds, NotebookStore.swift:75) |
| `recovered: true` | flag on a client `write_page` entry, appended on open | #s10 under AGENTS.md's locked "every page write must be recorded and undoable" | Stating an exception (a locked constraint). A new entry kind |

**Struck in revision 2:**
- recording changes made outside the app, and their label;
- the `attempt` duplicate skip;
- the in-memory pointer-card origin.

**Why:** The operator chose page-owned chats for dense technical learning (`qc/gate1.md`). C3 made notes the only compaction and asked C4 for the data contract (`qc/C3.md`).

**Confidence:**
- **Known from source:** the code facts cited were checked by the facilitator.
- **Assumed:** idle `claude` RSS is acceptable. Rebuilt context plus notes carries a derivation forward.
- **Untested:** every live run, the token figures (except SOPHIA.md's size), and orphaned-process behaviour.

**For the operator: what "always reconstruct" means for the person.** Sophia's context is always rebuilt from the notebook files.
- After any quit and relaunch within 6 hours, every thread with exchanges no notes cover shows the amber marker.
- Sophia's first reply there opens with "I couldn't reopen where we left off, so I've picked up from my notes and our last few exchanges here." Today a relaunch shows nothing.
- The notice is true: search results and pages she read before the relaunch are not kept.
- Choosing End session before quitting avoids it.

Marcus's dissent is recorded below.

## The stored fields in detail

### `page`
An entry's thread is `page ?? ""`, and `""` is Contents. Every filter uses that one accessor.

**Stamping rule:**

| Entry | `page` |
|---|---|
| person and Sophia messages, WebSearch, `goal_noted`, `stopped`, `replied`, non-refused `write_page`, `note`, `set_chapter`, `about_you`, `link` | The thread that produced it, never the page on screen. sophia-mcp is launched `sophia-mcp <notebook> <session> <page>`. The one-shot checkpoint/briefing engine gets `""` |
| `edit_page`, `release_edit`, refused `write_page` | their `file` (spec:59) |
| `undo_page` of a revision or edit | its `file` |
| `undo_page` of a new page | the thread of the creating `write_page`, where its card is (the page's own thread no longer has a page) |
| `undo_release` | the released edit's `file` (PageEdits.swift:302) |
| `clear` | the thread cleared |
| `checkpoint`, briefing and `memory` entries | `""` |

**`uniqueFile`.** It (NotebookStore.swift:605-611) skips any name already used as `file` in the transcript, so an undone page's thread is never inherited (#s4, #s11a).

### `clear`
**Order on ⇧⌘N:**
1. Append `clear`.
2. Stop T's engine.
3. Run the checkpoint.

⇧⌘N is disabled while any turn is pending.

**What a clear removes from T's context (N9).** It removes only pre-clear messages a checkpoint has covered, those at or before `through`. Pre-clear messages no checkpoint covers stay word for word until one does. So a failed or cut-off checkpoint after a clear never leaves Sophia with neither the words nor notes. No retry is needed: the next End session, catch-up or 30-message trigger in any thread covers them.

**Where the marker goes.** It sits above the earliest message she has word for word. Until those messages are noted, that can be above the clear divider, so the marker stays true. This is a minimal reading of spec:23, flagged to the operator.

**A message sent while the clear's notes run** is after `clear`. It belongs to the new conversation and waits as pending.

### `replied`
Appended at a conversation turn's successful `.turnDone` in NotebookSession. It is never written for checkpoint or briefing requests.

### `hash`
The SHA-256 of the page bytes the entry leaves on disk. An `undo_page` that removed a new page has none; the expected state is "no file". It is computed inside the lock (NotebookStore.swift:420-437, :472-497; PageEdits.swift:176-185).

**The expected hash.** A file's expected hash is the `hash` on its latest non-refused `write_page`, `edit_page`, `undo_page` or recovered entry. Refused writes never count (Ns-a).

### Write order
- **Revision or edit (unchanged):** copy to `.previous.md`, write the page, append the entry.
- **New page (changed, Ns-b):** write the page file, append the `write_page` entry, then update notebook.json. A crash before the notebook.json write leaves an entry and an unfiled page, which `recoverOrphanPages` lists. This changes DATA-MODEL.md:125's order for new pages only.

### `recovered` (narrowed in revision 2)
`NotebookStore.open` is a new entry point. The app calls it and sophia-mcp does not, so it runs once, under the lock (S-c). It runs `recoverOrphanPages` and then appends `{role: client, tool: "write_page", recovered: true, file, page: file, hash, revised?}` in exactly two cases:

1. **A cut-off revision or edit.** The latest recorded entry for the file has a hash, the page's bytes differ from it, and `.previous.md`'s hash equals it: the app copied first, then the crash cut off the entry (PageEdits.swift:176-178 copies first too). The entry carries `revised: true`.
2. **A cut-off new page.** The page file appears in neither notebook.json nor the transcript.

**Not recorded.**
- **A change made outside the app** (`.previous.md` doesn't match). It isn't an app write, so no scenario needs it. Its hash mismatch already hides any Undo (N2, struck by Marcus).
- **Pages from the proposal era.** They are in notebook.json with no hash, so they are skipped (Ns-b).

**How recovered entries show.** They count for Undo and nothing else: they never count in "Elsewhere" or the pointer card (N3). Their Undo is labelled "Undo the last change".

## Rules derived from what is stored

### Undo
**When a write is undoable.** A `write_page` (including a recovered one) or `edit_page` entry W on file F is undoable when all of these hold:
1. `isLatestWrite(W)` (NotebookStore.swift:455-461);
2. SHA-256(F) equals W.`hash`;
3. for a revision, edit or recovered revision, `.previous.md` exists and its hash differs from F's. For a recovered revision it must also equal the expected hash before the recovery (N2);
4. for a new page, F exists and no person message is tagged F.

Condition 4 is a minimal reading of spec:39, flagged to the operator.

**Releases.** A release is undoable while no later non-refused write, edit or undo on its file exists and no `undo_release` names it.

**What it replaces.** `lastWrites` and `lastReleases` are removed. Record deletion keeps "until the person's next message".

**How undo writes.**
- **Revision undo** uses `replaceItemAt` (#15).
- **New-page undo** writes notebook.json first, then removes the file, then appends `undo_page`. A crash after the notebook.json write leaves the page unfiled, and its Undo is still offered.
- **Limitation:** a crash after the file removal and before the entry leaves the page gone, as asked, with no `undo_page` entry.

### "Interrupted" and pending turns (N1)
**Pending.** A thread has a pending turn while a turn runs in it or a message of it waits in `queued`.

**Interrupted.** A person message M is interrupted when all of these hold:
1. M carries a `page` key;
2. no `replied` or `stopped` in M's thread follows it;
3. M's thread has no pending turn.

**"Ask again"** is shown only for an interrupted message. It is hidden while any turn in that thread is pending. It resends M as a new turn and appends nothing.

**Accepted limitation:** a crash between Sophia's last text and `.turnDone` shows "interrupted".

### Checkpoint
**Scope.** It stays notebook-wide, and `unnotedMessages` and `through` are unchanged.

**The window for thread T and message M:**
- **Word for word:** T's messages after `through`, plus T's pre-clear messages after `through` (N9). All are before M.
- **Carried:** T's last 6 messages at or before `through` and after T's latest clear.
- **Never:** M itself, or anything after it.
- **Markers (Ns-d):** in position, one line for each of T's non-refused `write_page` entries, refused writes and releases. For example: "[Sophia wrote 1.5]", "[revision of §3 refused: protected]", "[the person let you change their line in §3]". Markers are not messages; they don't count toward 30 or amber.

**Failure.** A turn error or an unparsable reply writes nothing (`NotebookStore.finishCheckpoint` returns `.failed`).

**Trigger.** Dispatch calls a pure `NotebookStore.nextStep(thread)`. It returns `.checkpoint` when, after a turn ended in T, T has 30 or more messages in its window. Otherwise it returns `.send`.

**Requests.** The checkpoint request labels each message with its page. It lists every record written since the previous checkpoint entry, of any session, as already noted.

**Accepted limitations:**
- A parsed reply whose records are all rejected moves the marker with `kept: []`, and the reasons are shown (#12). Otherwise the same input would be resent every turn.
- A crash between saving records and the checkpoint entry can repeat records on retry (#11). The duplicate skip was struck as too rarely effective. The person can delete repeats.

### Engines (Devon)
**Engines.**
- `engines[thread]`, each started with `Prompts.context` plus its thread block and no `--resume`.
- Checkpoint and briefing requests use a one-shot engine with thread `""`.
- All engines stop when a checkpoint finishes; T's engine stops on a clear.

**Exits.** `ClaudeEngine.stop()` sets `stopRequested`, and `.exited` carries it. NotebookSession ignores exits that carry it (S-a).

**Turns.**
- One turn runs at a time.
- `canSend` widens.
- `queued` holds an entry id and thread; the prefix is built at dispatch.

**`place`.** A write never changes it: `showWrittenPage` (NotebookSession.swift:334-341).

**`claude_session`** is no longer read or written.

**Tokens** (estimates): a page-thread rebuild is about 8.6k to 13.7k; a Contents rebuild about 7.2k to 12.3k; resume about 8k to 17k.

### Context (Devon)
**Thread start.**
- `Prompts.context` plus the thread line.
- For page f:
  - its body;
  - **Sophia's notes on f:** notes and memory whose `refs` contain `p:f`, or whose `refs` or `quote.entry` name a message tagged f (S-f, N6);
  - carried exchanges, window, markers.
- For a page R created after `through`: also its originating exchange.

**Prefix (`Prompts.turnPrefix`, pure, at dispatch), in this order:**
1. afterQuiet;
2. the amber line (first rebuilt turn only);
3. `bookChanges(cursor(T))`;
4. this-page lines;
5. `elsewhere(T)`;
6. music warnings;
7. selection;
8. text.

**This-page lines (#4, N5).**
- For each non-refused, non-recovered `write_page` to T's file since `cursor(T)` tagged with another thread X: "This page was revised from the conversation on X; call read_page before changing it."
- For each `undo_page` on T's file since `cursor(T)` whose undone entry is a `write_page` (Sophia's or a recovered one), from any thread: "The person undid Sophia's change to this page; call read_page before changing it."
- Undos of the person's edits stay in `bookChanges` (Prompts.swift:210).

**`elsewhere(T)` (N3, N4).** One line per other thread X with person messages, or non-refused non-recovered `write_page` entries, tagged X after `cursor(T)`. It gives the message count, then "Sophia revised <title>" or "Sophia wrote a new page: <title>". It leaves out writes to T's own file, which the this-page line covers. Edits, releases, refusals, undos and recovered writes never make a thread active.

### Quotes and goals (finding 7, N7)
- **Goals:** `writeGoal`'s `refs` cite the latest person message in sophia-mcp's thread.
- **Quotes** in `writeGoal` and `writeNote` match that thread's messages first, then any of this session's person messages (today's rule, NotebookStore.swift:568). R can therefore quote its originating exchange.

### Pointer card (N8, S-g)
The card on arrival and the card kept above the person's message are derived the same way, from person messages only. X is the thread of the person's latest message after T's previous person message, in a thread other than T. For a thread with no person message, that means after the later of `through` and T's latest clear. No arrival origin is held in memory.

**Spec change for the operator.** Spec:10's "arriving from X" becomes "continuing from the conversation you last talked in". A thread touched only by Sophia's writes produces no card; her revision still reaches her through that page's this-page line.

### Amber (Devon; Marcus dissents)
`rebuiltAfterRelaunch(T)` holds when T has a person or Sophia entry with no `purpose` that meets all of these:
- it is tagged T;
- it comes after `through` (or is a pre-clear message after `through`);
- its `session` differs from this launch's.

While it holds, the marker is amber. On the first rebuilt turn, the prefix asks for the spec:66 line.

### Other derived displays
- **"Started from"**, the marker's position and date, "Earlier on this page" and "Go to the open question" are derived as in revision 1.
- **`recall(page:)`** returns messages tagged with the page.
- **Migration** needs no rewrite.
- **Torn lines:** `append` writes a newline first if one is missing (S-e).

## Ambiguities in the C3 spec, with the minimal reading adopted
- **:9:** one turn at a time.
- **:10:** the card names the conversation last talked in (operator flag).
- **:23:** pre-clear messages no notes cover stay word for word, and the marker can sit above the divider until they're noted (operator flag).
- **:29:** 30 or more messages, after a turn.
- **:33:** `clear` is appended before its checkpoint.
- **:39:** a new page's Undo ends at the first message in its thread (operator flag).
- **:45:** the open question comes from the briefing's references.
- **:66:** amber covers a relaunch rebuild.
- **:67:** the hash match and the `.previous.md` conditions.

## Cut or defer
- **Thread-to-provider-session map:** deferred behind the sentinel test and a #s7 loss (S8). Owner: Devon.
- **Not stored:** a cursor, `lastWrites`, a migration step, summary records.
- **No logging** of `read_page` and `recall`.
- **Legacy messages** are not assigned to pages.
- **No overlapping turns.**
- **Not sent:** a revised page's body.
- **Struck in revision 2:**
  - recording outside changes;
  - the duplicate-attempt skip;
  - the in-memory arrival origin.

## Remaining dissent or test
- **Amber after quick relaunches.**
  - Marcus: it shows after every quit and reopen within 6 hours that has unnoted exchanges.
  - Owner: Devon.
  - Test: count such relaunches over a week; if they happen daily, revisit or build S8.
- **Recording outside changes.** Nadia had included them in revision 1, and Marcus struck them in revision 2 because no scenario requires them. A page changed outside the app has no Undo and no record. Owner: Marcus. Reopen if Justin edits pages outside the app.
- **Duplicate-attempt skip.** Nadia accepted it; Marcus struck it as too rarely effective. Owner: Marcus. Reinstate it if the S2 live checkpoint retry shows repeated attempts with identical quotes.
- **Operator flags:**
  - spec:10, the card wording;
  - spec:23, the marker above the divider until notes exist;
  - spec:33, the clear's order;
  - spec:39, a new page's Undo ending at the first message;
  - the PLAN.md:189 reading.
- **Untested:**
  - RSS of idle engines (Devon; check with `ps`);
  - an orphaned `claude` after an app kill (Nadia; by hand);
  - `ClaudeEngine.stop()` reporting `stopRequested` (inferred from Process semantics; S1 case).
- **Accepted limitations:**
  - #11: repeated records after a crash mid-checkpoint;
  - #12: an all-rejected checkpoint moves the marker;
  - #15: a crash inside new-page undo after the removal leaves no `undo_page`;
  - a crash between Sophia's last text and turn end shows "interrupted";
  - legacy notebooks: no Undo after relaunch, no "Started from", recall by words only.
- **Locked constraints:** none changed. `recovered` keeps "every page write recorded and undoable" true for app writes cut off by a crash.
