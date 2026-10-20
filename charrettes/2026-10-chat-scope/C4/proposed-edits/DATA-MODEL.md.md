# Proposed edits: DATA-MODEL.md

Review only; the real file is unchanged. Revised twice after the adversarial review. Each block names the section it replaces. Line numbers refer to DATA-MODEL.md as of 2026-10-19. Sections not listed are unchanged. The file list in "The files" is unchanged: no file is added.

---

## Replace: "### The conversation log: transcript.jsonl" (lines 109-119, the entry list)

### The conversation log: transcript.jsonl

Every entry: `{ "id", "at", "role": "person" | "sophia" | "tool" | "client", ... }`.

- Messages carry `text`, and each belongs to a session (`session`), one app launch.
- **Threads.** Each page has one conversation thread, and so does the notebook's Contents. An entry's `page` names its thread by the page's file name; `""` means Contents. An entry with no `page` was written before threads existed and also belongs to Contents. Entries take their thread as follows:
  - Messages, WebSearch, `goal_noted`, `stopped`, `replied` and the tool server's entries take the conversation they came from, not the page on screen. A reply that finishes after the person moves on stays where it began. The tool server is launched for one thread and stamps that thread on what it writes.
  - Entries that act on a page take that page: an edit, a release, a refused write, an undo of a revision or edit, and an undo of a release (which takes the edited page). An undo of a new page takes the conversation where the page was written, since the page itself is gone.
  - Checkpoint, briefing and memory entries belong to Contents.

  A file name never changes once used: a revision keeps its file whatever the title becomes, moving a page between chapters changes only notebook.json, and a new page never reuses a file name already in the transcript.
- A page write is a `tool` entry: `{ "tool": "write_page", "file", "title", "revised"?: true, "tool_use", "hash", "page" }`. `file` is the page written. `page` is the thread the request came from, which may be another page (scenario 4). `hash` is the SHA-256 of the page's bytes as written.
- **A recovered write** is `{ "role": "client", "tool": "write_page", "recovered": true, "file", "page": <file>, "hash", "revised"?: true }`. The app writes it on opening a notebook for a write that a crash cut off before its entry, in two cases:
  - a page whose bytes don't match the latest recorded hash while `.previous.md` does (the copy was made, then the crash came);
  - a page file listed in neither notebook.json nor the transcript.

  A change made outside the app is not recorded, and offers no Undo. A recovered write counts only for Undo: it is never reported as Sophia's revision or as activity in a conversation. The author is unknown, so it is a client entry.
- An undo is a `client` entry: `{ "purpose": "undo_page", "entry": "t-0042", "file", "page", "hash"? }`. `hash` is the SHA-256 of the restored page; there is none when the undo removed a new page.
- When Sophia records a goal, the app adds `{ "role": "client", "purpose": "goal_noted", "record": "g-3", "page" }` so the conversation shows it where it happened.
- **Clearing a thread.** `{ "role": "client", "purpose": "clear", "page" }`. The app writes it first, then runs a checkpoint. Messages before it that a checkpoint has covered are not sent to Sophia again. Messages before it that no checkpoint has covered yet (because the notes failed or the app quit first) stay with her word for word until one does, so a clear never loses what Sophia learned.
- **A finished reply.** `{ "role": "client", "purpose": "replied", "page" }`, written when Sophia's turn in that thread ends normally.
- The person's edit to a page (EDITING.md) is `{ "role": "person", "purpose": "edit_page", "file", "page": <file>, "title", "section", "index"?, "hunks": [{ "before", "after" }], "hash" }`.
  - `section` is the section's title, `"(opening)"` for the text before the first section, or `"(page)"` for the whole body; `index` is the section's position.
  - Hunks are whole changed lines, joined with newlines.
  - An edit is not a message: it is never quoted, checkpointed, or treated as evidence of understanding.
- A refused `write_page` is `{ "role": "tool", "tool": "write_page", "refused": true, "reason": "open" | "protected" | "quote", "file", "page": <file>, "section", "current", "edits", "edit"?, "why"? }`. Nothing on the page changed; `current` is the section's text that was kept.
- `{ "role": "person", "purpose": "release_edit", "entry": <edit_page id>, "page" }` lets Sophia change that edit's lines; `{ "role": "client", "purpose": "undo_release", "entry": <release id>, "page" }` takes it back.

**What a thread shows and what Sophia receives.** Nothing below is stored; each is worked out from the entries above when the thread is shown or a message is sent. A thread's "messages" are its person and Sophia entries without a `purpose`.
- **The marker.** Sophia has a thread's messages from just after the latest checkpoint's `through`. That is counted from the position of `through`, not of the checkpoint entry, because a message sent while notes were being written falls between the two. Above that point she has her notes. She also gets the thread's last 6 messages at or before `through` (the carried exchanges), but none from before the thread's latest `clear`. The message being answered is not repeated in the context; it arrives as the turn itself. The marker sits above the earliest message she has word for word, which can be above a clear until its messages are noted. Her context also shows, where they happened, one line for each page write, refused write and release in the thread; these are not messages.
- **Earlier on this page.** A thread's entries before its latest `clear`.
- **"Started from."** A new page's card comes from the `write_page` entry that created it. Its `page` names the thread, the person's message before it in that thread is the question, and the first Sophia message after that is her first line.
- **"Interrupted."** A person message that carries a `page` is interrupted when no `replied` or `stopped` in its thread follows it, and nothing is pending there: no reply running and no message waiting its turn. "Ask again" resends the text and stores nothing new. A crash after Sophia's last words but before her turn ended also shows as interrupted.

---

## Replace: "**The person's edits.**" paragraph, last sentence (line 121)

> A saved edit keeps the previous version and can be undone like a page write; only the latest write to a page, by either author, can be undone.

becomes

> A saved edit keeps the previous version and can be undone like a page write, by the rule below.

---

## Replace: the write-order paragraph (line 125)

A page write saves in a fixed order. Each entry records the page's `hash`:
- **A revision:** copy the current version to `.previous.md`, write the page file, then append the transcript entry.
- **A new page:** write the page file, append the transcript entry, then add the page to notebook.json.

**On opening a notebook,** the app, holding the notebook lock:
- lists any page file missing from notebook.json as unfiled;
- records a recovered write when a crash cut one off before its entry.

A crash part-way through a write therefore loses no text, and the write it cut off is recorded and can be undone. Changes made to a page outside the app are not recorded and can't be undone. Pages whose latest entry predates `hash` are left as they are.

**Undo.** Undo restores `.previous.md` for a revision or an edit, replacing the page in one step. For a new page, it removes the page from notebook.json and then deletes the file. A write can be undone until the next write to that page, by either author, whatever is said in any thread. Nothing records that a write is undoable; it is worked out from what is stored, so it survives relaunch.

A write is undoable when all of these hold:
- it is the latest non-refused write, edit or undo for its file;
- the page's current bytes still match its `hash`;
- for a revision or edit, `.previous.md` exists and differs from the page;
- for a recovered revision, `.previous.md` also matches the last version recorded before it;
- for a new page, the page exists and nobody has talked in its conversation yet.

Why each condition is there:
- The hash check stops a crash between a page write and its entry from making an earlier write look undoable.
- The `.previous.md` check stops a crash between the copy and the write from offering an Undo that would change nothing.
- The last condition keeps a page's conversation from being left with no page to show it beside.

If the app quits after deleting a new page's file but before recording the undo, the page is gone as asked, and nothing records it. Entries written before `hash` existed offer no Undo after a relaunch.

A release (below) can be undone until the next write, edit or undo on that page.

---

## Replace: in "3. **Sophia writes notes in three ways**", the "During the conversation" bullet "The store finds the person's message in this session that a quote comes from." (line 185)

     - The store finds the person's message that a quote comes from: first in this conversation, then anywhere in this session. A goal Sophia records cites the latest message in the conversation she is answering.

---

## Replace: "**Checkpoint scope:**" through "**Coming back**" bullets (lines 190-193)

   - **Checkpoint scope:** a checkpoint covers the person's messages since the previous checkpoint, in every thread and across sessions. A session is one app launch, and one sitting can span several.
   - **When it runs:**
     - at End session;
     - after a clear;
     - when the person comes back to a notebook whose last messages have no notes, before the briefing;
     - after a turn ends in a thread that then has 30 or more messages after the latest `through` and its latest clear.
   - **How it runs:** in its own short-lived conversation process, never in a thread's. Its entries belong to the Contents thread. It is not limited by the `note` quota.
   - **What it is shown:** the request lists each message with its page, and every record written since the previous checkpoint entry, whatever the session, as already noted. A crash between saving a checkpoint's records and its entry can still leave repeated records, which the person can delete.
   - **If it fails:** a checkpoint fails when the request ends in an error or the reply can't be read. Then it writes no records, no memory and no entry, so nothing moves, and the next turn tries again.

     A reply that is read but whose records the checks all reject still counts: it is recorded with nothing kept and the reasons shown.
   - **The checkpoint's transcript entry** names the last message it covered in `through` and marks `catch_up` when it ran on return. Messages a checkpoint covered are never offered to a later one. Every thread's word-for-word view starts just after `through`.
   - **Coming back** means the latest message by the person or Sophia in any thread (a briefing counts) is at least 6 hours old. A shorter gap gets neither catch-up notes nor a briefing. The briefing belongs to the Contents thread.

---

## Replace: "### Deletion and undo" (lines 208-210)

### Deletion and undo

The person can delete any learning record. The client removes the record and every record whose `replaces` chain leads to it, then rewrites learning.jsonl atomically. Undo holds the removed records in memory until the person's next message, in any thread. The conversation itself still contains the words, and the app says so. Because checkpoint quotes must come from the session being summarized, a deleted attempt cannot be recreated by a later checkpoint.

Page writes and edits are undone by the rule in "The conversation log", not this one.

---

## Replace: "### How each side reads the state back" (lines 212-215; retires the draft-proposal model)

### How each side reads the state back

- **The person** sees each page's thread beside the page. They also see:
  - after each session, one line such as "Sophia noted 3 attempts · Review" (counted from that session's records);
  - goals with their criteria, evidence, Sophia's dated reads and their own takes;
  - notes with quote, read and correction, and one next step.

  "Show record" exposes any raw entry.
- **Sophia**, when a thread's conversation starts, receives:
  - the goals, About you, her memory, other notebooks by title, and the page list;
  - for a page thread:
    - that page's body;
    - her notes that cite the page or a message in its thread;
    - if the page was written from another conversation since the last checkpoint, that exchange;
  - the thread's carried exchanges and its later messages, word for word.

  Other pages come through `read_page`, and older exchanges through `recall`.
- **With each message**, the app sends Sophia:
  - the page edits, releases and undos since her last turn in that thread;
  - a line if her page was revised from another conversation, or a change of hers to it was undone;
  - one line per other thread active since then.

  She never gets another thread's words.

  The briefing she writes must reference the records it rests on, so the person can follow every claim to its evidence and correct it.

---

## Add to "## Why each retained part is needed" (after line 227)

The existing bullets stay. The two on proposals and Accept order describe the retired draft model; removing them is a separate cleanup, not part of this change. Add:

- **`page` on transcript entries, stamped where each entry is written:** needed so each page's thread shows only its own conversation, refusals and edit markers (scenarios 2, 8, 9, 11), and so a page Sophia writes from another page's thread names where it started (scenario 4). Two simpler options were rejected:
  - Assigning entries by position fails: a message sent in one thread while Sophia answers in another lands among her later entries.
  - A file per thread was rejected because the transcript already orders everything.

  A missing `page` means Contents, so older notebooks need no migration.
- **The `clear` entry:** needed so a fresh start on a page keeps its history and notes (scenario 5). A new session was rejected: a session is an app launch, and quotes and the note quota depend on it.
- **The `replied` entry:** needed so a reply cut off by a crash shows as interrupted (scenario 10), while a turn that ends in a page write does not (scenario 4). Two simpler options were rejected:
  - Judging by the last entry's author fails both cases, and also when checkpoint entries follow a message.
  - Keeping it in memory loses it in exactly the crash.
- **`hash` on page writes, edits and undos:** needed so Undo, now worked out from records and kept across relaunch, can't be offered for a write a crash has already overwritten, and so a cut-off write can be found (scenario 10). Cost: one SHA-256 per write. Rejected: file modification times, which have seconds resolution and are changed by other programs.
- **Recovered writes:** needed so every page write is recorded and undoable even when a crash cut off its entry (AGENTS.md; scenario 10). It is a flag on the existing page-write entry, not a new kind. Two options were rejected:
  - Stating an exception was rejected because the rule is a fixed boundary.
  - Recording changes made outside the app was dropped, because no scenario needs it.
- **No stored provider session, cursor, or undo state:** Sophia's context is rebuilt from these records whenever a thread's conversation starts, so storage stays independent of provider sessions. A map from threads to provider sessions waits on the test in PLAN.md §4.

---

## Replace: "## Deferred until triggered", second bullet (line 253)

- Undo of a record deletion that survives a restart: add if Justin needs to undo a deletion after reopening the app. (Page undo already survives restart; see "The conversation log".)
- A map from threads to provider sessions in notebook.json: add only if all of these are shown:
  - a resumed session receives fresh context;
  - a bad session id fails detectably;
  - a rebuilt thread loses a step a resumed one kept (PLAN.md §4).

---

## Add to "## Verification" (after line 246)

- Entries from two threads, interleaved, are shown each in their own thread. Entries with `page: ""` or no `page` show in Contents. An edit, a refusal and an undo show in the page they act on.
- A message sent while notes are being written stays in its thread's word-for-word view, and the message being answered is not also in the context.
- P's Undo is still offered after a message in Q and after reopening. In each of these cases the crashed state is handled correctly:
  - **write cut off before its entry:** recorded as recovered and undoable, and the earlier write is not; a page changed outside the app is not recorded and offers no Undo;
  - **cut off after the copy to `.previous.md`:** no Undo;
  - **undo cut off:** the page is replaced in one step, so it never goes missing.
- A new page's Undo ends once the person has talked in its conversation.
- A turn ending in a page write is not interrupted; one cut off after Sophia's text but during a tool call is.
- A checkpoint reply that can't be read writes nothing. A queued message is never shown as interrupted.
- After a clear, nothing noted before it is carried, and anything not yet noted stays word for word. A message sent while the clear's notes are written belongs to the new conversation. An undone new page's file name is not reused.
