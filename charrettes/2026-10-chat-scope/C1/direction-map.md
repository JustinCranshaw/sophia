# Design directions: chat scope in Sophia

This is charrette C1: divergent, review-only. The voices were Mara Chen (Design), Marcus Webb (Product), and Devon Reyes (Coding coach). They ran as three persistent Opus subagents. Round digests are in [rounds.md](rounds.md). No winner is named.

**Who and when:** one person relearning Fourier analysis over months, in one notebook of about 11 pages with about 240 transcript entries across 9 launches in 3 weeks (`briefs/scenarios.md`). They move between reading a page, asking about it, and reorganizing the book.

**What should become possible:** the operator's two questions get coherent answers:
- whether a chat is anchored to a page or to the notebook;
- whether a scope has one clearable session or several named threads.

Those answers should also settle context, navigation, storage, undo, checkpoint, briefing, and provider sessions. All of this must stay within the locked constraints (AGENTS.md; small storage; storage independent of provider sessions; EDITING.md unchanged; no mode picker; macOS).

## Decisions that shape the space

- **What owns a conversation: the notebook, the page in view, or a topic the person names.** This is the root decision. Each alternative below takes one answer. Marcus (Product) states the difference by outcome:
  - in scenario 2, a page owner splits the P→Q line, while a notebook or topic owner keeps it whole;
  - in scenario 7, a page owner resumes by page, while a topic owner resumes by topic.
- **Whether navigating swaps the chat.** If selecting a page also selects its chat, the in-flight P exchange leaves the screen in scenario 2: the undo card (`ConversationView.swift:270`) and any reply still streaming go with it. Mara (Design) holds that every alternative must say where an in-flight exchange goes:
  - A and C keep it on screen.
  - B moves it elsewhere: the streaming reply finishes in P's chat, which gets an unread dot, and undo moves to P's banner.
- **Which surface is primary.** The app puts the conversation in the center (`app/Sources/Sophia/SophiaApp.swift:136-143`). The mock gives the book the center once a page exists (`mock/index.html:96`). Mara owns this decision, and it is unsettled today. Her position: A and C work with either surface in the center, while B requires the book in the center, because the page is what the person selects.
- **Scenario 11 is common, not rare** (Marcus).
  - The fixture already has page 0.3 never discussed and page 2.2 discussed in 4 sessions in 3 weeks.
  - About 240 entries in 3 weeks projects to about 1,000 by month three. This is arithmetic, not observation.
  - Every alternative has an 11c: A's stream, B's Contents chat, and C's "Notebook" thread and its thread list.
  - Scenario 6 is rare (an assumption; there is no user research).
- **Window tabs (⌘T)** (Mara). Native macOS tabs, one per page or thread, are a way to present B or C, not a new owner of the conversation, so they add no alternative.
- **Provider session per scope, or reconstructed context.** This is open. Grounding §4 infers that a resumed Claude Code session may keep its first system prompt. If so, every scope would freeze its own page list (`Prompts.swift:109`). Devon's test:
  1. Run `--resume <id>` twice, the second time with a different `--append-system-prompt` that contains a sentinel word, and ask Sophia to quote the sentinel.
  2. Run once with a fake id.

  Run the test with the app's exact flags: `-p`, stream-json, `--restricted`, `--system-prompt` and `--append-system-prompt` (`ClaudeEngine.swift:53-60`), because print mode may behave differently. Also check whether a changed `--system-prompt` (an edit to SOPHIA.md) reaches a resumed session.

  If the sentinel arrives and the bad id fails loudly, a map from scope to session id in notebook.json meta becomes viable. That map is a cache that can be thrown away, so storage stays independent of provider sessions. Otherwise every scope always reconstructs its context and labels it (`PLAN.md:189`).

  No code detects a failed resume today (grounding §4). Detection would need to be defined, either as the process exiting before `.started` or as `.started` reporting a different id; the fake-id run shows which happens. Not run.

### Shared proposals

Devon proposes these for every alternative. They are therefore not differentiators.

- **Undo belongs to the page.** A write stays undoable until the next write to that page by either author.
  - The store already derives undo this way: `isLatestWrite` (`NotebookStore.swift:454-460`) and `undoPageWrite`, which needs only `.previous.md` (`:471-497`).
  - Today only the in-memory `lastWrites` gate limits it (`NotebookSession.swift:201-204`, `:357-361`).
  - If the gate is dropped, undo survives a crash for writes that were recorded. This is inferred from source and untested.
    - A save writes the page, then notebook.json, then the transcript (`DATA-MODEL.md:125`).
    - A crash before the transcript step leaves a write with no entry, which `isLatestWrite` cannot offer.
  - The conversation card's Undo must use the same gate as the page banner. Today it checks `lastWrites` (`ConversationView.swift:270`).
  - Only `lastDeleted` stays session-scoped.
  - This changes `DATA-MODEL.md:125` and `EDITING.md:42` ("until the person's next message"). It also brings forward undo that survives a restart, which `DATA-MODEL.md:253` explicitly deferred (Marcus). Both are documented rules, not locked constraints, and they need the operator's approval.
- **One notebook-wide checkpoint.**
  - `unnotedMessages` and `through` already span every scope (`NotebookStore.swift:201-211`).
  - A checkpoint per scope would split memory.
  - Clearing never runs or skips a checkpoint.
- **`recall` must find messages by page.**
  - Today `recall(page:)` matches only note refs (`Memory.swift:94-97`; verified).
  - A page's past discussion is therefore unretrievable as written.
  - Every alternative depends on fixing this, whether for `recall` or for the filtered view.
- **The edit rules hold unchanged.**
  - `write_page` is refused while a section is open (`PageEdits.swift:273-279`).
  - Protected lines are refused (`:283-292`).
  - The refusal card shows in whichever conversation made the attempt.
  - Edits reach Sophia through `bookChanges` in the per-message prefix, never through the system prompt.

### Routing "Ask Sophia about this"

It exists only in the mock (`mock/index.html:497`, `:564-568`); the app has no route for it (grounding §6). Each alternative defines its own route below.

Passage-anchored margin threads ("D") were considered and rejected as a scope model:
- Mara: they compete for a 460–800 pt book (`SophiaApp.swift:131`), revisions orphan their anchors, and "resolve" implies a review workflow.
- Marcus: scenario 1 is plausibly common, so D is not hypothetical, but it belongs as a later layer on A's quote-and-anchor stamp.
- Devon: their context is B's with a section as the anchor.

D survives only as the selection route.

## Direction A: Anchored stream

- **Premise:** the conversation belongs to the notebook. A page is context that travels with each message, not a container. A sitting crosses pages (scenarios 2 and 4), and continuity lives in notes, memory, and checkpoints rather than in chat history (`PLAN.md:203`, `DATA-MODEL.md:190-192`).
- **Explicit choices:**
  - **Chat and page:** the chat is notebook-wide. Each transcript entry gains an optional `page` (and section) field: the page in view when the message was sent. The field goes on existing records; no file is added.
  - **Navigation:** does not re-anchor or swap the chat. Only the composer chip changes ("On: 1.4 Sampling and aliasing").
  - **Notebook scope:** the stream itself. The top-level page is not a separate scope; messages sent with no page open carry no `page` field.
  - **Chapter scope:** none.
  - **Clearing:** "New Topic" (⇧⌘N; ⌘N is New Notebook, `SophiaApp.swift:69`) writes a `clear` divider entry, and the engine restarts with reconstructed context.
    - Transcript: untouched.
    - Checkpoint: unaffected.
    - Memory and notes: kept.
    - Clearing only moves forward; an earlier topic can't be reopened as live context, only read and recalled.
  - **Finding history:**
    - Scroll the stream. Earlier topics collapse to one-line headers with their checkpoint caption.
    - An "All | This page" scope bar filters the view, as Finder's search scope bar does.
    - A page's title area shows "Discussed 3 times", which opens the filter.
- **Experience** (Mara):
  - The chat is a trailing inspector that stays put during navigation.
  - **Open P:** the stream is unchanged and the chip shows 1.3.
  - **Scenario 2:** the P exchange and its undo card stay visible.
  - **Week later:** one briefing appears at the end of the stream, and the person lands on the last open page.
  - **macOS conventions:** sidebar selection drives only the book; `.inspector`; a scope bar; ⇧⌘N.
- **Context** (Devon):
  - **At each start** (launch, clear, or failed resume, all built the same way):
    - `Prompts.context`;
    - the current page's body;
    - the stream since the last divider, capped;
    - one line per other page discussed since the checkpoint.
  - **With each message:** `bookChanges` since the last person message (today's global `since`, `NotebookSession.swift:208`, stays correct here) and "[Sophia app] The person is now on p:1-4" when the page changed.
  - **Resume failure:** if every start is reconstructed, resume never needs to succeed. If the sentinel test passes, resuming one notebook session id remains possible.
- **Ask Sophia about this:** the selected passage is attached to the next message as a quote, under the page chip.
- **Strength:**
  - It is the smallest change: an optional anchor field and a divider entry (Marcus).
  - Scenarios 2 and 4 stay whole.
  - Undo, checkpoint, and provider state stay single.
- **Cost:**
  - Opening a page doesn't bring back "its" conversation; the person has to filter.
  - The notebook stream grows without bound in scenario 11c, held in check only by collapsing.
  - A finished topic can't be resumed as live context.
- **Handles worst:** the voices split, and both views are kept.
  - Mara (Design) names scenario 11: the months-long stream, and 2.2's history interleaved with everything else.
  - Marcus (Product) names scenario 5, then 11b. 11c is shared by all three, so it doesn't single out A. A's own weaknesses are that the old discussion can be read but not continued (5), and that 2.2's history is reached only through the filter (11b).
- **Test:**
  - Marcus's tagging test: tag each person message in a real multi-week notebook by the page it concerns. If sittings regularly cross pages, A gains.
  - Mara's scenario 2 click-through: if people expect P's exchange to stay on screen after clicking Q, A gains.

## Direction B: Page-owned chats

The operator's lean.

- **Premise:** a discussion lives with its page. A learner who works through a textbook comes back to a page weeks later. Page 2.2 was discussed in 4 sessions in 3 weeks (`scenarios.md`). Marcus labels this habit an assumption.
- **Explicit choices:**
  - **Chat and page:** each page owns its chat. Messages are stored in the one transcript.jsonl, tagged with `page`; no file is added.
  - **Navigation:** re-anchors. Selecting a page in the sidebar swaps both the page and its chat, as selecting a mailbox does in Mail or Notes.
  - **Notebook scope:** the top-level Contents row (`SidebarView` `.contents`) owns the notebook chat.
  - **Chapter scope:** none. `set_chapter` moves pages between chapters, so a chapter scope would orphan chats (Mara).
  - **Clearing:** ⇧⌘N starts a new conversation on this page. It writes a `clear` entry tagged with the page, and that scope's provider session or reconstructed context is dropped.
    - Transcript: untouched.
    - Checkpoint: the notebook-wide one is unaffected.
    - Memory and notes: kept.
    - Other pages' chats: unaffected.
  - **Finding history:**
    - Above the current conversation sits "Earlier on this page: 3 conversations", collapsed.
    - Sidebar rows carry unread and open-question dots.
- **Experience** (Mara):
  - **Open P:** P's current conversation, with the earlier conversations collapsed above it.
  - **Scenario 2:**
    - Q's chat is empty apart from a pointer card, "Continuing from 1.3: convolution theorem".
    - A P reply that is still streaming finishes in P's chat, and P's row gets an unread dot.
    - P's undo moves from the chat card to P's page banner (`BookView.swift:224-231`).
    - ⌘[ and ⌘] navigate back and forward.
  - **Week later:** the person lands on Contents, where the briefing sits. P's row carries an open-question dot. If the person opens Q first, a one-line briefing banner sits above the book until dismissed.
  - **macOS conventions:** sidebar selection drives the detail view; unread dots; ⌘[ and ⌘]; ⇧⌘N.
- **Context** (Devon):
  - **Each scope has its own cursor:** its last person message tagged with that page. `bookChanges(since: cursor)` reports edits to any page, which fixes the staleness that today's global `since` would cause.
  - **At the start of P's scope:**
    - `Prompts.context`;
    - P's body;
    - P's exchanges since its last clear, capped;
    - memory.
  - **With each message:** `bookChanges` since P's cursor, plus one "[Sophia app] Elsewhere since your last turn here: p:1-4 discussed, t-…" line per other scope.
  - **The Contents scope:** gets `Prompts.context` and capped "Elsewhere" lines, with no page body. Scenario 3 needs nothing more.
  - Another scope's exchange is never included verbatim; Sophia uses `recall` once it can match messages by page.
  - **Resume failure:** handled scope by scope.
    - If the sentinel test passes, store a map from scope to provider session id in notebook.json meta.
    - Otherwise each scope rebuilds its context the first time it is used after launch and says so.
- **Ask Sophia about this:** opens P's chat, if it isn't already showing, with the passage quoted.
- **Strength:**
  - Arriving at a page brings back that page's discussion with no filter step.
  - Sophia's context is limited to the page by construction (scenario 11b).
  - A Socratic derivation check on P isn't steered by unrelated threads (Devon).
- **Cost:**
  - Chat state for every page: cursors, unread state, and a provider session or reconstruction per scope.
  - About ten one-conversation assumptions in code and docs must change (grounding §7).
  - Cross-page lines are split (scenarios 2 and 4).
  - Before a page exists there is only Contents to talk in. Containers keyed to pages pull against structure emerging from the inquiry (Marcus).
- **Handles worst:** scenario 2. The question about Q depends on the discussion of P, but it lands in Q's empty chat behind a pointer card, and Sophia has to recall P's exchange. Scenario 4 is a close second (Mara and Marcus): R's chat starts with only a pointer.
- **Test:**
  - Marcus's tagging test: if most sittings stay on one page and the person returns to a page by opening it, B gains.
  - Mara's click-through: if people expect a blank Q chat after clicking Q, B gains and A fails.

## Direction C: Named threads

- **Premise:** a conversation belongs to a topic the person is pursuing. The topic can span pages and can be paused and picked up again. An example is "spectrogram artifacts" for g-2 across 1.4, 2.1 and 2.2, running alongside a derivation drill on P. Marcus labels this habit an assumption.
- **Explicit choices:**
  - **Chat and page:** a thread owns the chat. Pages attach to the thread when a message is sent while they are open, or when Sophia reads or writes them, and they show as chips in the thread header. Messages are stored in the one transcript, tagged with `thread` and `page`; the thread's name lives in notebook.json; no file is added.
  - **Navigation:** does not re-anchor. The book follows page selection and the chat follows thread selection.
  - **Notebook scope:** a default "Notebook" thread, separate from the Contents page.
  - **Chapter scope:** none.
  - **Starting fresh:** ⇧⌘N creates a new thread, which Sophia names after its first exchange and the person can rename (Notion precedent).
    - Transcript: untouched.
    - Checkpoint: the notebook-wide one is unaffected.
    - Memory and notes: kept.
    - The old thread stays in the list and can be resumed as live context.
    - There is no separate "clear"; starting a new thread is the clear.
  - **Finding history:**
    - A "Threads" sidebar section above "Book".
    - A page's title area lists "In: Spectrogram artifacts, Convolution", and clicking one switches thread.
    - Paused threads carry open-question dots.
- **Experience** (Mara):
  - **Avoiding a mode picker:** there is no chooser before typing. The composer posts to the current thread.
  - **Open P:** the book shows P and the chat stays on the current thread.
  - **Scenario 2:** same thread; a Q chip is added; the undo card stays visible.
  - **Week later:** the person lands on the last thread. The briefing is in "Notebook", with a one-line briefing banner above the book, as in B, until dismissed.
  - **macOS conventions:** a source-list section; ⇧⌘N; renaming in place.
- **Context** (Devon):
  - The same design as B, keyed by thread id instead of page, with a set of pages as the anchor whose bodies are read on demand.
  - **At the start of a thread:**
    - `Prompts.context`;
    - the titles of the thread's chip pages, with only the body of the page in view;
    - the thread's exchanges, capped;
    - memory.
  - **With each message:** `bookChanges` since the thread's cursor, plus "Elsewhere" lines for the other threads. These lines are capped for the long-lived "Notebook" thread.
  - **Storage:** thread names in notebook.json widen that file beyond chapters and page order (`DATA-MODEL.md:35`; flagged by Marcus).
  - **Resume failure:** handled per thread, as in B.
- **Ask Sophia about this:** the passage is quoted into the current thread, and P is added as a chip.
- **Strength:**
  - A line of reasoning stays whole across pages (scenario 2).
  - A paused topic can be resumed as live context (scenarios 5 and 6).
  - It is the only alternative where two concurrent lines on one page each keep their own context.
- **Cost:**
  - Two selections share one sidebar (Mara: breaks the flow, medium).
  - Naming takes effort.
  - A thread list can drift toward a mode picker, which the locked constraints forbid.
  - It carries B's per-scope state machinery (Devon).
  - Mara's false compromise: threads auto-created per page are just B.
- **Handles worst:** scenario 3. Reorganizing the book or setting a goal lands in whichever thread is current, unless the person first switches to "Notebook", and the notebook-level actions end up scattered across topic threads. On screen, Mara rates 11c as equally bad: the thread list itself becomes the overflow, and two selections compete in one sidebar.
- **Test:** Marcus's sitting test. Tag a real notebook's sittings as page-returns or topic-resumes. Frequent topic-resumes that span pages favor C; rare ones mean C is A plus a list nobody uses.

## Scenario walkthrough

| # | A: Anchored stream | B: Page-owned chats | C: Named threads |
|---|---|---|---|
| 1 Ask about a sentence, then revise | The selection is attached as a quote to the next message in the stream, stamped p:1-3 §filters. Sophia revises P, and the undo card shows in the stream and on P's banner. | P's chat (already open) receives the quote. The revision's undo shows in P's chat and on P's banner. | The quote goes into the current thread and P is added as a chip. The undo card shows in the thread and on P's banner. |
| 2 Open Q mid-exchange | The stream stays on screen and the chip changes to 1.4. Sophia has the P exchange in context and answers in the stream. | Q's chat opens empty with a pointer card "Continuing from 1.3". The answer goes in Q's chat. Sophia sees "Elsewhere: p:1-3 discussed" and recalls P's exchange. P's undo moves to P's banner. | The same thread continues and a Q chip is added. Sophia has the whole line, and the answer goes in the thread. |
| 3 Notebook level | With no page open, messages carry no page. `set_chapter` and `set_goal` run in the stream. g-2 stays provisional. | The person selects Contents, and all three exchanges go in the Contents chat. | The person must be on the "Notebook" thread. Otherwise the exchanges land in the current topic thread. |
| 4 Page chat creates R | The conversation stays in the stream. When R is opened, "This page" shows the exchange that created R, because the `write_page` entry carries R's file. | The conversation stays in P's chat. R's chat shows a pointer card, "Created from a conversation on 1.3", and links back. | The thread stays and R is added as a chip. R's title area lists "In: <thread>". |
| 5 Fresh start on P | ⇧⌘N writes a divider, and Sophia restarts with reconstructed context; memory and notes are kept. The old discussion stays above the divider, readable but not resumable. | ⇧⌘N on P starts a new P conversation. The old ones collapse under "Earlier on this page", readable, and P's context resets. | ⇧⌘N starts a thread, "Where it fails". The old thread stays in the list and can be resumed as live context. |
| 6 Two lines on one page | One stream. The L₁+L₂ question is asked as an aside, or made as a page edit (scenario 8). The derivation check resumes after one reply. Marcus: rare (assumption). | The same as A, inside P's chat. A new P conversation would abandon the derivation. | A new thread for the aside, so the derivation thread stays paused and intact. This is C's best case, and Marcus judges it rare. |
| 7 Back after a week | Catch-up notes, then a briefing at the end of the stream. The person lands on the last open page. Opening Q first still shows the briefing. | The briefing goes in the Contents chat and the person lands there. P has an open-question dot. Opening Q first shows a one-line banner. | The briefing goes in "Notebook" and the person lands on the last thread. A one-line banner shows above the book until dismissed. Paused threads have dots. |
| 8 Editing while chat is open | The refusal ("open") card shows in the stream. The commit reaches Sophia as a hunk with the next message. The "protected" refusal and the release behave per EDITING.md. | The refusal card shows in P's chat. The hunk reaches each scope with its next message after its cursor, so P's scope sees it on the next P message. EDITING.md is unchanged. | The refusal card shows in the thread that tried the write. The hunk reaches each thread through its own cursor. EDITING.md is unchanged. |
| 9 Undo across scopes | Under the shared rule, P's revision stays undoable until the next write to P, both on P's banner and on the card in the stream. | P's banner keeps "Undo Sophia's change" after a message in Q. Undo belongs to the page, not to the chat. | The same as B. P's banner holds it, whichever thread is current. |
| 10 Crash and relaunch | One stream rebuilt from the transcript. Undo is rederived from recorded writes (inferred). One reconstructed start, labelled once. | Each scope's history is filtered from the one transcript. Each scope reconstructs the first time it is used and labels that scope. A stale session id is detected (the detection rule is still to be defined, see Decisions) and discarded. | The same as B, per thread. |
| 11 Empty and overflow | 0.3: "This page" shows "Not discussed yet", and the stream is unchanged. 2.2: the filter shows its 4 sessions. The notebook stream grows for months, bounded only by collapsing topic headers and Sophia's capped context since the divider. | 0.3: an empty chat with a quiet "Ask about this page" prompt. 2.2: "Earlier on this page: 4 conversations". The Contents chat grows for months and is bounded by ⇧⌘N. | 0.3: no threads listed. 2.2: "In:" lists its threads. The "Notebook" thread grows for months and is bounded by new threads. The thread list itself becomes the overflow. |

## Tensions to preserve

- **Is C distinct?** Devon (context) says C's context design is identical to B's. Mara (screen) and Marcus (product) say C differs from B in what owns a conversation, with different outcomes in scenarios 2 and 7. Marcus would fold C into A as "resumable topics". The facilitator kept the three apart because A and C give opposite answers to the operator's second question (clear vs. threads). Merging them would blend the alternatives. **Evidence that settles it:** Marcus's sitting test.
- **Arrival vs continuity.** B optimizes arriving at a page; A and C optimize a line of thought that crosses pages. They cannot be blended. Mara and Marcus independently name the same false compromise: an "All | This page" filter whose clearing or context also scopes per page. Clearing a filtered view has no defined effect on Sophia's context, and per-page clear markers interleave unreadably in "All". **Evidence:** the tagging test and the scenario 2 click-through.
- **Primary surface.** Owned by Mara. The app (chat-center) and the mock (book-center) disagree, and the choice weighs differently in each alternative.
- **Provider sessions.** Owned by Devon. Each alternative works under reconstruction. Per-scope resume (B, C) becomes viable only if the sentinel test passes.

## Locked constraints

No voice asked to change a locked constraint.

Two flags for the operator:
- The shared undo proposal changes documented rules (`DATA-MODEL.md:125`, `EDITING.md:42`) and brings forward a deferral (`DATA-MODEL.md:253`).
- C widens notebook.json to hold thread names.

## Divergent exit test

It passes. All three voices confirmed in round 4 that no alternative is cosmetic or weakened.

1. **Range:** three owners of the conversation: the notebook (A), the page in view (B), and a topic the person names (C). A and C also give opposite answers to the multiplicity question: forward-only clearing versus resumable threads.
2. **Integrity:** each alternative is internally coherent. C was not folded into A, and D was dropped rather than blended in.
3. **Comparability:** all three use the same actor, notebook, eleven scenarios, and locked constraints.
4. **Tensions:** recorded above, each with an owner or a test.
5. **Learning value:** each alternative names its own test.
6. **Prototypes:** none were requested.
