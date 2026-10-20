# C4 brief: data, agent context, and recovery for page-owned chats

You are the facilitator of a design charrette. Invoke the `three-agent-design-charrette` skill (if the Skill tool is unavailable, read `~/.claude/skills/three-agent-design-charrette/SKILL.md` and its `references/` directory) and follow it exactly.

**Team mode:** adaptive, with the trio fixed by the operator (below). **Direction:** convergent. **Delivery:** review-only (documents; no edits to the real docs or to `app/`). **Starting state:** the C3 interaction spec and decision brief for page-owned chats.

Seat the three voices as Opus subagents (Agent tool, `model: "opus"`, `subagent_type: "general-purpose"`, never `fork`), keep the same three across rounds (SendMessage), route digests not verbatim responses. You write the outputs.

Project root: `/Users/justincranshaw/Projects/sophia`. Read `AGENTS.md` first.

## Read before seating the room

- `charrettes/2026-10-chat-scope/C3/interaction-spec.md` and `C3/decision-brief.md`: the behavior to support. Do not reopen design decisions; if the spec is ambiguous or unimplementable, say exactly where and propose the minimal reading.
- `charrettes/2026-10-chat-scope/qc/gate1.md` and `qc/C3.md`: the operator's decisions and the orchestrator's QC notes.
- `charrettes/2026-10-chat-scope/briefs/grounding.md` and `briefs/scenarios.md`.
- `DATA-MODEL.md` (especially "The conversation log", "How records arrive", "Deletion and undo", and "Why each retained part is needed"), `PLAN.md` (§4 storage, the restart and resume rows, line 189), `SOPHIA.md`, `EDITING.md`.
- Code: `app/Sources/SophiaCore/NotebookStore.swift` (`appendTranscript`, `unnotedMessages`, `isLatestWrite`, `undoPageWrite`, `claudeSession`, `newSessionID`, `isReturn`), `app/Sources/SophiaCore/Prompts.swift`, `app/Sources/SophiaCore/ClaudeEngine.swift`, `app/Sources/SophiaCore/Memory.swift` (`recall`), `app/Sources/SophiaCore/PageEdits.swift`, `app/Sources/SophiaCore/RecordChecks.swift`, `app/Sources/Sophia/NotebookSession.swift`, `app/Sources/Sophia/ConversationView.swift`, `app/Sources/sophia-mcp/main.swift`, and `app/README.md` (the only commands that exist).

Give voices these paths, not pasted text.

## Locked constraints

As in `briefs/C1-direction-map.md`: AGENTS.md principles and boundaries (tools never delete pages or the person's records, never mark goals met, every page write recorded and undoable); storage stays small (Markdown pages, notebook.json, transcript and learning JSONL, one previous version; a new file or record type needs a scenario that requires it); storage independent of provider sessions; other notebooks by title only; EDITING.md protections unchanged. Flag, don't act on, any wish to change one.

## The trio's remits

- **Devon Reyes (Coding coach)** owns how context is assembled per scope (at thread start and per message), provider session per scope versus reconstruction, detection of a failed resume, cost and latency of several live sessions, and what a clear or compaction does to the provider session. Directive: specify the exact composition of Sophia's context for a page thread and for the Contents thread as changes to `Prompts.context`, `bookChanges`, and the per-message prefix; define the resume-failure detection rule and the sentinel test from C1 as the check that decides between per-scope resume and always-reconstruct; state cost in tokens per thread start under both. Boundary: don't design records (Nadia) or widen scope (Marcus).
- **Nadia Okafor (Media systems engineer; here directed at data contracts)** owns the transcript and learning record contracts, determinism, crash ordering, and restart recovery: the scope field on transcript entries and what it refers to when a page is renamed or created; whether a clear is a new `session` or a new entry kind; the scope-to-provider-session map and where it lives; checkpoint scope and `through` with several threads; the undo rule as a derivation from stored records; migration of existing notebooks with one conversation. Directive: for each addition, name the scenario that requires it and the simpler option rejected, in the style of DATA-MODEL.md's "Why each retained part is needed"; walk scenario 10 (crash with several threads live, provider resume failing) step by step through the write order. Boundary: don't decide what Sophia sees (Devon) or what is in scope (Marcus).
- **Marcus Webb (Product)** owns holding every piece of machinery to the minimum the C3 spec needs. Directive: for each proposed field, entry kind, or mechanism, ask which scenario breaks without it; strike anything that none requires; order the implementation slices so the first one is usable on its own. Boundary: don't redesign the spec.

Persona files: `~/.claude/skills/three-agent-design-charrette/references/persona-coding-coach.md`, `persona-media-systems.md`, `persona-product.md`.

## The ask

1. **`charrettes/2026-10-chat-scope/C4/decision-brief.md`** (convergent decision-brief shape): the minimal data-model and engine changes the C3 spec requires. For each: the scenario it is required for, the simpler option rejected and why, and the check that verifies it. Cover at least: the scope field on transcript entries (and renames and new pages); clear as session or entry; scope-to-provider-session mapping; checkpoint scope and `through`; the undo rule; context assembly per scope; compaction or summary records if the spec has them (and whether they are records, transcript entries, or nothing stored); migration of existing notebooks; resume-failure detection; what `recall` must change. Record remaining dissent with owners.

2. **`charrettes/2026-10-chat-scope/C4/proposed-edits/`**: full proposed replacement text for each affected section of `DATA-MODEL.md`, `PLAN.md`, `SOPHIA.md`, and `EDITING.md`, one file per doc (`DATA-MODEL.md.md`, etc.), each listing the section heading replaced and the new text in the doc's own style. Include the cleanup of DATA-MODEL.md's "pending proposals" mention at line 215 (retired draft model). Do not edit the real docs.

3. **`charrettes/2026-10-chat-scope/C4/slices.md`**: ordered implementation slices for `app/`, each with the files touched, the observable exit check, and the command that runs it, using only commands in `app/README.md` (`swift run sophia-checks`, `--live`, `--probes`, `sophia-reader-checks`, `scripts/make-app.sh`, the snapshot env vars). A slice may add a check to `sophia-checks`; say which.

4. **`charrettes/2026-10-chat-scope/C4/rounds.md`**: opening passes and round digests.

Run the convergent exit test before stopping. Rules: every claim cites a file and line or a scenario; no persona theater; disagreements resolved, owned, or turned into a test. Make no changes outside `charrettes/2026-10-chat-scope/C4/`.

After you report, an adversarial reviewer will read the C3 spec and your edits cold and try to break them with scenarios 2, 4, 9, and 10. Expect up to two rounds of confirmed findings sent back to you for revision.

When done, reply with: the paths written, the list of additions to the data model (one line each, with the requiring scenario), what was struck as unrequired, the resume decision and its test, how the voices were run, any locked constraint a voice wanted to change, and the result of the convergent exit test with remaining dissent.
