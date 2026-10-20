# Interaction spec: page-owned chats

Prototype: `mock/chat-scope/chosen.html`. These rules govern.

## Threads, switching, history

- Every page (including the Reading list) and the Contents row has exactly one thread; a new page starts empty. Chapters, Goals and Sophia's notes have none.
- Selecting a page shows its page and its thread together.
- A reply streaming when the person leaves finishes in its thread; that row gets a blue dot.
- **Pointer card.** Arriving in thread T from thread X (sidebar, ⌘[ / ⌘], a link) adds one card at the end of T if, since T's last turn, the person sent a message in X or Sophia wrote X's page. Lines: "Continuing from X · <time>"; "Your last message there: …" (if any); "Sophia revised X while you were away · undo is on X" (undo clause only while it holds); "Back to X ⌘[". It is derived from the transcript at display time; nothing is stored. If the person sends in T, it stays above that message; if they leave without sending, it is dropped. Sophia never receives it.
- Messages stay in the one transcript, tagged with `page`; no file is added.
- History: conversations before a clear sit collapsed above the current one ("Earlier on this page"), readable in place.
- Shortcuts: ⇧⌘N new conversation on this page; ⌘[ / ⌘] back, forward; ⇧⌘J go to the open question; ⌘L (View ▸ Show What Sophia Has) opens the marker; ⌘E, ⌘↩, Esc as EDITING.md.

## What Sophia receives

At thread start and after any rebuild:
1. standing context (`Prompts.context`: goals, About you, memory, other notebooks by title, page list);
2. this page's body (Contents: none);
3. her notes that reference this page (Contents: none beyond memory);
4. word for word, the thread's **carried exchanges** and everything after its latest checkpoint.

The **carried exchanges** are this thread's last 3 exchanges (6 entries) before the latest checkpoint. Checkpoints are notebook-wide. After a clear, nothing before the clear is carried.

With each message: edits, releases and undos to any page since this thread's last turn (`bookChanges`, keyed per thread), and one line per other thread active since then: "Elsewhere since your last turn here: 1.3, 2 exchanges; Sophia revised 1.3." Another thread's words never arrive; Sophia uses `recall` when asked.

## Managing context within a thread

- **Default, when the person does nothing.** Besides End session and the return catch-up, a checkpoint runs automatically when the thread the person is sending in reaches 30 entries since its latest notes (the carried 6 not counted), between turns, never mid-reply. It covers the whole notebook, moving every marker. A thread thus holds at most about 36 entries word for word. If notes fail, nothing moves: unnoted messages wait, a clear still happens, the trigger retries next turn.
- **Compaction is the checkpoint.** Sophia writes the notes under DATA-MODEL.md's existing checks; no summary record, file or count cap. The live `note` quota (8 per session) does not limit checkpoints.
- **Every checkpoint drops the provider session in every thread;** each thread's next turn is rebuilt from storage. Resume is used only within a sitting before the next checkpoint, so the marker tells the truth.
- **The marker.** One hairline divider, drawn above the carried exchanges: "Sophia has your words from here on · before this, her notes ›", dated by the latest notes. Opening it (click or ⌘L) shows "Her notes from Oct 16 · she works from these for everything above the line" and the notes, linked to their sources. Messages above it stay readable, dimmed. Its moves are not announced. Every thread's header subtitle reads "Her notes, then your words since Oct 14" (the first word-for-word entry).
- **Clearing (⇧⌘N, or "New" in the header).** First runs the checkpoint, then writes a `clear` entry tagged with the page and shows "New conversation · Sophia has your words from here on · before this, her notes ›". That thread's context becomes page, notes and memory. Storage keeps everything; the old conversation collapses under "Earlier on this page".
- **Shaping.** The person clears, or asks her to note something, put it on the page, or `recall` an older exchange.
- The person never sees the words "checkpoint", "session", "context" or "token".

## Undo

A write to page P stays undoable until the next write to P by either author, whatever is said in any thread. P's banner offers "Undo Sophia's change" or "Undo your edit", "until the next change to this page". P's revision card keeps its Undo while that holds; a message in another thread does not end it (#s9). The pointer card carries no Undo button.

## Checkpoints, End session, return

One checkpoint covers every unnoted person message in all threads. End session runs it once; on return (6 h gap) the catch-up runs it once, then the briefing.

The briefing (at most two sentences) appears in the Contents thread, where the person lands. Its link, "Go to the open question ⇧⌘J", opens that page's thread at Sophia's unanswered question, highlighted; the page's sidebar row carries a ring. Opening another page first shows it as a one-line banner above the book, with the link, until dismissed (#s7b).

## Ask Sophia about this

The selection on page P goes to P's thread, quoted; P's thread is always the one showing.

## Writes to another page from a thread

The conversation stays put. The thread shows Sophia's card ("Sophia revised 1.4" or "Sophia wrote a new page: 1.5 … · Open"); the target row gets a dot; Undo lives on the target's banner.

A new page R's thread opens with a pointer card, "Started from a conversation on 1.3 · Oct 17", derived from the `write_page` entry that created R and kept permanently. It quotes the person's question and Sophia's first line, with "Back to 1.3 ⌘[". R's context carries that exchange word for word until the next checkpoint (#s4).

## Editing (EDITING.md protections unchanged)

Refusals ("open", "protected"), the edit marker and the release card appear in the edited page's thread. The hunk reaches each thread's next turn through `bookChanges`. "Let Sophia change this" is undoable until the next change to that page, replacing EDITING.md's "until the next message" (#s8).

## Resume failure and crash recovery

Person-visible rules (C4 owns the data):
- Each thread shows exactly what was persisted, nothing duplicated.
- A reply cut off by the crash shows "Sophia's reply was interrupted · Ask again".
- If resuming a thread's provider session fails, its next turn is rebuilt; the thread opens on the marker, now amber, and Sophia's first line says: "I couldn't reopen where we left off, so I've picked up from my notes and our last few exchanges here." Threads that resumed show nothing.
- A page's Undo survives relaunch if its previous version is on disk; otherwise none is shown (#s10).

## Cuts

"Work from here" and per-exchange keep/exclude (clear, note it, or put it on the page); meters, counts, `/compact`; summary records or files; the 40-entry cap; resume across checkpoints; a second thread per page (#s6: asides go inline); chapter threads; visible authorship tags (EDITING.md Phase 3).
