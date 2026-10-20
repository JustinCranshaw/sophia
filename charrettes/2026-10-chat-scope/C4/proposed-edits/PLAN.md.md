# Proposed edits: PLAN.md

Review only; the real file is unchanged. Revised after the adversarial review. Line numbers refer to PLAN.md as of 2026-10-19.

---

## Replace: the "Restart" row of "### Acceptance checks" (line 161)

| Restart | Kill and relaunch the client with several page threads live. Each thread shows exactly what was stored, without duplicates; a reply cut off shows as interrupted. Each thread's context is rebuilt from storage, and a thread that had unnoted exchanges from before the relaunch says it was reconstructed. Produce an accurate return briefing |

---

## Replace: "## 4. Notebook tools, saving, and return", the paragraph beginning "[DATA-MODEL.md](DATA-MODEL.md) defines these files" (line 185), last two sentences

> … The client requests a short checkpoint at session end and records it as Sophia's account, not an objective measure of the person.

becomes

> Each page, and the notebook's Contents, has its own conversation thread. These threads are kept in the one transcript, each entry tagged with its page. The client requests a short checkpoint at session end, after a clear, and when a thread grows long. It records the checkpoint as Sophia's account, not an objective measure of the person. The checkpoint's notes are the only compaction: no summary is stored.

---

## Replace: "## 4. Notebook tools, saving, and return", the paragraph beginning "For the return briefing" (line 189)

For the return briefing, supply a bounded selection of recent inquiry/learning records and saved pages. Sophia should ground her account in those records and invite correction.

**Rebuilding context.** Sophia's context for a thread is rebuilt from storage whenever that thread's conversation starts:
- her standing context;
- the page;
- her notes on it;
- the thread's last few exchanges before the latest notes, and everything since, word for word.

A checkpoint ends every thread's provider session, so her view always matches the marker the person sees.

**Saying so.** Provider sessions are not stored or resumed. After a relaunch, a thread that had exchanges no notes cover says, once, that it was reconstructed. Its live session may have held search results or pages read that storage does not keep. Never claim to restore private provider state that Sophia does not possess.

**Deferred: resuming provider sessions.** Resuming a thread's provider session is deferred behind one test, run with the app's exact flags:
1. Resume with a changed `--append-system-prompt` containing a sentinel word, and ask Sophia to quote it.
2. Resume with a changed `--system-prompt`.
3. Resume with an id that does not exist.

Store a map from threads to provider sessions in notebook.json only if both of these hold:
- fresh context reaches the resumed session and the bad id fails detectably;
- a rebuilt thread is shown to lose a step that a resumed one kept.

---

## Replace: "## 5. Native application after the experiment", the paragraph beginning "The book and the conversation are separate surfaces" (line 203), first three sentences

> The book and the conversation are separate surfaces. Before a notebook has a page, the conversation fills the window. Once it has one, the window shows the notebook's single running conversation in the middle and the book (chapters and read-only pages) on the right; …

becomes

> The book and the conversation are separate surfaces. Before a notebook has a page, the Contents conversation fills the window. Once it has one, selecting a page shows the page and that page's own conversation together. Selecting the Contents shows the notebook-level conversation. Chapters, Goals and Sophia's notes have no conversation of their own. A reply finishes in its own thread if the person moves to another page. …

(The rest of the paragraph is unchanged.)
