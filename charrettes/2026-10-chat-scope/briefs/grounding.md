# Grounding: conversations and the notebook today

## 1. Conversation and session model

- A `NotebookSession` is one open notebook and its single conversation process (`app/Sources/Sophia/NotebookSession.swift:5`). Its `session` id is minted at init (`NotebookSession.swift:54`) as `s-` plus the highest number already used in transcript or learning (`app/Sources/SophiaCore/NotebookStore.swift:175-178`). A session is one app launch; a sitting can span several (`DATA-MODEL.md:190`).
- Every transcript entry the app writes carries `session` (`NotebookSession.swift:125`, `:214`); `appendTranscript` stamps id and time (`NotebookStore.swift:102-112`).
- `ConversationView` lists every displayable entry of `store.transcript`, filtered only by role and purpose, never by session or page (`app/Sources/Sophia/ConversationView.swift:94-103`).

## 2. Checkpoint, briefing, catch-up

- `unnotedMessages` are person messages after the furthest checkpoint's `through`, across sessions (`NotebookStore.swift:201-211`). The checkpoint entry records `through`, `catch_up`, `kept`, `not_kept` (`NotebookSession.swift:295-297`); covered messages are never offered again (`DATA-MODEL.md:192`).
- Triggers: End session calls `writeNotes(catchUp: false)` (`NotebookSession.swift:251`). On open, if `isReturn` (last person/Sophia message at least `returnGap`, default 6 h: `NotebookSession.swift:17`, `NotebookStore.swift:214-225`), `pickUp` runs catch-up notes, then a briefing (`NotebookSession.swift:58-59`, `:247-249`, `:320-322`).
- The briefing prompt reads goals, memory, the last 40 non-memory records, all pages, and the last 12 person/Sophia messages (`app/Sources/SophiaCore/Prompts.swift:244-277`).
- If the window stayed open past the gap, no briefing runs; `send` prefixes `Prompts.afterQuiet` (`NotebookSession.swift:205-212`, `Prompts.swift:237-241`).

## 3. Undo

- `lastWrites`, `lastReleases`, `lastDeleted` are in-memory (`NotebookSession.swift:30-34`) and all cleared at the top of `send` (`NotebookSession.swift:201-204`): "until the person's next message" (`DATA-MODEL.md:125`, `EDITING.md:42`). Restart-surviving undo is deferred (`DATA-MODEL.md:253`).
- `undoableWrite(for:)` returns the last id in `lastWrites` for that file that is not undone and is the latest write (`NotebookSession.swift:357-361`, `NotebookStore.swift:455-461`). `undoPageWrite` restores `.previous.md` or removes a new page, then logs `undo_page` (`NotebookStore.swift:472-497`).
- The page banner offers "Undo your edit"/"Undo Sophia's change" (`app/Sources/Sophia/BookView.swift:224-231`); the conversation card's Undo shows while `lastWrites` contains it (`ConversationView.swift:270`, `:332`).

## 4. Provider resume

- `ensureEngine` starts one `ClaudeEngine` with `resume: store.claudeSession` and `context: Prompts.context(store)` (`NotebookSession.swift:96-98`); the engine adds `--resume <id>` (`app/Sources/SophiaCore/ClaudeEngine.swift:60`).
- `claudeSession` lives in notebook meta (`NotebookStore.swift:227-235`), written on `.started` and `.turnDone` (`NotebookSession.swift:117`, `:163`).
- On exit the engine is dropped and a problem is shown; the next message restarts it (`NotebookSession.swift:174-187`, `:88-89`). No code detects a failed resume or reconstructs context (grep: only `NotebookSession.swift:97` reads `claudeSession` in the app). PLAN.md requires a new session with retained context, labelled reconstructed (`PLAN.md:189`; mock `mock/index.html:769`). Stale-id behavior: not verified.
- Inference: Claude Code docs say a resumed conversation keeps the system prompt recorded on its first request until compaction (code.claude.com/docs/en/cli-reference, "System prompt flags in resumed conversations"), so the fresh `--append-system-prompt` context (`ClaudeEngine.swift:59`) may not reach a resumed session. Not verified in the app.

## 5. Context assembly

- `Prompts.context`: tool rules, goals, About you, memory, notes count (latest 10 if memory empty), other notebooks/links (or "kept separate"), page list (`Prompts.swift:91-128`). The page list is "from when this conversation started" (`Prompts.swift:109`). Page bodies arrive only via `read_page` (`Prompts.swift:102`, `:109`).
- `send` prepends `afterQuiet`, `bookChanges` (edits, releases, undone edits since the previous person message), and unseen `musicWarnings` (`NotebookSession.swift:205-213`, `Prompts.swift:188-233`).
- `recall` finds notes by id, page ref, or words, plus matching person messages from the whole transcript (`DATA-MODEL.md:57`, `app/Sources/SophiaCore/Memory.swift:88-109`).

## 6. "Ask Sophia about this"

The mock's selection popover opens the conversation with the passage quoted, headed "About a passage on this page" with an "Earlier today" link (`mock/index.html:497`, `:523`, `:564-568`). Absent from the app: grep of `app/Sources` finds no such string or selection-to-chat path. EDITING.md assumes it keeps working (`EDITING.md:34`); SOPHIA.md says she answers questions about selected passages (`SOPHIA.md:44`).

## 7. One-conversation assumptions

- Docs: `PLAN.md:203`; `PLAN.md:161` (restart restores one session); `SOPHIA.md:93` (memory "at the start of every conversation"); `DATA-MODEL.md:113`, `:190`, `:215`; `EDITING.md:64` ("since her last turn"); `mock/index.html:99` ("One conversation per notebook, in dated sessions").
- Code: one `engine` (`NotebookSession.swift:37`); one `claudeSession` in meta (`NotebookStore.swift:227`); one `request`/`queued` (`NotebookSession.swift:38`, `:43`); `ConversationView` reads all of `store.transcript` (`ConversationView.swift:95`); checkpoint covers all unnoted messages (`NotebookStore.swift:201`); briefing reads the last 12 messages notebook-wide (`Prompts.swift:252`); `bookChanges` indexes from the last person message anywhere (`NotebookSession.swift:208`); undo state cleared by any `send` (`NotebookSession.swift:201-204`); note quota of 8 per session (`DATA-MODEL.md:184`).

## 8. Editing rules that touch chat

Open-section marker `.editing.json`, cleared on commit, revert, launch (`DATA-MODEL.md:40`, `EDITING.md:34`, `NotebookSession.swift:56`); `write_page` refused `open` (`app/Sources/SophiaCore/PageEdits.swift:273-279`, `EDITING.md:46`). Protected lines and quotes (`DATA-MODEL.md:123`, `PageEdits.swift:283-292`). Refusal entry shape (`DATA-MODEL.md:118`), shown as `RefusalCard` (`ConversationView.swift:343-391`). Release (`DATA-MODEL.md:119`, `EDITING.md:56`, `NotebookSession.swift:446-460`). Edits reach Sophia via `bookChanges` with her next message (`EDITING.md:64`, `Prompts.swift:188-218`).

## 9. Reference tools

- **Claude Code** (checked: code.claude.com/docs/en/commands, /cli-reference, /interactive-mode). `/clear` (aliases `/new`, `/reset`) starts an empty-context conversation; the previous one stays resumable via `/resume`. `/compact` summarizes to free context within the same conversation. `--continue` loads the latest conversation in the directory; `--resume` takes an ID or name; `/branch` keeps the original.
- **Codex CLI** (checked via search summaries of developers.openai.com/codex/cli/slash-commands; page not fetched directly). `/new` starts a fresh chat in the same CLI session; `/resume` and `codex resume [--last]` reopen saved chats with history intact, `--last` scoped to the directory.
- **Cursor** (checked via search summary of docs.cursor.com/agent/chat/tabs, which now redirects; not fetched). Each tab has separate history and context and starts empty; `@Past Chats` pulls in other tabs.
- **NotebookLM** (checked via search summary of support.google.com/notebooklm/answer/16179559). Chat is per notebook over selected sources, auto-saved and resumable; "Delete chat history" clears the log, not sources or notes.
- **Notion AI** (checked via search summary of notion.com/help/notion-agent). Chat defaults to the current page and selected blocks, can add sources with @; past chats are listed in the sidebar as separate, renameable threads.
