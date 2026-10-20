# Operator gate 1 (2026-10-19)

**Decision:** B, page-owned chats. The operator's reasoning, in their words: "B is still better for learning dense technical content. The conversation thread on a page becomes part of the learning process. But we do need to be conscious of context length, and how the user manages context within a page thread."

**What this adds to C3's remit:** context length is a first-class design problem. The spec must say how much of a page thread Sophia receives, what bounds it, how the person sees and manages that context (clearing, compaction, keeping or excluding exchanges), and how this stays free of a mode picker.

**Flags not explicitly ruled on, and the working assumptions C3 proceeds under (the operator can reverse either at gate 2):**

1. **Page-owned undo** ("until the next write to that page, by either author"): assumed adopted, because every prototype already used it and B's scenario 9 depends on it. C4 owns the crash-survival claim.
2. **Clearing before notes:** the operator reaffirmed that the thread is part of the learning process, so C3 treats "a clear never loses what Sophia learned" as a requirement and must specify whether a clear writes notes first, or how else that holds.
3. C-only flags (thread names in notebook.json, attachment rule): moot.

**Dropped:** A and C. Nothing from them is to be merged into B. Their records stay in C1 and C2 for reference.
