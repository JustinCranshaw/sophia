# C1 selection: what C2 prototypes

All three alternatives are prototyped. The operator asked that both axes be settled together, and the three alternatives are the only ones that cover both answers to each axis: A (notebook-owned, forward-only clear), B (page-owned, clear per page), C (topic-owned, resumable threads). Dropping any one would leave an answer to the operator's question untested by a render.

| File | Alternative | What the prototype must teach |
|---|---|---|
| `mock/chat-scope/anchored-stream.html` | A: Anchored stream | Whether a single stream with page stamps, an "All / This page" scope bar, collapsed topic headers, and a "Discussed 3 times" affordance makes a page's history findable without a container, and whether a months-long stream (11c) stays readable. Scenario 2 is its showcase; 5 and 11 are its stress tests. |
| `mock/chat-scope/page-owned.html` | B: Page-owned chats (the operator's lean) | Whether swapping chat with page selection reads as natural on macOS, whether the pointer card carries scenario 2 and the "Created from a conversation on 1.3" card carries scenario 4, where an in-flight P reply and its undo go when the person clicks Q, and whether the Contents chat as notebook scope reads as the place for scenario 3 and the briefing (7). |
| `mock/chat-scope/named-threads.html` | C: Named threads | Whether a Threads section plus a Book section in one sidebar reads as two selections without becoming a mode picker, whether thread naming is bearable, whether "In: …" on a page makes thread history findable, and whether scenario 3 (notebook actions landing in a topic thread) is as bad as the map says. Scenario 6 is its showcase. |

## Dropped

- **D: passage-anchored margin threads.** Dropped as a scope model in C1 with reasons from all three voices (competes for the book's width, revisions orphan anchors, "resolve" implies a review workflow, fails scenario 2). It survives only as the "Ask Sophia about this" route, which every prototype must show in scenario 1.
- **Window tabs (⌘T).** A presentation of B or C, not a different owner of the conversation. A prototype may use it if it helps, but it is not a fourth alternative.

## Conditions for C2

- Prototypes must stay distinct. In particular, B must not grow A's scope bar, and C must not auto-create threads per page (Mara's named false compromise).
- Each prototype shows the shared proposals the same way (page-owned undo on the page banner; one notebook-wide checkpoint), so they do not become differentiators.
- Each prototype shows what Sophia is given as context in its scope, because that is where A and B/C differ most and the operator will need to see it.
