# C2 rounds: opening passes, digests, and screenshots

This is charrette C2: adaptive team mode with the operator's fixed trio, divergent, implementation (three HTML/CSS prototypes). Prototypes are in `mock/chat-scope/`; the comparison is in [comparison.md](comparison.md).

## How it ran

- **Voices.** Mara Chen (Design), Marcus Webb (Product), and Edmund Farwell (Editor) ran as three persistent Opus subagents (`general-purpose`). The same three agents were continued with SendMessage through round 3. Each received the other two voices' digests, never verbatim responses.
- **Builders.** Three more Opus subagents (`general-purpose`), one per file:
  - builder A wrote only `anchored-stream.html`;
  - builder B wrote only `page-owned.html`;
  - builder C wrote only `named-threads.html`.
  No two agents wrote the same file. The voices wrote no repository files.
- **Facilitator.** Wrote the shared harness (`mock/chat-scope/harness.js`, `harness.css`: hash-addressed states `#s1`…`#s11c`, `/sees` inspector toggle, window sized to the viewport) and the build inputs in the session scratchpad:
  - build contract (skeleton, shared component markup);
  - canonical page bodies (P, Q, 0.3, 2.2, Contents), which builders pasted verbatim;
  - round digests;
  - rulings that kept the prototypes comparable.
  The facilitator also captured the final screenshots. No file in `mock/` outside `mock/chat-scope/` was edited.
- **Rendering.** gstack `browse` (headless Chromium) at 1440×900, with a private browser instance per agent (`BROWSE_STATE_FILE`). Pages were served by a local static server over `mock/` (`http://127.0.0.1:8765/`), because `browse` refuses `file://` paths outside its safe directories.
  - The prototypes link only `../styles.css`, `harness.css`, `harness.js`, and the mock's Google Fonts stylesheet, so they also open from `file://`. The `file://` route was not itself rendered in this charrette.
  - Every voice viewed renders in every round. Each listed which hashes it had actually viewed; these are recorded below.

## Round 0: independent opening passes (before any build)

**Mara (Design).** The only render she had seen was the existing mock. She noted that `.cols{height:880px}` plus a bar does not fit 900 px, so panes must scroll internally and anchors must land on the proof.

| | Keep | Risks | Direction |
|---|---|---|---|
| A | The composer chip "On: 1.4" under an unchanged stream | 11c collapsed headers as identical rows (medium); stamping every message is noise, so stamp only page changes (medium-low, taste) | #s2 shows in one viewport: Q, P's revision card with Undo, a "→ 1.4" boundary, and the question |
| B | The chat header names the page | In #s2 P's reply finishes off-screen and the unread dot may be too faint (high); Contents chat looking like any page chat (medium) | #s2: Q's chat is empty except the pointer card, P's row has a visible dot, and the undo's departure is shown honestly with no preview of P |
| C | Two selections visible at once | Two equal highlights read as a bug (medium-high); page chips overflow at 400 px (medium) | #s6: "Derivation check" paused with a dot, aside thread current |

Mara's test: in B #s2, can someone tell without clicking that P's reply finished and where its undo went?

**Marcus (Product).**

| | Keep | Risks | Direction |
|---|---|---|---|
| A | Clearing only moves forward | #s5 shows the divider but not its consequence (high); #s11c is a short stream with a "hundreds" caption (high) | Show the consequence of New Topic and an honestly long #s11c |
| B | Arriving at a page brings back its own conversation | "Earlier on this page: N" is only a label unless one is shown expanded (medium); #s6 must show the aside inline and record the weakness (medium) | Make the dots, cursors and "Elsewhere" lines visible so the cost of B's machinery can be judged |
| C | A paused thread can be resumed as live context | Ready-made names hide the naming cost (high); a hand-picked short thread list (high) | Show a Sophia-named thread with Rename, and an honest growing list |

Marcus's test: compare A #s6 with C #s6. If the stream returns to the swapped-sums ask as cleanly, C's showcase does not justify its machinery.

**Edmund (Editor).**

| | Keep | Risks | Direction |
|---|---|---|---|
| A | The article is identical under All and This page; stamps stay in the chat | "Discussed N times" inside the article reads as part of the page (medium); collapsed headers carry Sophia's summary unattributed (medium-high) | Headers quote the person's first message verbatim, or are labelled "Sophia's summary" |
| B | Earlier conversations are about the page, not part of it | The pointer card mistaken for a Sophia bubble (high); "Created from…" implies R carries P's discussion (medium) | Pointer cards in sans caption style, quoting the person's message verbatim |
| C | The title area stays a title | "In:" prints Sophia's reading onto the person's page (high); merely-open pages listed as discussed (medium) | "Named by Sophia" until renamed; "In:" above the article, in sans |

Edmund's rules for all three:
- page bodies byte-identical, never mentioning a conversation;
- serif means Sophia, `.words` and "your line" mean the person, `.src` means a source ("Cited, not opened by Sophia");
- Sophia's chat lines are short and never quote the person except verbatim.

Edmund's test: in #s7b and #s11b, cover the chat and attribute every visible sentence.

**What the facilitator did with round 0.**
- Turned Edmund's rules into canonical page bodies, so P, Q, 0.3 and 2.2 are identical in all three. A text comparison after the build confirmed this.
- Turned the voices' asks into a shared digest for builders, plus per-builder directives.

## Build 1 (builders' reports, digested)

- **A.** All hashes built. Weaknesses the builder recorded rather than fixed:
  - a page's history is reachable only through the filter;
  - Q's body reaches Sophia only via `read_page`;
  - finished topics are read-only;
  - the 11c headers read as near-identical rows.
- **B.** Default #s2 is the moment of arrival on Q. Weaknesses recorded:
  - the line of thought splits in #s2;
  - #s6 has no second line;
  - only ⇧⌘N bounds 11c.
- **C.** Default #s3 is the worst case (notebook actions land in a topic thread). Weaknesses recorded:
  - nothing prompts switching to "Notebook";
  - the 11c list fills the sidebar;
  - open pages attach to whatever thread is current.
- **Harness.** All three builders reported that the strip wrapped to about 110 px, which cut off composers. The facilitator fixed this in the harness: the window is now sized from the measured strip height, scene buttons wrap within the strip, and anchors subtract sticky headers. The checkpoint marker now wraps, and the popover no longer does.

## Round 1: inspection of build 1 (digests)

**Mara.** Viewed all 33 default hashes; no sub-steps or inspectors.

| | Makes the premise visible | Undermines it |
|---|---|---|
| A | #s2: card, boundary, chip | #s11c: 23 cards crowd the live topic to an empty "YOU" sliver (high) |
| B | #s2: header "1.4 · nothing yet" and the dot on 1.3 | #s7: an 8 px ring is the only route to the open question; action cards not in the direction map cover the gap |
| C | #s7b: the line "Posts to Derivation check · 1.4 joins it when you send". The thread and page selections now carry different weights, which resolved her R0 risk | #s11c: 30 threads push Book below the fold (high) |

- **Her R0 test:** half passes. The finished reply is legible; where the undo went is not.
- **Missing direction:** a chat-centred primary surface. She records it as her own tension, with no fourth build.

**Marcus.** Viewed #s5, #s6 and #s11a/b/c in all three, plus some inspectors.
- **Demonstrates or labels:**
  - A: all five demonstrate.
  - B: #s11b and #s11c only label, because they assume ⇧⌘N was pressed every session.
  - C: all five demonstrate.
- **R0 test:** A gets back to the derivation in one reply, so for a one-reply aside C's machinery is not justified. C's real case is a pause that outlives a reply.
- **Shared finding:** ⇧⌘N starts fresh before notes are written. This is a question for the operator.
- **Comparability:** notes counts and 11c projections differed between prototypes.

**Edmund.** Viewed 21 of 33.
- **Body identity:** verified.
- **His test:** A and B passed. C partly passed #s7b and failed #s11b: "In:" lists a thread, "Inverse transform sign", that never discussed 2.2.
- **Missing:** the book was not projected in 11c; the chats cite pages that do not exist (A: 3.4 and 3.5; C: 4.2).

**Facilitator rulings after round 1**, applied identically to all three:
1. One projected 11c book and totals: Feb 12, 2027; about 1,100 entries, 41 sessions, 24 checkpoints, 63 notes.
2. Fixed notes counts: 14, 16, and 63.
3. An identical 2.2 undo banner in 11b. Its Oct 14 write is still undoable under the shared rule.
4. An identical inspector line in #s5: "Not yet in notes: 9 of your messages…". There is no product UI for it.
5. Speaker labels on every exchange that is shown.
6. No chrome beyond each alternative's definition.

## Revision 1 (what changed)

- **A:**
  - #s11c anchored on the current topic;
  - #s11a defaults to arrival in All, with the filter as a sub-step;
  - #s11b gains a "filter → stream" round-trip sub-step;
  - YOU and SOPHIA labels;
  - a sticky banner strip that no longer hides text.
- **B:**
  - #s11b and #s11c default to "never pressed ⇧⌘N" (one conversation per scope, inspector capped at 40 entries), with the pressed version as a sub-step;
  - the #s7 action cards are removed;
  - #s2 gains a sub-step, "⌘[ back to 1.3";
  - sidebar titles wrap.
- **C:**
  - a #s6 sub-step, "Next day, Oct 18";
  - a #s11a sub-step in which 0.3 joins the current thread;
  - #s11c opens on a page buried under the thread list;
  - names wrap;
  - "In:" tags threads Sophia named;
  - the banner reads "Sophia's briefing".

## Round 2: inspection of revision 1 (digests)

**Mara.** Viewed 39 shots, including the new sub-steps.
- **Revision 1 sharpened all three:**
  - A: the filter-to-stream round trip;
  - B: ⌘[ shows the finished reply and its Undo;
  - C: the next-day resume.
- **What undermines each premise now:**
  - A: This-page rows are one line, so history is found but cannot be read in place.
  - B: the #s7 ring, unchanged.
  - C: the #s11c buried page selection, unchanged.
- **The B pointer-card tension:** she reversed her R0 position. The card now notes the revision with "undo is on 1.3" and has no Undo button on Q.

**Marcus.** Viewed the changed scenarios and sub-steps.
- **Demonstrations:** A's #s11a, B's #s11b and #s11c, and C's #s11a sub-step now demonstrate.
- **Sharpened:** yes, all three.
- **C's #s6 sub-step:** only partly shows what A cannot, because the "other talk" between pause and resume is not rendered. This was his one ask.
- **Evidence that would rule each in or out:** listed in comparison.md.

**Edmund.** Viewed all 33.
- **His test:** A and B pass. In C, #s7b leaves the person-named chip untagged, and #s11b still says "Inverse transform sign" discussed 2.2.
- **Ambiguity:** B's #s2 card credits the last line on 1.3 to the person alone, though the last thing that happened there was Sophia's revision.
- **Projected book:** reads as an emergent textbook; every cited page exists.
- **Asks:**
  - B: add the attribution line.
  - C: tag "named by you".
  - Facilitator: make invented person lines verbatim across all three.

**Facilitator ruling 7:** three person lines verbatim in all three prototypes:
- the Oct 16 edit message;
- the #s5 fresh-start message;
- the #s6 derivation ask.

## Revision 2 (final)

- **A:** ruling 7; #s11c opens fully below the scope bar.
- **B:**
  - Q's pointer card adds "Sophia revised 1.3 while you were away · undo is on 1.3", with no Undo button;
  - ruling 7;
  - #s3 shows all three exchanges.
- **C:**
  - the #s6 next-day sub-step shows activity in other threads after the pause, plus an inspector line contrasting it with a single stream;
  - tags "named by you", "named by Sophia", and "default thread";
  - page rows wrap;
  - #s2 opens at the revision card.

## Round 3: exit check on the final files

- **Mara.** Viewed A #s11c; B #s2 and #s3; C #s2, #s6, the next-day sub-step, and #s11c.
  - No blocking problems.
  - Distinct, coherent and comparable: yes for all three.
  - One minor bug: C #s11c opened mid-sentence.
- **Marcus.** Viewed C's #s6 next-day sub-step and its inspector, A #s6, and B #s5 and #s6.
  - C now shows a case A cannot. Qualification: A's side of the comparison appears only as an inspector line.
  - No blocking problems.
  - Each alternative states its test and the evidence that would rule it in or out.
- **Edmund.** Viewed #s2, #s5, #s6, #s7b and #s11b in all three.
  - Ruling-7 lines are verbatim.
  - His test passes in all six views.
  - Source, the person's words, and Sophia's interpretations stay distinguishable in all three.
  - One minor inconsistency: B's #s7b card lacked the new attribution line.

**After the exit check**, two non-blocking fixes were made and checked by the facilitator's render only; no voice viewed them:
- B #s7b: the same attribution line added to the Oct 17 card;
- C #s11c: the chat now opens at a message boundary.

## Screenshots

Every file below is in `charrettes/2026-10-chat-scope/C2/screens/`.
- **Capture.** The facilitator captured them from the final files, after the post-exit fixes, at 1440×900 viewport size, with no console errors.
- **Default state.** Each file shows a scenario's default state as opened by its hash.
- **Sub-steps.** Files marked "step" were captured by clicking that sub-step's button.
- **Inspector.** Files ending in `-sees` show the diagnostic "What Sophia sees" inspector, which is not part of the product.

Scenario states 4, 8, 9 and 10 have no states; the brief did not require them.

| File | Prototype | State shown |
|---|---|---|
| anchored-stream-1.png | A | #s1: selection popover on P's sinc sentence |
| anchored-stream-1b.png | A | #s1b: quote, Sophia's answer, revision card with Undo, P's banner |
| anchored-stream-2.png | A | #s2: Q in the book; same stream with P's card, "→ 1.4" boundary, Q question and answer |
| anchored-stream-2-sees.png | A | #s2 inspector |
| anchored-stream-3.png | A | #s3: notebook-level exchanges, Contents updated, g-2 provisional |
| anchored-stream-3-sees.png | A | #s3 inspector |
| anchored-stream-5.png | A | #s5: collapsed earlier topics (read-only), New Topic divider, fresh exchange |
| anchored-stream-5-sees.png | A | #s5 inspector (stream since divider; "Not yet in notes" line) |
| anchored-stream-5-step-reading.png | A | #s5 sub-step: reading an earlier topic, read-only |
| anchored-stream-6.png | A | #s6: aside and one reply in the stream, then the derivation ask again |
| anchored-stream-7.png | A | #s7: catch-up notes and briefing at the stream's end; P in the book |
| anchored-stream-7b.png | A | #s7b: Q opened first; stream and briefing unchanged |
| anchored-stream-11a.png | A | #s11a: arrival on 0.3 in All; "Not discussed yet" |
| anchored-stream-11a-step-this-page.png | A | #s11a sub-step: This-page filter, empty |
| anchored-stream-11b.png | A | #s11b: 2.2 "Discussed 4 times", This-page filter with 4 sessions; 2.2 banner |
| anchored-stream-11b-sees.png | A | #s11b inspector |
| anchored-stream-11b-step-in-stream.png | A | #s11b sub-step: Oct 10 session highlighted in All |
| anchored-stream-11c.png | A | #s11c: Feb 12 projection; collapsed topics above the current topic |
| anchored-stream-11c-sees.png | A | #s11c inspector |
| page-owned-1.png | B | #s1: P's chat with the selection popover |
| page-owned-1b.png | B | #s1b: P's chat with quote, answer, revision card; P's banner |
| page-owned-2.png | B | #s2: arrival on Q; empty Q chat with pointer card and attribution line; unread dot on 1.3 |
| page-owned-2-sees.png | B | #s2 inspector (per-scope cursor, "Elsewhere" line) |
| page-owned-2-step-answered.png | B | #s2 sub-step: Q question answered after recall |
| page-owned-2-step-back-to-p.png | B | #s2 sub-step: ⌘[ back to 1.3; finished reply and Undo |
| page-owned-3.png | B | #s3: Contents (notebook) chat with the three exchanges |
| page-owned-3-sees.png | B | #s3 inspector |
| page-owned-5.png | B | #s5: earlier P conversations collapsed, one expanded and marked read-only; new conversation |
| page-owned-5-sees.png | B | #s5 inspector |
| page-owned-6.png | B | #s6: aside inline in P's chat; return to the derivation |
| page-owned-7.png | B | #s7: lands on Contents; catch-up, briefing; amber ring on 1.3 |
| page-owned-7b.png | B | #s7b: Q opened first; briefing banner above the book |
| page-owned-11a.png | B | #s11a: 0.3 empty chat, "Ask about this page" |
| page-owned-11b.png | B | #s11b: 2.2 as one conversation across four sessions (never pressed ⇧⌘N) |
| page-owned-11b-sees.png | B | #s11b inspector (capped at last 40 entries) |
| page-owned-11b-step-pressed.png | B | #s11b sub-step: ⇧⌘N pressed each session |
| page-owned-11c.png | B | #s11c: Contents chat since Oct 1, one conversation |
| page-owned-11c-sees.png | B | #s11c inspector |
| page-owned-11c-step-pressed.png | B | #s11c sub-step: ⇧⌘N pressed each time |
| named-threads-1.png | C | #s1: popover on P; chat on the current topic thread |
| named-threads-1b.png | C | #s1b: quote in thread, 1.3 chip added, revision card; P's banner |
| named-threads-2.png | C | #s2: same thread, 1.4 chip added, revision card still visible |
| named-threads-2-sees.png | C | #s2 inspector |
| named-threads-3.png | C | #s3: worst case; notebook actions land in the topic thread |
| named-threads-3-sees.png | C | #s3 inspector |
| named-threads-3-step-notebook.png | C | #s3 sub-step: switched to "Notebook" first |
| named-threads-5.png | C | #s5: new thread "Where it fails" (named by Sophia, Rename) |
| named-threads-5-sees.png | C | #s5 inspector |
| named-threads-5-step-resume.png | C | #s5 sub-step: resuming the old thread |
| named-threads-6.png | C | #s6: aside thread current; "Derivation check" paused with a dot; "In:" lists both |
| named-threads-6-step-next-day.png | C | #s6 sub-step: next day, the derivation thread resumes with its pending question after other-thread activity |
| named-threads-7.png | C | #s7: lands on the last thread; "Sophia's briefing" banner |
| named-threads-7b.png | C | #s7b: Q opened first; banner; Q joins the current thread on send |
| named-threads-11a.png | C | #s11a: 0.3, no "In:" line; chat unchanged |
| named-threads-11a-step-first-message.png | C | #s11a sub-step: first message on 0.3 joins the current thread |
| named-threads-11b.png | C | #s11b: 2.2 "In:" lists four threads; one thread open |
| named-threads-11b-sees.png | C | #s11b inspector |
| named-threads-11c.png | C | #s11c: Feb 12 projection; 29 threads; 1.3's row below the fold |
| named-threads-11c-sees.png | C | #s11c inspector |

Count: 59 PNG files.
