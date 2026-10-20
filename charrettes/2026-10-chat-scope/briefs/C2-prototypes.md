# C2 brief: build comparable prototypes of chat scope in Sophia

You are the facilitator of a design charrette. Invoke the `three-agent-design-charrette` skill (if the Skill tool is unavailable, read `~/.claude/skills/three-agent-design-charrette/SKILL.md` and its `references/` directory) and follow it exactly.

**Team mode:** adaptive, with the trio fixed by the operator (below). **Direction:** divergent. **Delivery:** implementation (HTML/CSS prototypes are the deliverable). **Starting state:** the direction map from C1 and the operator's selection of alternatives to prototype.

Seat the three voices as Opus subagents (Agent tool, `model: "opus"`, `subagent_type: "general-purpose"`, never `fork`), keep the same three agents across rounds (SendMessage), route digests not verbatim responses. Assign **one builder per prototype file** (builders may be additional Opus subagents or the voices themselves, but never two writers on one file). You, the facilitator, own integration and the comparison document.

Project root: `/Users/justincranshaw/Projects/sophia`. Read `AGENTS.md` first.

## Read before seating the room

- `charrettes/2026-10-chat-scope/briefs/grounding.md`: how things work now, with citations.
- `charrettes/2026-10-chat-scope/briefs/scenarios.md`: the eleven scenarios and the Fourier notebook content. Use this content verbatim in every prototype so they stay comparable.
- `charrettes/2026-10-chat-scope/C1/direction-map.md` and `C1/rounds.md`: the alternatives and their scenario tables.
- `charrettes/2026-10-chat-scope/qc/C1-selection.md`: which alternatives to build and what each prototype must teach.
- `mock/index.html`, `mock/styles.css`, `mock/sidebar.js`, `mock/app.js`: the visual language to build from. **Do not edit these files.** Copy what you need; prototypes may link to `../styles.css` or inline their own copy.
- `EDITING.md` and `DATA-MODEL.md` for the rules a prototype must not contradict.

Give each voice and builder these paths, not pasted text.

## Locked constraints

Same as C1 (see `briefs/C1-direction-map.md`, "Locked constraints"). A prototype that violates one is rejected. If a voice wants to change one, record it in the handoff for the operator; do not act on it.

## The trio and their directives

- **Mara Chen (Design)** owns the rendered interface: where the chat sits relative to the book, navigation and re-anchoring, the states for scenarios 1, 2, 3, 5, 6, 7, and 11, and macOS idiom. Directive: inspect every prototype in the browser at a realistic Mac window size (about 1440×900) and name, per prototype, the rendered element that makes its premise visible and the one that undermines it. Boundary: don't rule on which scenarios are real (Marcus) or on textbook legibility (Edmund).
- **Marcus Webb (Product)** owns whether each prototype answers the scenarios it was selected to test and whether its machinery is proportionate for a solo learner. Directive: for each prototype, walk scenarios 5, 6, and 11 in the render and say whether the prototype demonstrates the case or merely labels it. Boundary: don't redesign the screen (Mara) or the prose (Edmund).
- **Edmund Farwell (Editor)** owns whether the notebook still reads as an emergent textbook as conversations multiply, and whether source evidence, the person's own words, and Sophia's interpretations stay distinguishable in each scope. Directive: read the rendered pages and chats as the person would a week later; point at the exact passage where a page stops reading as a book or where authorship becomes ambiguous. Boundary: don't decide layout (Mara) or scope (Marcus).

Persona files: `~/.claude/skills/three-agent-design-charrette/references/persona-design.md`, `persona-product.md`, `persona-editor.md`.

## The ask

One HTML/CSS prototype per selected alternative, in `/Users/justincranshaw/Projects/sophia/mock/chat-scope/<alt>.html` (file names given in `qc/C1-selection.md`). Each must:

- be built from the visual language of `mock/index.html` (same type, spacing, palette, sidebar and book treatment), self-contained enough to open with a `file://` URL;
- show scenarios **1, 2, 3, 5, 6, 7, and 11** as navigable states (the mock's `data-when`/`data-set` state mechanism or equivalent: buttons or a state strip that switches the view), using the Fourier notebook content from `scenarios.md`;
- include the empty state (a never-discussed page), the overflow state (a page with many sessions; a long notebook-level chat), and the return briefing placement;
- show, where the alternative's premise makes it matter, what Sophia is given as context (a small "what Sophia sees" inspector is acceptable if it is visibly diagnostic and not part of the product);
- keep the alternative's premise sharp. Do not borrow the other prototypes' moves to fix a weakness; record the weakness instead.

Each voice must inspect the **rendered** prototypes in a real browser, not just the source. Use the `browse` skill (gstack) or an equivalent headless browser; if neither is available, say so in the handoff and do not claim a render was reviewed. Save screenshots of every required scenario state for every prototype to `/Users/justincranshaw/Projects/sophia/charrettes/2026-10-chat-scope/C2/screens/<alt>-<scenario>.png`. Screenshots must be of the final files.

Complete at least one full build → inspect → critique → revise loop per prototype. Apply the skill's divergent exit test (including item 6: each prototype received at least one revision that sharpened its intended difference).

## Output

- The prototypes in `mock/chat-scope/`.
- `/Users/justincranshaw/Projects/sophia/charrettes/2026-10-chat-scope/C2/comparison.md`: per alternative, (a) what building and rendering it revealed that the direction map did not, (b) the scenario it fails or handles worst, with the screenshot that shows it, (c) what evidence would rule it in or out, (d) the voices' unresolved tensions, each assigned to an owner or a test. Do not rank the alternatives.
- `/Users/justincranshaw/Projects/sophia/charrettes/2026-10-chat-scope/C2/rounds.md`: opening passes and round digests, plus a list of every screenshot with the file and state it shows.

Rules: every claim points at a rendered element (screenshot path), a source location, a scenario, or an explicit assumption; no persona theater. Make no changes outside `mock/chat-scope/` and `charrettes/2026-10-chat-scope/C2/`.

When done, reply with: the prototype paths, the screenshot directory and count, how the voices and builders were run, whether every voice saw the renders (and with what tool), any locked constraint a voice wanted to change, and the result of the divergent exit test.

## Selected alternatives

All three C1 alternatives are built. Details and what each must teach are in `qc/C1-selection.md`.

| File | Alternative | Showcase scenario | Stress scenarios |
|---|---|---|---|
| `mock/chat-scope/anchored-stream.html` | A: Anchored stream (one notebook stream, page stamps, "All / This page" scope bar, ⇧⌘N New Topic divider) | 2 | 5, 11 |
| `mock/chat-scope/page-owned.html` | B: Page-owned chats (selecting a page selects its chat; Contents row owns the notebook chat; ⇧⌘N new conversation on this page; earlier conversations collapsed above) | 7, 11b | 2, 4 |
| `mock/chat-scope/named-threads.html` | C: Named threads (Threads section above Book in the sidebar; default "Notebook" thread; pages attach as chips; threads resumable) | 6 | 3, 11c |

Required in every prototype, shown the same way so they do not become differentiators: page-owned undo on the page banner (a write stays undoable until the next write to that page); one notebook-wide checkpoint; the "Ask Sophia about this" selection route in scenario 1; a small, clearly diagnostic "what Sophia sees" inspector per scope.

Do not let B grow A's scope bar, and do not let C auto-create threads per page. Use the Fourier notebook content from `briefs/scenarios.md` verbatim.
