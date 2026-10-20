# Working on Sophia

## Project and sources of truth

Sophia is a personal research and learning notebook: a wise teacher, Socratic thought partner, and research assistant. Conversation drives inquiry; the person and Sophia negotiate what becomes a durable page.

Read these before changing the product or its architecture:

- [PLAN.md](PLAN.md): requirements, proposed architecture, experiment, evidence, and unresolved decisions.
- [SOPHIA.md](SOPHIA.md): the product companion's initial system-prompt candidate.
- [DATA-MODEL.md](DATA-MODEL.md): the notebook's files and record shapes, who may write each, and the checks the client enforces.
- [mock/index.html](mock/index.html): HTML/CSS mock of the intended experience. It is a design reference, not application code.

The user's latest instructions take precedence over earlier proposals. PLAN.md is a reviewed draft, not proof that an integration works or that provider permission has been obtained. SOPHIA.md describes the product's runtime behavior; its tool restrictions do not prohibit development agents from using shell commands to build and test the project.

## Product principles

- Build for personal usefulness first. The eventual application should feel at home on macOS.
- Organize a Library into Notebooks, optional Chapters, and Pages. Let structure emerge from inquiry.
- Adapt between explanation, thoughtful challenge, and research. Do not impose a lesson, examination, mode picker, or page-creation task on every conversation.
- Questions flow both ways. Offer understanding checks when useful; do not use question quotas or infer mastery from reading or agreement.
- Preserve source evidence, the person's actual statements, and Sophia's interpretations as distinguishable material.
- Keep the return experience concrete: the open question, relevant prior idea or attempt, uncertainty, and a useful next step.
- The notebook is an emergent textbook: it grows page by page as the person directs the inquiry. Sophia may suggest directions for the person to choose, but does not write ahead of them or fill out a predetermined curriculum.
- The conversation sits beside the book. Sophia writes and revises pages directly as the conversation calls for them; the person can undo or ask for changes. She also records the person's goals as she hears them, provisional until the person confirms.
- The person can edit pages directly, a section at a time, in a byte-exact source editor; Sophia must not overwrite their edits. See [EDITING.md](EDITING.md). A social platform is outside the initial scope.

## Current implementation priority

The Mac app is in [app/](app/README.md), which documents its build, run, and check commands. Inspect the actual tree as implementation develops; do not invent existing commands or infrastructure.

The next milestone is the small Claude-only command-line experiment in PLAN.md. Prove effective companion instructions and an actual model call to Sophia's HTTP MCP proposal handler before investing in SwiftUI, Codex parity, or additional persistence machinery.

Use the exact package baselines in PLAN.md and retain a lockfile when dependencies are introduced. Record the actual adapter, SDK, Node, and launched engine versions. Do not assume the globally installed CLI is the binary an adapter uses. Avoid deprecated adapter packages, unpinned `latest`, and preview dependencies unless the task specifically requires evaluating them.

## Implementation boundaries

- Notebook tools may read pages, write or revise pages, group pages into chapters, record provisional goals, write or revise Sophia's own notes and working memory, and propose lines for "About you" and links between notebooks, all through the stores' checks and locking. Across notebooks, Sophia sees only titles, and reads another notebook's page only through a link the person confirmed; a notebook kept separate is invisible to the others. They must not delete pages, remove the person's records, change lines the person wrote or edited on a page, or mark goals met or dropped.
- Every page write must be recorded and undoable (a revision keeps the previous version). Only the person confirms a goal.
- Keep the initial storage small: Markdown pages, ordering metadata, transcript and learning JSONL, and one previous page version. Add complexity only for a demonstrated failure or workflow.
- Configure the experiment explicitly rather than inheriting personal hooks, skills, instructions, or permissive tool settings. Prefer per-process configuration over modifying global agent settings.
- Prevent silent fallback from intended subscription usage to separately billed API usage. Never extract subscription tokens, copy authentication caches into the project, or log credentials.
- Treat retrieved content and model output as untrusted input. Generated artifacts require a separate restricted viewer before execution; pages containing code do not authorize running it.
- Successful login, an advertised capability, and a real successful tool invocation are different evidence. None establishes commercial authorization.
- Recheck current primary documentation when changing provider access assumptions. Do not contact providers or send external messages without explicit authorization.

## Verification and handoff

Use disposable notebooks and non-sensitive material for experiments. Follow PLAN.md's focused checks for tool delivery, page write and undo behavior, effective capability limits, denial, cancellation, restart, billing attribution, and companion usefulness.

Run checks appropriate to the change. As code is introduced, document its real setup, run, and test commands. Do not add a test framework for documentation-only work or repeat empty-session probes as evidence that the learning loop works.

Report observed results separately from reviewer reports, source inspection, inference, and untested behavior. Mark unavailable billing evidence as inconclusive. Describe failures directly; do not claim a live experiment passed when only metadata or initialization was checked.

Keep changes narrow and readable. Update PLAN.md or SOPHIA.md when the corresponding decisions or companion behavior change, without duplicating their full content here.
