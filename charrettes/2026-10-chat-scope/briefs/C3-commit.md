# C3 brief: commit to page-owned chats, with context management

You are the facilitator of a design charrette. Invoke the `three-agent-design-charrette` skill (if the Skill tool is unavailable, read `~/.claude/skills/three-agent-design-charrette/SKILL.md` and its `references/` directory) and follow it exactly.

**Team mode:** standard (Mara Chen, Design; Marcus Webb, Product; Imani Blackwood, CEO). **Direction:** convergent. **Delivery:** implementation (one refined prototype plus an interaction spec and a decision brief). **Starting state:** the operator chose alternative B, page-owned chats, and its prototype `mock/chat-scope/page-owned.html`.

Seat the three voices as Opus subagents (Agent tool, `model: "opus"`, `subagent_type: "general-purpose"`, never `fork`), keep the same three across rounds (SendMessage), route digests not verbatim responses. You may use one Opus builder subagent for `chosen.html`; never two writers on one file. You own integration and the two documents.

Project root: `/Users/justincranshaw/Projects/sophia`. Read `AGENTS.md` first.

## Read before seating the room

- `charrettes/2026-10-chat-scope/qc/gate1.md`: the operator's decision and the working assumptions.
- `charrettes/2026-10-chat-scope/briefs/grounding.md`: how things work now, with citations.
- `charrettes/2026-10-chat-scope/briefs/scenarios.md`: the eleven scenarios and the Fourier notebook.
- `charrettes/2026-10-chat-scope/C2/comparison.md` (the B section and the tensions table) and `C2/rounds.md`; `C1/direction-map.md` for B's explicit choices and context design.
- `mock/chat-scope/page-owned.html`, `harness.js`, `harness.css` (copy the harness pattern; do not edit `page-owned.html`, it is the C2 record). `mock/index.html` and `mock/styles.css` for the visual language (do not edit).
- `EDITING.md`, `DATA-MODEL.md`, `SOPHIA.md`, `PLAN.md` for the rules the spec must not contradict.
- Code for what exists: `app/Sources/Sophia/NotebookSession.swift`, `app/Sources/SophiaCore/Prompts.swift`, `app/Sources/SophiaCore/NotebookStore.swift`, `app/Sources/SophiaCore/ClaudeEngine.swift`.

Give voices and the builder these paths, not pasted text.

## The operator's direction

B: a discussion lives with its page. Selecting a page selects its chat. The Contents row owns the notebook-level chat. The operator's reasoning: for dense technical content, the thread on a page becomes part of the learning process. The operator's stated concern, which this charrette must answer as carefully as the scope question itself: **context length, and how the person manages context within a page thread.** A page thread may run for weeks; Sophia cannot receive all of it; the person must be able to see and shape what she is working from without a mode picker or ceremony.

Do not reopen the choice of B. Do not merge in A's scope bar or C's threads. Refine B.

## Locked constraints

As in `briefs/C1-direction-map.md`: AGENTS.md principles and boundaries; storage small (a new file needs a demonstrated need); storage independent of provider sessions; other notebooks seen by title only; EDITING.md protections unchanged; no mode picker or forced lesson structure; at home on macOS. A voice that wants to change one flags it for the operator; the stage does not act on it.

Working assumptions from gate 1 (specify them concretely; the operator can reverse at gate 2): undo is page-owned, "until the next write to that page by either author"; a clear never loses what Sophia learned.

## The trio's remits

- **Mara Chen (Design)** owns the rendered interface and every state: the swap on selection, the pointer card for cross-page continuations, the in-flight reply and undo when the person navigates away, the empty page, the many-session page, the long Contents chat, the return briefing placement and the route from it to the open question, the error state (provider resume failed, context reconstructed, Sophia says so), the editing state per EDITING.md, scenario 4 (the page created from another page's chat), and the context-management affordances. Directive: make what Sophia is working from visible and adjustable in the thread itself, in macOS idiom, without a mode picker. Name the keyboard shortcuts.
- **Marcus Webb (Product)** owns scope, sequencing, and the premise that a page thread is part of learning. Directive: decide what "manage context" means for a solo learner at minimum machinery: when and how a thread is cleared, compacted, or summarized; whether the person can keep or exclude specific exchanges; what the default is when they do nothing (the C2 finding that B's bound depended on pressing ⇧⌘N must be answered). Name the cuts.
- **Imani Blackwood (CEO)** owns Sophia's identity as a wise teacher in a notebook rather than an IDE or chat client, and what the product commits to long term. Directive: judge every affordance against "would a thoughtful teacher's notebook have this?" and against what it commits future versions to (per-page provider sessions, summaries as records, visible context meters). Reject what makes Sophia feel like a developer tool.

Persona files: `~/.claude/skills/three-agent-design-charrette/references/persona-design.md`, `persona-product.md`, `persona-ceo.md`.

## The ask

1. **`mock/chat-scope/chosen.html`**: one prototype refined from `page-owned.html`, covering **all eleven scenarios** as navigable states (hashes `#s1`…`#s11c`, plus `#s4`, `#s8`, `#s9`, `#s10`), including: empty (11a), overflow (11b, 11c), error (provider resume failed, so the context was reconstructed and Sophia says so, in scenario 10), the editing state (scenario 8, with the "open" refusal, the hunk reaching Sophia, the "protected" refusal and the release marker), and the context-management states (what Sophia is working from in this thread; clearing; whatever compaction or keep/exclude affordance the room commits to). Keep the diagnostic "What Sophia sees" inspector, labelled as not part of the product. Use the Fourier notebook content verbatim.

2. **`charrettes/2026-10-chat-scope/C3/interaction-spec.md`**, at most 1,200 words, with exact rules for:
   - creating a scope (which pages and rows have one; what happens for a new page), switching, clearing, finding history, and the keyboard shortcuts;
   - what Sophia receives as context in each scope at thread start and with each message, with the bounds (how many exchanges, which ones, what is summarized and by whom, what the person sees of that), and what "Elsewhere" lines say;
   - how context is managed within a page thread: the default when the person does nothing, what clearing removes from Sophia's context versus storage, whether a clear writes notes first, any compaction or keep/exclude mechanism, and how the person sees what Sophia is working from;
   - how undo is scoped (page-owned), and what the page banner and the chat card show after a message in another scope;
   - what triggers a checkpoint and what it covers (notebook-wide; say what End session and the return catch-up do with several threads);
   - where the briefing appears, and the route from it to the thread holding the open question;
   - how "Ask Sophia about this" routes (the selection on page P goes to P's thread; say what happens if another thread is showing);
   - what happens when a page-scoped chat writes to another page, including creating a new page R (where the conversation stays, what R's thread shows, what R's thread receives as context);
   - what happens on provider resume failure and on crash recovery (state the person-visible rule only; C4 owns the data contract).
   Name the cuts explicitly.

3. **`charrettes/2026-10-chat-scope/C3/decision-brief.md`** in the skill's convergent decision-brief shape: the chosen direction, keep, change, cuts, owners, confidence, remaining dissent. Also `C3/rounds.md` with the opening passes, round digests, and the screenshot index.

Each voice inspects the rendered `chosen.html` in a real browser (gstack `browse`, served over a local static server as C2 did, 1440×900) in every round after a build; screenshots of every state go to `charrettes/2026-10-chat-scope/C3/screens/chosen-<state>.png` from the final file. Rerun build → inspect → critique → revise until the skill's convergent exit test passes; name any limitation of direct inspection.

Rules: every claim points at a rendered element, a source location, a scenario, or an explicit assumption; no persona theater; each unresolved objection is answered, assigned to its owning discipline, or converted into a test. Make no changes outside `mock/chat-scope/chosen.html` and `charrettes/2026-10-chat-scope/C3/`.

When done, reply with: the paths written, the spec's word count, how the voices and builder were run and whether every voice saw the final render, the context-management rule in three sentences, any locked constraint a voice wanted to change, the cuts, and the result of the convergent exit test including remaining dissent.
