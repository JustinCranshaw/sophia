# C3 rounds: opening passes, digests, and screenshots

Charrette C3: standard team mode (Mara Chen, Design; Marcus Webb, Product; Imani Blackwood, CEO), convergent, implementation. Starting state: the operator's choice of B and its C2 prototype `mock/chat-scope/page-owned.html`. Output: `mock/chat-scope/chosen.html`, [interaction-spec.md](interaction-spec.md), [decision-brief.md](decision-brief.md).

## How it ran

- **Voices.** Three persistent Opus subagents (`general-purpose`), one per persona, each given its persona file path, a shared frame (brief, files to read, ownership map, locked constraints, substance rules) and no pasted source text. The same three agents were continued with SendMessage in every round. Each received only the other two voices' digests, never verbatim responses. The voices wrote no repository files.
- **Builder.** One Opus subagent (`general-purpose`) was the only writer of `chosen.html`, working from a facilitator build contract (the room's committed rule, wording, states, and checks) and continued with SendMessage for revisions.
- **Facilitator.** Wrote the build contract and digests (session scratchpad), this file, the spec and the decision brief, and captured the final screenshots. `harness.js` and `harness.css` are linked unchanged; nothing in `mock/` outside `chosen.html` was edited.
- **Rendering.** gstack `browse` (headless Chromium) at 1440×900, one private browser instance per agent (`BROWSE_STATE_FILE`), pages served by a local static server over `mock/` at `http://127.0.0.1:8765/`.

## Round 0: independent opening passes (renders of page-owned.html)

| | Keep | Risks | Direction |
|---|---|---|---|
| **Mara** (viewed #s2, #s5, #s5/sees, #s7, #s11b, #s11b/sees, #s11c) | Header naming scope and state; the pointer card's attribution line; the in-stream checkpoint divider as the seed of a context affordance | The bound exists only in the inspector: #s11b/sees drops 8 entries and the product view shows nothing (high). #s5's "READ-ONLY · OUT OF SOPHIA'S CONTEXT" hides that 9 messages have no notes (high). #s7's only route to the open question is an 8 px ring (medium) | One in-thread marker of what Sophia is working from, built from the divider; default advances with checkpoints; right-click "Work from here"; ⇧⌘N writes notes first; amber marker plus Sophia's line on resume failure; R opens with a pointer card; briefing link to the question (⇧⌘J) |
| **Marcus** (viewed #s5, #s5/sees, #s11b, #s11b/sees, #s11c) | The checkpoint divider; a clear only adds a marker | The 40-entry count cap is arbitrary and invisible, and `--resume` on every turn lets the provider decide what Sophia sees (`ClaudeEngine.swift:60`, `NotebookSession.swift:97`) (high). A clear leaves 9 messages unnoted; End session is a button press too (high). The notebook chat grows without limit (medium) | Context = page, memory, her page notes, exchanges since the later of clear/checkpoint, plus a 3-exchange carry-over. Compaction is the existing checkpoint, with a size trigger at 30 entries. Every checkpoint ends provider sessions. ⇧⌘N checkpoints first. Cut keep/exclude, the cap, resume across checkpoints, summary records |
| **Imani** (viewed #s1, #s5, #s5/sees, #s7, #s11b, #s11c) | Header naming the page; the "Notes written" marker as the teacher's-notebook voice | #s5 clears before notes (high); the bound is silent, and a meter would make the person a buffer manager (high); per-page provider sessions multiply stale ids for a cache (medium) | Notes are the compaction; the marker is the line between notes and verbatim, expandable to the notes it wrote; reject meter, /compact, per-message pins, summary records, the words "session"/"context"; provider sessions a disposable cache |

Tests named: Mara, whether people read a dimmed region as deleted (#s11b click-through). Marcus, scenario 7 return from page + notes + 3-exchange tail against 40 raw entries on the 2.2 and 1.3 fixtures. Imani, scenario 7 rebuilt with no resume must pick up at the swapped-sums step.

## Round 1 digests (no render yet)

- **Mara.** Dropped "Work from here". Blocking: the visible line must be the true word-for-word boundary, so it is drawn above the 3 carried exchanges, not at the checkpoint. Wording: marker "Sophia has your words from here on · before this, her notes ›"; subtitle "This page's conversation · her notes, then your words since Oct 14"; error line "I couldn't reopen where we left off, so I've picked up from my notes and the conversation below this line." Owns line placement and wording; Imani may veto vocabulary.
- **Marcus.** Cut "Work from here" as keep/exclude by another name; the marker moves only forward, by a checkpoint or ⇧⌘N; older material returns through `recall` (reverse if `recall(page:)` cannot bring back a requested 2.2 exchange). Accepts that a notebook-wide checkpoint moves every thread's marker. Quota unchanged: 8 new notes per session, size and ⇧⌘N checkpoints share it, past it Sophia revises notes. Blocking: the marker is true only if every checkpoint drops the provider session in every scope; the inspector must show it. Numbers: tail 3 exchanges (6 entries), trigger 30 entries, no count cap.
- **Imani.** Blocking (then resolved by Mara's withdrawal): "Work from here" commits to a context editor. Background checkpoint acceptable if it reads as Sophia's notes: no toast, spinner, meter or count; drop "12 messages" from the subtitle (taste). Error wording without "session".

**Facilitator integration for build 1.** "Work from here" cut (all three). Checkpoint = compaction = boundary; triggers End session, return catch-up, ⇧⌘N, 30 entries in a thread; tail 3 exchanges; no cap; every checkpoint drops provider sessions; marker above the tail with Mara's wording; no counts in the subtitle.

## Build 1 (builder's report, digested)

All 15 hashes and 29 steps were rendered with no console errors or overflow. The marker is a native `<details>` element, and the inspector agrees with each screen.

The builder made several choices of its own:
- The "latest checkpoint in this thread" is the latest one that covered any of the thread's entries.
- The 4:12 PM trigger came from Contents reaching 30.
- ⌘L and ⇧⌘J appear only as labels.

## Round 2: build 1 inspected

- **Mara** (viewed s2 a, s4 r, s5 n, s7 a/f, s8 c, s9 p, s10 a/c, s11a a, s11b a/o).
  - Keeps the #s7 briefing route (a→f) and the #s9 p line.
  - **Blocking.** In #s10 a, Sophia says "below this line", but the amber marker is off-screen.
  - Next edits:
    - The release card's "until your next message" contradicts page-owned undo.
    - Merge #s5 n's two stacked rules into one.
    - #s4 r should use the standard marker wording.
    - The expanded heading should become "Her notes from Oct 14 · she works from these…".
    - Shorten the subtitle.
- **Marcus** (viewed s3, s4 r, s5 a/n, s9 a/p, s10 a/q/c, s11b a/o/t, s11c, all with /sees).
  - Corrected his own round-1 claim: the 8-note quota (DATA-MODEL.md:183-186) limits only the live `note` tool, so checkpoints have no quota.
  - **Blocking.** There must be one definition of the latest checkpoint. It is notebook-wide, so every thread shows the same notes date at the same moment; #s3 and #s10 c showed Oct 13 against 1.3's Oct 16.
- **Imani** (viewed s1, s4 a/r, s5 a/n, s7 a/f, s10, s11b a/o, s11c).
  - **Blocking (vocabulary veto).** "Notes this checkpoint wrote" puts "checkpoint" in product text.
  - Asked Marcus whether another thread's size should be able to dim this thread's words (#s11b t).
- **Marcus's owned call on Imani's question.** The automatic trigger counts only the thread the person is sending in. It runs between turns, still writes notes for the whole notebook, and other threads' markers move unseen until those threads are opened.
- **Facilitator ruling.** "Let Sophia change this" follows page-owned undo ("until the next change to 1.3"). This is flagged to the operator.

## Build 2

All of the round-2 edits went in:
- Imani's veto: the product text was grepped clean, and the strip button became "11b Many sittings".
- The quota lines were fixed.
- There is one notes date across threads.
- #s10 a opens on the amber marker. Because Sophia's line is not in that view, she now says "…our last few exchanges here."
- #s5 n has one merged marker, and #s4 r uses the standard marker.
- The release card's undo is page-owned.
- The trigger fires on 2.2's own count.

**Rendering caveat found in round 3.** The browse instances served a cached build 1 to all three voices. Each voice discarded that pass and re-rendered with a cache-busting query (`?v=…`), and each confirmed build 2 from #s11b t's Look-at line.

## Round 3: build 2 and the spec draft inspected

- **Mara** (viewed every hash and step, cache-busted).
  - **Blocking.** The spec's "30 entries past its marker" contradicts its own "about 36" and #s11b. The count must start at the latest notes, not at the marker.
  - Next edits:
    - Shorten the Contents subtitle.
    - Give ⌘L a visible label.
    - Remove the "22 messages" count.
- **Marcus** (viewed s3, s5 n, s11b t, s10 a/c, s7 f, s11c, s2 b, cache-busted).
  - **Blocking.** The Contents inspectors contradicted the spec: they said "any thread" for the trigger and listed "notes on this thread". Contents has no page notes.
  - Proposed a failure sentence for the spec, which was adopted.
- **Imani** (viewed s1, s4 a/r, s5 n, s7 a/f, s7b, s8 c, s10 a, s11b o/t, s11c, cache-busted).
  - No blocking objection. Her veto is met.
  - Commitments priced:
    - note quality now carries long threads;
    - the trigger adds a model call between turns;
    - the release undo changes EDITING.md.
  - Taste: note links should show the first words of their message rather than ids. This went to Mara, who did not adopt it.
  - Exit test: passes.

## Build 3, and the final check

The trigger now counts 30 entries since the latest notes. The Contents inspectors and subtitles were fixed, the ⌘L tooltip was confirmed, and every count was removed from product text. The spec was updated to match.

| Voice | Viewed (`?v=b3`) | Blocking | Exit test |
|---|---|---|---|
| Mara | s3, s5 n, s7 a, s10 a/c, s11b a/o/t, s11c; read spec and brief | none (taste: "Earlier on this page: 3 conversations" still carries a count) | pass |
| Marcus | s3, s11b a/t, s11c, s10 c, all /sees; read spec and brief | none | pass |
| Imani | s11b a/o/t, s11c, s10 a, s5 n; read the brief | none | pass |

## Convergent exit test

It passes.

1. **Shared problem.** All three solved the same problem: a solo learner's page thread running for weeks, and what Sophia works from in it.
2. **Coherent direction.**
   - The premise: notes are the only compaction, and one marker shows the truth.
   - The refusals: no context editor, meter, summary record or cap.
3. **Blockers.**
   - Every blocker from rounds 1–3 was answered in the build or the spec: "Work from here", the true line position, provider sessions dropped at each checkpoint, the #s10 off-screen line, the vocabulary veto, one notes date, the Contents inspectors, and the trigger's starting point.
   - The remaining questions are converted to owned tests in the decision brief.
4. **Cuts.** They are explicit in the spec and the brief.
5. **Artifact verified.**
   - All three voices inspected build 3, the final file, in the browser at 1440×900.
   - Three revisions followed critique.
   - The facilitator's final screenshots were taken from that same file, with no console messages.
   - **Limitations of direct inspection:**
     - Keyboard shortcuts are labels only; no key handling is implemented.
     - The #s7b banner link is inert, because the harness cannot change scenario and step in one click.
     - Nothing was tested with real model calls, VoiceOver, or a person.

## Screenshot index (`screens/`, final file, 1440×900)

Scenario states: `chosen-1`, `-1-asked`, `-1b`, `-2`, `-2-answered`, `-2-back`, `-3`, `-4`, `-4-open-r`, `-5`, `-5-cleared`, `-6`, `-7`, `-7-followed`, `-7b`, `-8-open`, `-8-committed`, `-8-protected`, `-9`, `-9-back-on-p`, `-10`, `-10-q`, `-10-contents`, `-11a`, `-11a-first`, `-11b`, `-11b-notes`, `-11b-auto`, `-11c`.

Inspector ("What Sophia sees", diagnostic) views: `-2-sees`, `-3-sees`, `-4-open-r-sees`, `-5-cleared-sees`, `-8-committed-sees`, `-9-back-on-p-sees`, `-10-sees`, `-11b-sees`, `-11b-auto-sees`, `-11c-sees`.

## Post-exit QC fix (spec only)

The orchestrator's QC found that the spec had no rule for the "Continuing from" pointer card. I added a "Pointer card" rule to the spec's "Threads, switching, history" section and trimmed other wording to stay under the cap. The new rule also says the "Started from" card on a new page is derived from the `write_page` entry that created the page and is kept permanently.

chosen.html and the screenshots were not changed. The voices did not review this addition.

**Known difference from the render.** In #s9 the card on 1.4 is shorter than the rule requires: it reads "Sophia revised 1.3 · undo is on 1.3 ⌘[" and has no "Your last message there" line. Under the rule it would show the full card: the "Continuing from 1.3" line, the person's last 1.3 message, and "…while you were away · undo is on 1.3".
