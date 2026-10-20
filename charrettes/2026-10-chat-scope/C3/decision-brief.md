# Design decision: page-owned chats, with context managed by Sophia's notes

**Decision:** Every page, and the Contents row, owns one thread. Selecting a page selects its thread. Sophia's notes are the only compaction. One in-thread marker, "Sophia has your words from here on · before this, her notes ›", shows exactly where her word-for-word view begins. The bound holds when the person does nothing: notes are written automatically when the thread they are in reaches 30 entries since the latest notes. Clearing (⇧⌘N) writes notes first. Rules: [interaction-spec.md](interaction-spec.md). Prototype: `mock/chat-scope/chosen.html`.

**Why:**
- **Who and what for.** The operator chose B because a page's thread becomes part of learning dense technical content (`qc/gate1.md`).
- **The concern it answers.** C2 showed that B's bound depended on the person pressing ⇧⌘N. In `C2/screens/page-owned-11b-sees.png`, a hidden 40-entry cap silently dropped 8 entries.
- **How the existing pieces carry it.** The checkpoint already exists (DATA-MODEL.md), already writes notes under client checks, and already appears in the thread as a divider. Making it the compaction, the boundary and the visible marker adds no record type, no file and no meter.

**Confidence:**
- **Known from render.** The marker, merged clear, briefing route, amber error state and every scenario state render at 1440×900 with no console errors, and all three voices inspected them.
- **Assumed.** Notes are good enough to stand in for older exchanges. 30 and 3 are the right numbers. People read the dimmed region as "out of view", not "deleted".
- **Untested.** Real model calls. Whether provider resume after a crash fails as #s10 shows (C4).

## Keep

- The header that names the page, the pointer card's attribution line ("Sophia revised 1.3 while you were away · undo is on 1.3"), and the unread dot (from C2).
- The checkpoint divider, now the marker. Opening it lists the notes she works from.
- Page-owned undo, held until the next write to that page by either author (gate 1 assumption).
- The Contents thread as the notebook scope, under the same rule as page threads.

## Change (from page-owned.html)

1. Replace the 40-entry cap with notes as the bound. Product (Marcus), medium.
   - The automatic trigger counts only the thread the person is sending in.
   - 3 exchanges are carried above the latest notes.
   - Every checkpoint drops provider sessions in all threads, so the marker is true.
2. ⇧⌘N writes notes, then clears. This answers gate 1's "a clear never loses what Sophia learned". Product, small.
3. One marker, drawn above the carried exchanges, expandable to the notes. Subtitle: "Her notes, then your words since …". The person never sees "checkpoint", "session", "context" or "token". Design (Mara), with a vocabulary veto held by CEO (Imani). Small.
4. The briefing's page reference becomes "Go to the open question ⇧⌘J". It opens the question highlighted (#s7, #s7b), replacing C2's 8 px ring as the only route. Design, small.
5. New states: #s4 (R's thread starts with a pointer card and carries the originating exchange until the next notes), #s8 (EDITING.md refusals in the page's thread), #s9, and #s10 (amber marker plus "I couldn't reopen where we left off, so I've picked up from my notes and our last few exchanges here."). Design, medium.

## Cut or defer

- **"Work from here" and per-exchange keep/exclude.** They commit the product to a context editor (CEO). Moving the boundary per message is keep/exclude by another name (Product). Proposed by Mara in round 0, withdrawn by her in round 1.
- **Context meters, counts, `/compact`, summary records, the 40-entry cap.** All are developer-tool vocabulary or a new store.
- **Provider resume across notes.** It would make the marker untrue.
- **A second thread on a page (#s6), and chapter threads.** No demonstrated need; chapters move.
- **Visible authorship tags on edited lines.** The "your line" tag in #s8 was carried from C2; EDITING.md defers this to Phase 3.

## Remaining dissent or test

- **Operator flags (rule changes, not locked constraints):**
  - "Let Sophia change this" stays undoable until the next change to that page. This replaces EDITING.md's "until the next message"; it is a facilitator ruling to keep one undo rule.
  - Page-owned undo keeps the Oct 14 write on 2.2 undoable days later (#s11b banner), as flagged in C2.
  - The authorship tag above.
- **Notes as compaction.** Owner: Marcus. Test: on the 1.3 and 2.2 fixtures, compare Sophia's scenario 7 return from page + notes + 3 carried exchanges against her return from 40 raw entries. Imani's version of the test: rebuilt with no resume, she must resume at the swapped-sums step. Drop the rule if raw entries clearly win.
- **`recall(page:)` as the only route to older exchanges.** Owner: Marcus. Test: it must bring back a specific Oct 9 exchange on 2.2 when the person asks. If it cannot, revisit the cut of keep.
- **Dimmed means out of view, not deleted.** Owner: Mara. Test: a click-through on #s11b asking "Does Sophia have your Oct 14 question word for word?" Answers must match the inspector.
- **Latency of the automatic notes call between turns.** Owner: Marcus. Measure it in the CLI experiment.
- **Note quality now carries every long thread.** Imani prices this, not rejects it.
- **Taste, not adopted:** Imani would show note links as the first words of the source message rather than ids such as "n-31". Mara owns the call and kept the ids.
- No voice asked to change a locked constraint.
