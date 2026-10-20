# Stage 0 brief: grounding (read-only, not a charrette)

You are writing a grounding brief for a design process about how Sophia's conversations relate to the notebook. Today a notebook has one conversation beside the book; the operator is considering per-page chats and a notebook-level chat, and either one clearable session per scope or several named threads. Your job is only to describe how things work now and what the reference tools do. Do not propose a design.

Project root: `/Users/justincranshaw/Projects/sophia`. Read `AGENTS.md` there first.

## Output

Write `/Users/justincranshaw/Projects/sophia/charrettes/2026-10-chat-scope/briefs/grounding.md`. At most 900 words. Every claim about the code or the docs carries a citation in the form `path:line` (for example `app/Sources/Sophia/NotebookSession.swift:214`). A statement about the code with no citation will be rejected. Use relative paths from the project root.

## What it must cover

1. **The current conversation and session model.** What a session is (one app launch), how a session id is made, how messages are stamped with it, that there is one conversation per notebook, and how the conversation view shows it. Files: `app/Sources/Sophia/NotebookSession.swift`, `app/Sources/Sophia/ConversationView.swift`, `app/Sources/SophiaCore/NotebookStore.swift` (look at `newSessionID`, `unnotedMessages`, `lastConversationAt`, `isReturn`, `claudeSession`, `appendTranscript`).
2. **Checkpoint, briefing, and catch-up.** What triggers each, what `through` and `catch_up` mean on the checkpoint entry, what the briefing reads, the 6-hour return gap, and the "quiet" message when the window stayed open. Files: `NotebookSession.swift` (`pickUp`, `endSession`, `writeNotes`, `requestBriefing`, `finishRequest`, `send`), `app/Sources/SophiaCore/Prompts.swift` (`checkpoint`, `briefing`, `afterQuiet`), `DATA-MODEL.md` (the checkpoint scope paragraph).
3. **Undo.** The rule "until the person's next message": where `lastWrites` is cleared, what `undoableWrite(for:)` returns, what `undoPageWrite` does, the page banner in `app/Sources/Sophia/BookView.swift`, and the conversation marker's undo. Also `lastReleases` and `lastDeleted`.
4. **Provider resume.** How `ClaudeEngine` is started, what `--resume` is passed, where `store.claudeSession` is read and written (`handle(.started)`, `.turnDone`), what happens when the engine exits, and what PLAN.md says about reconstruction when resume fails (PLAN.md around line 189). Files: `app/Sources/SophiaCore/ClaudeEngine.swift`, `NotebookSession.swift`, `PLAN.md`.
5. **How Sophia's context is assembled.** `Prompts.context` (what it includes: goals, About you, memory, notes count, other notebooks, page list; and that the page list is from conversation start), `Prompts.bookChanges`, `Prompts.musicWarnings`, `Prompts.afterQuiet`, and how `send` composes the outgoing message. Note that Sophia reads page bodies only through `read_page`. Also what `recall` offers (DATA-MODEL.md).
6. **"Ask Sophia about this".** What the mock shows (`mock/index.html` around lines 497 and 523) and whether the app implements it (grep `app/Sources/Sophia` for it; report what you find, including if it is absent).
7. **Every place the design assumes one conversation per notebook.** List each with a citation: in `PLAN.md` (for example line 203 "the notebook's single running conversation"), `SOPHIA.md`, `DATA-MODEL.md`, `EDITING.md`, `mock/index.html`, and the code (single `engine`, single `claudeSession`, `ConversationView` reading `store.transcript`, the checkpoint covering all unnoted messages, the briefing reading the last 12 messages, etc.).
8. **The editing rules that interact with chat** (`EDITING.md`, `DATA-MODEL.md`): the open-section marker, protected lines, the refusal entry, release, and how edits reach Sophia (`bookChanges`). Cite lines.
9. **Reference behavior of other tools.** For each, two or three sentences, and say explicitly whether it was *checked against current documentation* (use WebFetch or WebSearch on the vendor's docs and name the URL) or *from recall*:
   - Claude Code `/clear` and `/compact` (and `--resume` / `--continue`).
   - Codex CLI: new chat and resume.
   - Cursor: chat tabs and threads (including whether context is shared across tabs).
   - One or two notebook-anchored tools: NotebookLM (chat anchored to a notebook's sources; whether chat history persists) and Notion AI (page-anchored versus workspace-wide chat), or Obsidian Copilot if it is easier to verify.
   Keep this section under 300 words.

## Rules

- Read-only. Do not change any file outside `charrettes/2026-10-chat-scope/briefs/grounding.md`.
- Describe, don't recommend. If you notice a tension, state it as a fact with a citation ("X assumes one conversation; Y would need…" is fine only if both halves are cited or clearly marked as inference).
- Mark anything you could not verify as "not verified".
- Do not paste large code blocks; cite lines.
- When done, reply with: the path written, the word count, and a list of any sections you could not complete and why.
