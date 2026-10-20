# C1 rounds: opening passes and digests

Facilitator's record for audit. These are digests, not verbatim transcripts. Voices ran as three persistent Opus subagents: Mara Chen (Design), Marcus Webb (Product), and Devon Reyes (Coding coach). Each received file paths rather than pasted text. Routing was digest-only: each voice saw only the other two voices' new positions.

## Frame

- Team mode: adaptive, with the trio fixed by the operator.
- Direction: divergent.
- Delivery: review-only.
- Starting state: a mature mock (`mock/index.html`) and a working app (`app/Sources`).
- QC notes passed to every voice:
  - "Ask Sophia about this" exists only in the mock.
  - Whether resume picks up fresh context is unverified.

## Round 1: independent opening passes

### Mara (Design)

- **Read:** one notebook-wide conversation beside the book. The chat points into the book (mock:96, :366).
- **Keep:**
  - Separate surfaces, with the chat pointing into the page.
  - Page-to-history pointers: "Earlier today: revising this page" (mock:566) and "Show Oct 14" (mock:621).
- **Risks:**
  - The surfaces disagree about which is primary. The app puts the conversation in the center (SophiaApp.swift:136-143); the mock gives the book the center once a page exists (mock:96). Settle this first. (high)
  - If the chat swaps on sidebar selection, scenario 2 breaks: P's undo card hides (ConversationView.swift:270) and a streaming P reply has no home. (medium-high)
  - No overflow, empty, or return states exist in the app. The view shows the whole transcript unfiltered (ConversationView.swift:94-103). (high)
- **Direction, "One stream, page-stamped lens":**
  - Each transcript entry records the open page.
  - A trailing inspector stays put when the person navigates. It has an "All | This page" scope bar, Finder-style.
  - "New Topic" (⇧⌘N) inserts a /clear-like boundary.
  - Earlier topics collapse to headers with their checkpoint caption.
  - A composer chip shows "On: 1.3"; the page title shows "Discussed 3 times".
- **Test:** a scenario 2 click-through. Do people expect P's exchange to remain visible after clicking Q, or a blank Q chat?

### Marcus (Product)

- **Read:** one continuous inquiry per notebook. Continuity lives in notes, memory, and checkpoints, not in the chat log (PLAN.md:203; DATA-MODEL.md:190-192).
- **Keep:**
  - Notebook-wide learning state.
  - One provider-independent transcript.
- **Risks:**
  - Scenario 6 is rare (assumption; medium) and already covered: Sophia asks one question per reply (SOPHIA.md:40), and the L₁+L₂−1 question is a page edit (scenario 8).
  - Scenario 11 is common and real today (high). About 240 entries in 3 weeks projects to about 1,000 in 3 months. Per-page chats split the overflow; they don't remove it.
  - Page-keyed containers presuppose pages, while scenarios 2 and 4 are cross-page. Each scope multiplies undo, checkpoint, and provider state, and about 10 single-conversation assumptions would change (grounding §7). (medium)
- **Direction, "Anchored stream":**
  - Stamp each person message with its page and section.
  - A page's chat is a filtered view.
  - Clearing writes a divider and starts a new provider session.
  - Undo, checkpoint, and briefing stay unchanged.
  - He names this the smallest change.
- **Test:** tag the messages in a real multi-week notebook by page. If sittings mostly stay on one page, containers earn their cost. If they cross pages, the stream wins.

### Devon (Coding coach)

- **Read:** one conversation. It starts from a launch snapshot (Prompts.swift:91-128), resumes a provider session (ClaudeEngine.swift:60), and receives a per-message `bookChanges` prefix (Prompts.swift:188-218), indexed from the last person message anywhere (NotebookSession.swift:208).
- **Keep:**
  - The per-message prefix.
  - A notebook-wide checkpoint over an explicit message list (NotebookSession.swift:265).
- **Risks:**
  - With per-page provider sessions, P's session misses edits reported on Q, because `since` is global. This affects scenarios 2, 8, and 9. (high)
  - A resumed session may keep its first system prompt, so each scope would freeze its own snapshot, unlabeled (grounding §4). (medium, inference)
  - `recall(page:)` matches note refs only, never messages (Memory.swift:98-101; facilitator verified). A page's past discussion cannot be retrieved today. (high)
- **Direction, "One stream with page tags, clear cuts context, no provider resume":**
  - Every start is reconstructed: `Prompts.context`, the current page body, this page's exchanges since its last clear (capped), and one line per other page discussed since the checkpoint.
  - Navigation adds "now on p:1-4" to the prefix.
  - Clear writes a `clear` entry and restarts; storage and the checkpoint are untouched.
- **Test:** run `--resume` twice with different `--append-system-prompt` sentinels and ask Sophia to quote the sentinel; also try a fake id. If fresh context reaches the resumed session and the bad id fails loudly, per-scope provider sessions become viable.

### Facilitator observation after round 1

All three voices independently converged on one notebook stream with page tags. In a divergent charrette, quick unanimity is not success. The operator's lean (per-page chats with clearing) and the brief's other example premises (named threads over page sets; a chat that follows the selection) have no advocate. Round 2 asks each voice to name the missing directions and give the strongest version of one, within its own remit.

## Round 2: missing directions (divergent contract)

Each voice was asked to give the strongest version of a premise none of the three had chosen, within its own remit.

### Mara (Design)

- **Preserve:**
  - Navigating never hides an exchange that is in flight.
  - The chat shows what Sophia was given.
- **Missing direction, "Page-owned chats":** selecting a page in the sidebar swaps the page and its chat together, Mail/Notes-style.
  - The notebook scope is the Contents row.
  - Chapters get no scope, because `set_chapter` moves pages and would orphan the chats.
  - Open P: the current conversation, with "Earlier on this page: 3 conversations" collapsed above it. ⇧⌘N starts a new conversation.
  - Scenario 2:
    - Q shows a pointer card: "Continuing from 1.3".
    - P's streaming reply finishes in P, and P's row gets an unread dot.
    - P's undo moves to P's page banner (BookView.swift:224-231).
    - ⌘[ and ⌘] navigate back and forward.
  - Week later: the person lands on Contents, where the briefing appears. P's row has an open-question dot. If the person opens Q first, a one-line banner shows.
- **False compromise:** a stream whose "This page" filter also scopes context or clearing. The filter would hide cross-page turns Sophia did see, and per-page clear markers would interleave unreadably in "All".
- **Learning:**
  - The stream tests whether a sitting crosses pages.
  - Page-owned chats test whether finding history by page is faster (11b) and whether the pointer card carries scenario 2.

### Marcus (Product)

- **Preserve:** stream continuity across pages (scenarios 2 and 4), and a single undo, checkpoint, and provider state.
- **Per-page chats with clearing** are credible on their own.
  - Assumption: they fit page-by-page relearning with returns weeks later; 2.2 was discussed in 4 sessions.
  - They buy arrival in a page's history and context bounded by construction.
  - Cost: state for every page.
  - Scenario 4: P keeps the exchange and R gets a pointer.
  - Scenario 5: clear touches P only.
  - Scenario 9: needs a per-scope undo rule beyond DATA-MODEL.md:125.
- **Named threads** are credible, but they are not a page variant.
  - They fit a line that crosses pages and is paused and resumed, for example "spectrogram artifacts" (g-2) across 1.4, 2.1, and 2.2.
  - They buy resuming a paused topic; a divider only goes forward.
  - Costs: the burden of naming, and a chooser that drifts toward a mode picker (locked constraint).
- **False compromise:** "All | This page" plus per-page clearing. Clearing a filtered view has no defined effect on context.
- **Learning:** tag a real notebook's sittings as page-returns versus topic-resumes.

### Devon (Coding coach)

- **Preserve:** book changes reach Sophia through the per-message prefix, not the system prompt.
- **Missing direction, per-page scopes with separate context:**
  - **Cursor:** each scope has its own cursor, the last person message tagged with that page. There is no new file. `bookChanges(since: cursor)` reports edits to any page.
  - **Start:** `Prompts.context`, P's body, P's exchanges since its last clear (capped), and memory.
  - **Per message:** `bookChanges`, plus one "[Sophia app] Elsewhere since your last turn here" line per other scope, citing t-ids.
  - **Never:** Q's exchange verbatim. Sophia uses `recall` instead, which needs page matching for messages.
  - **Clear:** drops the provider session. Storage and the checkpoint are unchanged.
  - **Sentinel test:** a pass means a scope-to-session-id map in notebook.json meta; a failure means always reconstructing, labeled (PLAN.md:189).
- **Named threads over page sets:** the context collapses into the page-scope design, with the page set as the anchor.
- **False compromise:** per-page provider sessions that keep the global `since` and clear undo on any message. This pays for isolation and still works from stale pages (scenarios 8 and 9).
- **Learning:** a page scope keeps a Socratic derivation check (scenario 6) from being steered by unrelated threads.

### Facilitator observation after round 2

- Three premises now have advocates:
  - **(A)** the anchored stream;
  - **(B)** page-owned chats;
  - **(C)** named threads. Marcus calls it a distinct product premise; Devon says its context collapses into B's. This is a live tension.
- The brief's "chat that follows the selection" premise is still unrepresented. A passage-anchored variant is a candidate: margin conversations attached to a selected passage, beside a notebook stream.
- Round 3 assigns each voice its remit across C and the candidate D, and asks whether either is cosmetic.

## Round 3: sharpening C (named threads), testing D (margin threads)

### Mara (Design)

**C's screen is distinct from B's.** The chat is decoupled from page selection.
- The sidebar gets a "Threads" section above "Book".
- A thread acquires pages when a message is sent while a page is open, or when Sophia reads or writes a page. Those pages appear as chips in the thread header.
- A page's title area lists "In: …" for the threads that touch it.
- No chooser appears before typing; messages go to the current thread. A default "Notebook" thread exists.
- ⇧⌘N makes a new thread, which Sophia names after its first exchange.
- Scenario 2: the person stays in the same thread, Q is added as a chip, and the undo card stays visible.
- Week later: the person lands on the last thread, and the briefing appears in "Notebook".
- Cost: two selections live in one sidebar. (medium)

**D is distinct, but a bad fit as a scope model.**
- Margin and chat compete for a 460-800pt book (SophiaApp.swift:131).
- Revisions orphan anchors.
- "Resolve" implies a review workflow.
- It fits scenario 6 and fails scenario 2.
- Keep it as the selection affordance only.

**False compromise:** C with threads auto-created per page is just B.

### Marcus (Product)

**C is distinct from B.** What owns the conversation differs: the topic in C, the page in view in B.
- Scenario 2: B splits the P-to-Q line; C keeps it whole.
- Scenario 7: B resumes by page; C resumes by topic.

He concedes C is "A plus reopening an earlier topic" and proposes folding it into A. The facilitator declined the fold. A's multiplicity answer (one stream, forward-only clearing) and C's (several resumable threads) answer the operator's second question differently, and merging them would be the blend the skill forbids.

**D:**
- Scenario 1 is plausibly common (assumption; SOPHIA.md:42).
- Scenario 6 is rare.
- Most of D's value comes from A's quote-and-anchor stamp, so D is a later layer, not an alternative.

**Smallest change:** A is confirmed. B buys over A that opening a page restores the page's own conversation, with context bounded to it.

### Devon (Coding coach)

**Undo** (inferred from source, untested):
- The store already makes undo page-owned. `isLatestWrite` derives it from the transcript (NotebookStore.swift:454-460), and `undoPageWrite` needs only `.previous.md` (:471-497).
- Only the in-memory `lastWrites` gate is lost on send. The facilitator verified that the banner's `undoableWrite` is gated on `lastWrites` (NotebookSession.swift:357-361).
- Proposed rule for A, B, and C: a write stays undoable until the next write to that page by either author.
- This would survive a crash, because it derives from stored records.
- Only `lastDeleted` stays session-scoped (DATA-MODEL.md:253).

**Checkpoint and briefing:**
- One notebook-wide checkpoint. `unnotedMessages` already spans scopes (NotebookStore.swift:201-211); per-scope checkpoints would split memory.
- The briefing lands at notebook level and reads the last 12 messages of each of the 2-3 most recent scopes, instead of 12 notebook-wide (Prompts.swift:252).

**D:** in context terms it is B with a section anchor. A resolved thread returns to the stream as one "Elsewhere" line plus notes.

**C vs B:** only the anchor (a page set) and the key (a thread id) differ. The context design is the same.

### Facilitator integration after round 3

- **Retained:**
  - A, the anchored stream;
  - B, page-owned chats (the operator's lean);
  - C, named threads. Retained on the screen distinction (Mara) and the product distinction (Marcus) despite the shared context design (Devon). That disagreement is preserved as a tension.
- **D** was dropped as a scope alternative; all three voices give reasons. It is retained as the selection route ("Ask Sophia about this") that each alternative must specify.
- **Cross-cutting proposals:** page-owned undo, a notebook-wide checkpoint, and a reconstruct-vs-resume test. Devon proposes them for every alternative, so they are recorded as shared decisions, not differentiators.

## Round 4: exit check on the draft map

Each voice reviewed `direction-map.md` within its own remit. All corrections were applied.

### Mara (Design)

**Corrections:**
- The draft overstated her. Her rule is "say where an in-flight exchange goes", not "never hide it". B moves the exchange elsewhere by design.
- Add her position: B needs the book in the center; A and C work either way.
- C's week-later return needs a briefing banner above the book.

**Worst cases:** A=11, B=2 (with 4 close behind), C=3. She adds that, on screen, C's 11c is as bad as 3.

**Exit test:** nothing is cosmetic or weakened. Window tabs (⌘T) are a way to present B or C, not a new direction. A line saying so was added.

### Marcus (Product)

**Corrections:**
- Add his claim that scenario 11 is common, and that every alternative has an 11c.
- In the D entry, keep "not hypothetical".

**Worst cases:**
- He would change A's worst case to "5, then 11b". The disagreement with Mara is kept with each view attributed, not averaged.
- B: 4 is a close second.

**Flags:**
- C widens notebook.json to hold thread names.
- The shared undo rule brings forward the deferral at DATA-MODEL.md:253.

**Exit test:** nothing is cosmetic. No locked constraint needs to change.

### Devon (Coding coach)

**Confirmed for A:**
- The start context is "the stream since the last divider". His round 1 wording was wrong for A.
- The global `since` is correct for A.

**Fixes:**
- Undo survives a crash only for recorded writes. Order: page, then notebook.json, then transcript.
- The chat card's Undo needs the `isLatestWrite` gate. The facilitator verified that it is gated by `lastWrites` (ConversationView.swift:270).
- Detecting a failed resume is undefined today. Candidate rules: the process exits before `.started`, or `.started` reports a different id.
- Run the sentinel test with the app's exact flags (ClaudeEngine.swift:53-60, verified), and also with a changed `--system-prompt`.

**Fill-ins:**
- B's Contents scope gets `Prompts.context` plus capped "Elsewhere" lines.
- C's chip pages appear as titles, with only the body of the page in view.

**Constraints:** none need to change. A map from scope to session id is a cache that can be discarded, so storage stays independent of provider sessions.

### Facilitator

The divergent exit test passed after these corrections; see the end of `direction-map.md`. Cycles: one opening pass plus three cross-critique rounds, which is the default cap.
