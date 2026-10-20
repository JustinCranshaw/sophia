# C2 comparison: three rendered prototypes of chat scope

Implemented:
- `mock/chat-scope/anchored-stream.html` (A)
- `mock/chat-scope/page-owned.html` (B)
- `mock/chat-scope/named-threads.html` (C)

All three share `harness.js` and `harness.css`. Open a scenario by its hash (`#s1` … `#s11c`). Add `/sees` for the diagnostic inspector.

The three alternatives are not ranked. Process, round digests and the screenshot index are in [rounds.md](rounds.md). Screenshots are in `screens/`.

**Shared by all three, so not a differentiator:**
- page bodies identical (checked by text comparison and by Edmund);
- undo owned by the page (P's banner, plus the 2.2 banner in 11b);
- one checkpoint marker for the whole notebook;
- the "Ask Sophia about this" popover;
- the two-sentence briefing text;
- one projected book for 11c (Feb 12, 2027; about 1,100 entries, 41 sessions, 24 checkpoints);
- the same three invented person lines.

## A: Anchored stream

**Premise:** the conversation belongs to the notebook. A page is context that travels with each message.

**What building and rendering it revealed that the direction map did not**
- **Scenario 2.** At 1440×900 the premise fits in one chat column: P's revision card and Undo, a "→ 1.4" boundary, the Q question and its answer, and the chip "On: 1.4" (`screens/anchored-stream-2.png`). Mara names this the element that makes the premise visible.
- **Scenario 6.** The aside is no stress case. One reply, then Sophia re-asks the swapped-sums step (`screens/anchored-stream-6.png`). Marcus: for a one-reply aside this is as clean as C's thread.
- **Finding history.** The direction map's "This page" filter does find a page's history (`screens/anchored-stream-11b.png`). But the rows are one line each, so history is found but cannot be read in place. The person has to go round-trip into the stream (`screens/anchored-stream-11b-step-in-stream.png`). The map did not show that A's history needs two hops.
- **Scenario 11c.** When the stream opens at the top, months of collapsed topics crowd out the live topic. Build 1 showed 23 headers and an empty "YOU" sliver. Anchoring on the current topic fixes the first view, but then only about two headers are visible (`screens/anchored-stream-11c.png`). Collapsing alone bounds the stream for the person but does not make it navigable.
- **Clearing.** "New Topic" starts fresh before notes are written: 9 messages are not yet in notes (`screens/anchored-stream-5-sees.png`). The same is true of B (Marcus's finding).

**Scenario it handles worst:** scenario 11c, with 11b close behind.
- In `screens/anchored-stream-11c.png`, 24 topics over four months reduce to near-identical one-line headers above the current exchange. The only bound is collapsing.
- In `screens/anchored-stream-11b.png`, 2.2's four sessions are reachable only through the filter.
- Marcus's earlier view, scenario 5 ("readable, not resumable"), is demonstrated honestly in `screens/anchored-stream-5.png` and `-5-step-reading.png`. He judged it acceptable once rendered.

**Evidence that would rule it in or out**
- **In:** Marcus's tagging test, on a real multi-week notebook, finds that sittings regularly cross pages.
- **In:** Mara's scenario 2 click-through finds that people expect P's exchange to stay on screen after clicking Q.
- **Out:** people looking for "what we said about 2.2" fail or give up at the filter-to-stream round trip.

## B: Page-owned chats

**Premise:** a discussion lives with its page. Selecting a page selects its chat; the Contents row owns the notebook chat.

**What building and rendering it revealed that the direction map did not**
- **The swap is legible.** The chat header names the page ("1.4 Sampling and aliasing · nothing yet"). Q's pointer card quotes the person's last message on 1.3, and 1.3's row carries a blue unread dot (`screens/page-owned-2.png`).
- **Where the undo went was not legible** until the pointer card said "Sophia revised 1.3 while you were away · undo is on 1.3", without an Undo button on Q. Mara and Edmund converged on that line, Mara for layout and Edmund for authorship. The direction map's "undo moves to P's banner" is invisible from Q unless the card says so. The ⌘[ return shows the finished reply and its Undo (`screens/page-owned-2-step-back-to-p.png`).
- **The bound rests on behaviour.** B's 11b and 11c only label their bound if the person presses ⇧⌘N every session (Marcus, round 1). Rendered with no presses, 2.2 is one 48-message conversation across four sessions (`screens/page-owned-11b.png`), and the inspector cap of 40 drops 8 of them (`screens/page-owned-11b-sees.png`). B's overflow story depends on a behaviour the map assumed.
- **Return.** When the person returns, the open question lives in 1.3's chat, but they land on Contents. The only route from there is a small amber ring on 1.3's sidebar row (`screens/page-owned-7.png`). The build-1 "Open 1.3 and answer" cards hid this; they were removed as outside B's definition.
- **Notebook scope.** Contents as the notebook scope reads as distinct once its header is tinted "Fourier analysis · whole notebook" (`screens/page-owned-3.png`). That answers Mara's round-0 risk.

**Scenario it handles worst:** scenario 2, then 7.
- **Scenario 2.** In `screens/page-owned-2.png`, the question about Q depends on the discussion of P but lands in Q's empty chat. Sophia gets only an "Elsewhere" line and must recall 1.3 (`screens/page-owned-2-sees.png`, `-2-step-answered.png`).
- **Scenario 7.** In `screens/page-owned-7.png`, the briefing sits on Contents while the open question is behind an 8 px ring.
- **Scenario 6.** It has no second line on a page (`screens/page-owned-6.png`). The aside goes inline, the same as in A, and the builder recorded it rather than inventing threads.
- **Scenario 4.** It was not built, because the brief required no hash for it. The "Created from a conversation on 1.3" card remains untested.

**Evidence that would rule it in or out**
- **In:** the tagging test finds that most sittings stay on one page, and people come back to a page by opening it.
- **In:** people press ⇧⌘N without being prompted.
- **In:** in Mara's click-through, people expect a blank Q chat.
- **Out:** sittings regularly cross pages.
- **Out:** people never press ⇧⌘N, which leaves one ever-growing conversation per page with Sophia's context capped (`screens/page-owned-11b-sees.png`).

## C: Named threads

**Premise:** a conversation belongs to a topic the person names. It can span pages and can be paused and resumed as live context.

**What building and rendering it revealed that the direction map did not**
- **Two selections need different weights, and can have them.** The thread selection is outlined with a blue rule; the page selection is a grey fill (`screens/named-threads-1.png`). Mara withdrew her round-0 risk.
- **"Posts to <thread>" carries C on screen.** The line under the composer reads "Posts to Derivation check · 1.4 joins it when you send" (`screens/named-threads-7b.png`). Mara names it C's premise-making element. It was not in the direction map.
- **Scenario 6 has to be shown at the right length.** A one-reply aside does not justify threads. Marcus's round-1 test: A recovers as cleanly (`screens/named-threads-6.png` vs `screens/anchored-stream-6.png`). C shows a case A cannot only when the pause outlives a day of other talk. That is the next-day sub-step: 22 messages in other threads, and the derivation thread still ends on its pending question (`screens/named-threads-6-step-next-day.png`). Marcus's qualification: A's side of that comparison appears only as an inspector line.
- **Naming has an authorship cost, not only an effort cost.** Sophia's thread names are her reading of what the person is pursuing, and they print onto the page's "In:" line. They became attributable only with tags: "named by Sophia", "named by you" and "default thread" (`screens/named-threads-11b.png`).
- **The attachment rule creates false history.** A page that was merely open when a message was sent joins the thread. 2.2's "In:" lists "Inverse transform sign" though that thread never discussed 2.2 (`screens/named-threads-11b.png`, Edmund). Read literally, the rule also attaches pages Sophia writes, which would give 0.3 "In: Notebook".
- **Scenario 3 is as bad as the map said, and nothing in the UI mitigates it.** With Contents open, the reorganisation and the goal change land in "Filters as products". "Notebook" still says Oct 15 (`screens/named-threads-3.png`), and nothing prompts the switch (`screens/named-threads-3-step-notebook.png`).

**Scenario it handles worst:** scenario 3, with 11c close behind.
- **Scenario 3.** In `screens/named-threads-3.png`, notebook-level actions scatter into a topic thread.
- **Scenario 11c.** In `screens/named-threads-11c.png`, 29 threads push the Book section and the selected page row (1.3) below the fold, so the second selection disappears. Eight open-question dots compete. Mara rates this "breaks the flow; high".

**Evidence that would rule it in or out**
- **In:** Marcus's sitting test, on a real notebook, finds frequent topic resumes that span pages, with other talk in between.
- **Out:** resumes are rare, which would make C, in Marcus's words, "A plus a list nobody uses".
- **Out:** people often send notebook-level requests from a topic thread, which would show in a count of misfiled `set_chapter`/`set_goal` calls.
- **Out:** a count of "In:" entries in a real notebook with no message about that page (Edmund) shows how much false history the attachment rule creates.

## Unresolved tensions

| Tension | Positions | Owner or test |
|---|---|---|
| Does clearing (⇧⌘N or New Topic) write notes first? | Marcus: scenario 5 says Sophia keeps what she learned, but A and B clear with 9 messages not yet in notes (`screens/anchored-stream-5-sees.png`, `page-owned-5-sees.png`). The shared proposal says clearing never runs a checkpoint. | **Operator** (rule decision). Not a locked constraint. |
| Primary surface: book-centred or chat-centred? | Mara: all three put the book in the centre, as the mock does; the app puts the chat there. That untested layout may change whether B's swap and C's two selections read. | **Mara.** Test: render B #s2 and C #s11c with the chat in the centre. |
| C's attachment rule: should a merely-open page join a thread? | Edmund: it prints false history onto the page (`screens/named-threads-11b.png`). Builder C kept the direction map's rule and recorded the weakness instead of fixing it. | **Operator** rules on the rule. Test: Edmund's "In:" audit on a real notebook. |
| B's bound depends on the person pressing ⇧⌘N. | Marcus: unless people press it, B's 11b and 11c are one capped conversation per scope. | **Marcus.** Test: observe whether people press ⇧⌘N unprompted. |
| A's history needs two hops (filter, then stream). | Mara: the This-page rows are one line, so history cannot be read in place (`screens/anchored-stream-11b.png`). | **Mara** owns any layout change within A. Test: a scenario 11b retrieval task ("what did we conclude about padding?"), timed in A against B. |
| Is C distinct enough from A to earn its machinery? | Marcus: only if pauses outlive other talk. The next-day sub-step shows the case, but A's side of it is only an inspector line. | **Marcus.** Test: the sitting test. Cheaper alternative: a matching A screen with the same 22 intervening entries. |
| B's notebook scope lands the person away from the open question (scenario 7). | Mara: the amber ring alone is B's honest cost. Adding action cards would be a fix outside B's definition. | **Mara.** Test: a click-through in B #s7. Does the person find 1.3's open question without help? |

## Locked constraints

No voice asked to change a locked constraint.

Operator flags:
- The shared page-owned undo rule makes the Oct 14 write on 2.2 still undoable three days later. A green "✓ Sophia revised" banner is shown on 2.2 in 11b in all three prototypes (`screens/*-11b.png`). This is a visible consequence of changing `DATA-MODEL.md:125` / `EDITING.md:42`, which C1 already flagged.
- The ⇧⌘N-before-notes question above.

## Divergent exit test

It passes.

1. **Range.** Three owners of the conversation: the notebook (A), the page in view (B), and a named topic (C). They give opposite answers on clearing versus resuming.
2. **Integrity.** No prototype borrowed another's move.
   - B has no scope bar.
   - C creates no thread per page.
   - Weaknesses were recorded rather than patched with another alternative's mechanism: B's scenario 6 aside, C's scenario 3 and attachment rule, and A's read-only topics.
   - Mara confirmed this in round 3.
3. **Comparability.** The three use the same content, page bodies, shared components, projection, counts, person lines, window and viewport. Facilitator rulings 1–7 are recorded in rounds.md.
4. **Tensions exposed.** See the table above. Each tension has an owner or a test.
5. **Learning value.** Each alternative states what it would test and the evidence that would rule it in or out (above). Marcus confirmed this in round 3.
6. **Artifacts verified.**
   - All three voices inspected rendered versions in every round with gstack browse at 1440×900, and each said which hashes it viewed.
   - Each prototype received revisions that sharpened its intended difference, and all three voices confirmed this in round 2:
     - A: the filter-to-stream round trip, and 11c anchored on the live topic;
     - B: the "never pressed ⇧⌘N" overflow, the ⌘[ undo route, and the attribution line on the pointer card;
     - C: the next-day resume with talk in between, the visible join on first message, and the naming tags.
   - **Disclosure.** Two non-blocking fixes came after the round-3 exit check: B #s7b's card line and C #s11c's scroll position. Only the facilitator's final screenshot pass rendered them; no voice viewed them.
