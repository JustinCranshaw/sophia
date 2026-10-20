# C4 adversarial review brief

You are a cold adversarial reviewer. You have not seen the discussion that produced these documents and you must not read `C4/rounds.md`, `C3/rounds.md`, or any `qc/` file. Your job is to break the design with four scenarios, not to improve it.

Project root: `/Users/justincranshaw/Projects/sophia`. Read `AGENTS.md` first.

## Read, in this order

1. `charrettes/2026-10-chat-scope/briefs/scenarios.md`: the notebook fixture and the eleven scenarios. You attack with scenarios **2, 4, 9, and 10** only.
2. `charrettes/2026-10-chat-scope/C3/interaction-spec.md`: the person-visible rules.
3. `charrettes/2026-10-chat-scope/C4/decision-brief.md`, `C4/proposed-edits/*.md`, `C4/slices.md`: the data model, context assembly, recovery, and implementation plan.
4. The current code the edits must fit: `app/Sources/SophiaCore/NotebookStore.swift`, `Prompts.swift`, `ClaudeEngine.swift`, `Memory.swift`, `PageEdits.swift`, `RecordChecks.swift`, `app/Sources/Sophia/NotebookSession.swift`, `ConversationView.swift`, `app/Sources/sophia-mcp/main.swift`; and the current docs `DATA-MODEL.md`, `EDITING.md`, `PLAN.md`, `SOPHIA.md`.

## How to attack

For each of scenarios 2, 4, 9, and 10, trace the exact sequence of entries written to `transcript.jsonl`, `learning.jsonl`, notebook.json meta, page files, and `.previous.md`, in the order the proposed edits specify, and what each thread shows and what Sophia receives at every step. Then try to produce:

- a duplicated or lost entry after a crash at each write boundary (scenario 10), including a crash during the automatic checkpoint, during a clear (checkpoint then `clear` entry), and during a `write_page` to another page;
- a state where a thread's view and Sophia's context disagree (the marker says one thing, the context is another), for example after a failed checkpoint, a failed resume in one thread but not another, or a page rename;
- an undo that is offered but cannot be performed, or performed but not offered (scenario 9), including after relaunch and after a write from another thread;
- an "Elsewhere" line, pointer card, or per-thread cursor that is wrong or ambiguous when a reply is still streaming in P while the person sends in Q (scenario 2), or when R is created mid-stream (scenario 4);
- a rule in the C4 edits that contradicts the C3 spec, EDITING.md, or the tool boundaries in AGENTS.md (tools never delete pages or records, never mark goals, every write recorded and undoable);
- an addition (field, entry kind, record, file, mapping) that none of the eleven scenarios requires;
- any step in `C4/slices.md` whose exit check cannot be run with the commands in `app/README.md`, or whose check would pass without the slice working.

## Output

Write `/Users/justincranshaw/Projects/sophia/charrettes/2026-10-chat-scope/C4/adversarial-findings.md`. For each finding: a number, the scenario, severity (breaks the design / wrong but fixable / unclear), the exact sequence that produces it with the cited lines in the spec, the edits, and the code, and what evidence would confirm it. Mark each finding **confirmed** (you traced it to a contradiction or a lost or duplicated record) or **suspected** (plausible, not traced). Do not propose designs; one sentence on the minimal fix is enough. Make no other changes.

When done, reply with the list of confirmed findings (one line each) and the count of suspected ones.
