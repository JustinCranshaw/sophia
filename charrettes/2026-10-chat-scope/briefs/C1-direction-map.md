# C1 brief: map the design space for chat scope in Sophia

You are the facilitator of a design charrette. Invoke the `three-agent-design-charrette` skill (if the Skill tool is unavailable, read `~/.claude/skills/three-agent-design-charrette/SKILL.md` and its `references/` directory) and follow it exactly.

**Team mode:** adaptive, with the trio fixed by the operator (below). **Direction:** divergent. **Delivery:** review-only (a direction map; no repository changes outside the output file). **Starting state:** an existing product with a mature mock and a working app; the question is a structural one about conversations.

If you can spawn subagents, seat the three voices as Opus subagents (Agent tool, `model: "opus"`, `subagent_type: "general-purpose"`) and keep the same three agents across rounds (SendMessage). If you can't, voice them one after another as the skill describes and say so in your handoff.

Project root: `/Users/justincranshaw/Projects/sophia`. Read `AGENTS.md` first.

## The problem

Today a notebook has one conversation beside the book; one session per app launch; "End session" runs the learning checkpoint; the Claude engine resumes one stored provider session; every message goes to one `transcript.jsonl`; undo lasts "until the person's next message". The operator wants to rethink this along two axes that must be settled together:

1. **Anchoring.** Each page might have its own chat, anchored mainly to that page, plus a chat anchored to the notebook as a whole (perhaps reached by selecting the notebook's top-level page).
2. **Multiplicity within a scope.** One ongoing session per scope that the person can clear (as Claude Code and Codex do), or several named threads (as Cursor does)? The operator leans toward clearing but this is open.

What follows from the answers must also be mapped: what context Sophia gets in each scope, what happens on navigation, and how storage, undo, checkpoints, the return briefing, and provider sessions map onto scopes.

## Read before seating the room

- `charrettes/2026-10-chat-scope/briefs/grounding.md`: how things work now, with citations. Treat it as the factual baseline; verify a citation if you doubt it.
- `charrettes/2026-10-chat-scope/briefs/scenarios.md`: the eleven scenarios and the Fourier notebook. Every alternative must walk through all eleven.
- Sources of truth: `PLAN.md`, `SOPHIA.md`, `DATA-MODEL.md`, `EDITING.md`, `mock/index.html`, and `app/Sources` (mainly `Sophia/NotebookSession.swift`, `Sophia/ConversationView.swift`, `SophiaCore/ClaudeEngine.swift`, `SophiaCore/NotebookStore.swift`, `SophiaCore/Prompts.swift`). Code shows how things work now, not how they should.

Give each voice these paths, not pasted text.

## Locked constraints (no alternative may violate them; flag it in the handoff if a voice wants to change one)

- The Product principles and Implementation boundaries in `AGENTS.md`.
- Storage stays small: Markdown pages, notebook.json, transcript and learning JSONL, one previous page version. A new file needs a demonstrated need.
- Storage is independent of provider sessions (a notebook must be fully readable and recoverable without any provider session).
- Sophia sees only the titles of other notebooks.
- The person's edits are protected exactly as `EDITING.md` describes.
- No mode picker, no forced lesson structure.
- It must feel at home on macOS.

## The trio and their directives

Ownership map (share with all three):

- **Mara Chen (Design)** owns the visible relationship between chat and page: where the chat sits, how navigation changes it, what the person sees on arrival at a page or the notebook, the empty, overflow, and return states, and how history is found. Directive: for each alternative, say what is on screen when the person opens page P, opens Q mid-exchange (scenario 2), and comes back after a week (scenario 7), and what macOS conventions (sidebar selection, tabs, split views, `⌘N`-style shortcuts) it leans on. Boundary: don't decide which scenarios are real (Marcus) or what Sophia should know (Devon).
- **Marcus Webb (Product)** owns which scenarios are real for a solo learner and the scope of the change. Directive: judge scenario 6 (two lines on one page) and scenario 11 (overflow) honestly: is each common, rare, or hypothetical for one person studying over months? Name the smallest change to today's single conversation that would resolve the operator's two questions, and what each larger alternative buys over it. Boundary: don't design the screen (Mara) or the context rules (Devon).
- **Devon Reyes (Coding coach)** owns agent context: what Sophia should know in each scope, clearing versus compaction, continuity of context across scopes and sessions, and the difference between a provider session and reconstructed context. Directive: for each alternative, specify what Sophia receives at the start of a scope's conversation and with each message (page body? the page's past discussion? the notebook stream? memory and notes? the other scope's last exchange?), what "clear" removes from her context versus from storage, and how resume failure is handled. Point at `Prompts.context`, `bookChanges`, `recall`, and the checkpoint mechanism as they exist now. Boundary: don't rule on screen layout (Mara) or on scope of the product change (Marcus).

Persona files: `~/.claude/skills/three-agent-design-charrette/references/persona-design.md`, `persona-product.md`, `persona-coding-coach.md`.

## The ask

Produce two to four coherent, materially different alternatives. Each answers both axes and makes these choices explicit:

- whether a chat lives with a page, or the page is only context for a notebook-wide stream;
- whether navigating to another page re-anchors the chat;
- whether the notebook scope is the top-level page or something separate;
- whether a chapter has its own scope;
- what clearing (or starting a new thread) means for the transcript, the checkpoint, and Sophia's memory;
- how past sessions or threads are found again.

At least one alternative must differ substantially from the operator's lean (per-page chats with clearing). Examples of genuinely different premises: one continuous notebook stream with page context passed along automatically as the person navigates; named threads that can be anchored to any set of pages; a chat that follows the selection rather than the page. Each alternative walks through all eleven scenarios in a table (rows: scenarios 1–11; columns: the alternatives; each cell says concretely what happens, in one to three sentences) and names the scenario it handles worst.

Apply the skill's divergent exit test before stopping. Do not pick a winner. Do not blend alternatives.

## Output

`/Users/justincranshaw/Projects/sophia/charrettes/2026-10-chat-scope/C1/direction-map.md`, in the skill's divergent direction-map shape, plus the scenario table and, per alternative, the explicit choices above. Also record each voice's opening pass and the round digests in `/Users/justincranshaw/Projects/sophia/charrettes/2026-10-chat-scope/C1/rounds.md` so the operator can audit the reasoning (digests, not verbatim transcripts).

Rules: every claim points at a file, a cited line, a scenario, or an explicit assumption; no persona theater, credentials, or war stories; disagreements are preserved as tensions, assigned to an owner, or turned into a test, never averaged. Make no changes outside `charrettes/2026-10-chat-scope/C1/`.

When done, reply with: the paths written, the alternatives' names in one line each, how the voices were run (subagents or sequential), any locked constraint a voice wanted to change, and the result of the divergent exit test.
