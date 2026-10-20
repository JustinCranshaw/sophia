# C4 rounds: data, agent context, and recovery

## Frame

- **Team mode:** adaptive, trio fixed by the operator: Devon Reyes (coding coach: context assembly, provider sessions, resume detection), Nadia Okafor (media systems engineer, directed at data contracts: records, crash ordering, recovery, migration), Marcus Webb (product: minimum machinery, slice order).
- **Direction:** convergent. **Delivery:** review-only; the voices were read-only and the facilitator wrote every file in `C4/`.
- **Starting state:** the C3 interaction spec and decision brief, `qc/C3.md` "Carried to C4", the grounding and scenario briefs, the four docs, and the code named in the brief.
- **How the voices ran:** three Opus subagents (`general-purpose`, never `fork`), each given its persona path, a shared frame file (scratchpad, not in the repo), a remit card and the source paths. The same three agents continued across rounds through SendMessage; each round sent a voice only the other two voices' digests. Openings were independent.
- **Deviations, disclosed:** the opening pass allowed a 500 to 600-word **Spec** block beyond the 350-word cap, because the brief's directives (context composition, the scenario 10 walk, the slice table) could not fit. Round 4 was a fourth cross-critique cycle beyond the default three, opened because round 3 produced one new blocker (a crash point) and one ruling that the facilitator found rested on an incomplete premise (see round 4). Several voices also sent copies of their replies to the facilitator's own address; those were the same text and were not routed further.

## Opening passes (independent)

**Devon.**
- **Proposal:** run one live engine per thread touched since the last checkpoint. Checkpoint and briefing run in a one-shot engine whose id is never stored.
- **Why the one-shot engine:** today both requests go through the conversation engine, and `.started`/`.turnDone` overwrite `claude_session` (NotebookSession.swift:117, :163, :261, :272).
- **Order of work:** build always-reconstruct first, because spec:66 requires it as the fallback anyway. Keep a resume map only if the sentinel test passes.
- **Failed resume:** nothing detects it today. `.exited` drops the request, and the next send resumes the same stale id (NotebookSession.swift:97, :174-187).
- **Detection rule he proposed:** before `.started(R)`, any `.exited`, `.turnDone(isError)`, or `.started` with another id.
- **Token estimates:** about 8.6k to 13.7k per page-thread rebuild and 7.2k to 12.3k for Contents; resume about 8k to 17k. Only the SOPHIA.md byte count (15,118) was measured.
- **Context layout:** `Prompts.context`, then a thread block. The per-message prefix is afterQuiet, resume notice, `bookChanges(cursor(T))`, `elsewhere(T)`, music, selection, text.

**Nadia.**
- **The tag:** `page: <file>` on every conversation entry; file names are stable (NotebookStore.swift:426-428; `set_chapter` only reorders). sophia-mcp entries carry only `session` (main.swift:13, :195, :212, :254, :263), so she proposed a third launch argument.
- **Legacy entries:** untagged means Contents, so there is no rewrite.
- **Clear:** a `clear` client entry rather than a new session (DATA-MODEL.md:190; quote scope and note quota key on session).
- **Map:** a `claude_sessions` map in notebook.json.
- **Anchor:** the window must count from the index of `through`, not the checkpoint entry. A message sent while notes run lands between them (NotebookSession.swift:214 vs :295).
- **Undo:** derived from `isLatestWrite` and the files on disk.
- **File names:** `uniqueFile` must skip names already in the transcript (NotebookStore.swift:605-611).
- She also proposed a byte-identical guard and walked scenario 10.

**Marcus.**
- **Stored additions:** only two, the `page` tag and `clear`. Everything else is derived: pointer card, Elsewhere, marker, undo, interrupted, Started-from.
- **Struck:** the MCP argument (unless sends overlap), a stored cursor, persisted undo storage, and a migration step.
- **recall:** `recall(page:)` matches notes only (Memory.swift:96-99); it must return tagged messages.
- **Slices:** S1 (tag, filtered view, derived undo) is usable on its own.

## Round 1

Facilitator questions: Q1 engine topology; Q2 the third argument; Q3 whether the map is reachable; Q4 the window anchor; Q5 the open-question derivation; Q6 the guard and `uniqueFile`; Q7 the legacy `recall` gap.

**Devon.**
- **Turns:** one turn at a time notebook-wide is enough; spec:9 requires a reply to finish, not overlapping sends. Widen `canSend` (NotebookSession.swift:194) so Q's composer works in #s2.
- **Third argument:** conceded the strike.
- **Map:** none. A planned rebuild shows nothing.
- **Anchor:** agreed on `through`.

**Nadia.**
- **Blocking objection:** the `through` anchor. Settled by agreement.
- **Third argument:** keep it (it breaks if sends overlap or an orphaned `claude` writes).
- **Carried exchanges:** they come after T's latest clear.
- **Open question:** the first `t-` ref in the briefing that is a Sophia message with no later person message in its thread.
- **Guard:** struck (power-loss only).
- **`uniqueFile`:** kept (#s4, #s9).

**Marcus.**
- **Third argument:** withdrew his strike. `send()` appends the person entry before checking the queue (NotebookSession.swift:214-221), so a Q message lands among P's later MCP entries, which breaks #s4's card.
- **Engines:** accepted per-thread engines.
- **Guard:** struck.
- **`uniqueFile`:** kept (#s11a, spec:7).
- **Legacy `recall` gap:** accepted; `recall(words:)` still finds legacy messages.
- **New blocking objection:** a crash between a revision's page write and its entry (NotebookStore.swift:398) makes W0 look latest. Its derived Undo then silently reverts the unrecorded W1.

Facilitator observation, routed: the `send()` ordering also refutes Devon's concession, so it went back to him.

## Round 2

**Devon.**
- **Third argument:** withdrew the strike.
- **Quiet rebuild:** not honest after a relaunch. Tool and search results the old engine held are gone (PLAN.md:189, SOPHIA.md:97).
- **Amber rule (derived):** amber when T has a person or sophia entry after `through`, after T's latest clear, from an earlier launch.

**Nadia.**
- **Crash case:** fixed with one field, `hash` (SHA-256 of the bytes written) on `write_page` and `edit_page`. Undo requires that the hash still matches the page.
- **Rejected:** mtime vs `at` (`at` is whole seconds, NotebookStore.swift:75) and a recovery entry on open.
- **After such a crash:** P keeps W1's text, with no card, no Undo, and "interrupted".

**Marcus.**
- **Amber on relaunch:** opposed. It shows after every quick relaunch, a rebuild holds what the marker states (spec:32), and amber belongs to an attempted resume (spec:66).
- **Slices:** S1 through S8, with the map gated as S8.

## Round 3

**Marcus.**
- **`hash`:** keep (#s10).
- **Amber:** recorded dissent, not blocking.
- **Slices:** S4 becomes interrupted plus amber.

**Devon.**
- **Narrowed rule:** amber only when T has an earlier-launch WebSearch entry after `through`. Search results are not stored (NotebookSession.swift:133).

**Nadia.**
- **Final walk:** found one more crash point. Between the copy to `.previous.md` and the page write, W0's Undo would record `undo_page` and change nothing.
- **Fix:** Undo also requires `.previous.md` to differ from the page.
- **One-shot engine:** its sophia-mcp gets no third argument, so its entries belong to Contents.
- **"Ask again":** needs nothing new.
- **Migration:** the legacy `claude_session` is ignored and not removed.

## Round 4 (extension)

**Facilitator evidence, verified in source:**
- sophia-mcp writes no transcript entry for `read_page` (main.swift:187) or `recall` (:234). So Devon's WebSearch-only rule misses losses that no record reveals.
- Nadia's guard covers a crash point the `hash` misses.

**Devon:** returned to the round-2 rule (option a). The predicate is in the decision brief. Option (c), logging reads, was rejected as storage no scenario requires.

**Marcus:** keep the guard. A false `undo_page` is a false statement about the book (#s10). Its crash case goes into S1.

## Convergent exit test

1. **Shared problem: pass.** All three solved the C3 spec's threads with the same scenarios (2, 4, 9, 10 explicitly).
2. **Coherent direction: pass.** Store only `page`, `clear` and `hash`, and derive everything else. Always rebuild from storage, and treat a provider session as a cache that is not kept across checkpoints or launches. Refused: a session map, stored cursors, summary records, logging reads, a migration step.
3. **Blocking objections resolved: pass.**
   - The `through` anchor: agreed.
   - Crash-undo: fixed by `hash`.
   - Copy-then-crash: fixed by the guard.
   - Third argument: kept on evidence.
   - Amber: owned by Devon and ruled.
4. **Cuts are explicit: pass** (decision brief, "Cut or defer").
5. **Artifact verified: not applicable** (review-only). The facilitator checked every cited line used in the brief against source. Nothing was run, including the sentinel test.

**Remaining dissent:** Marcus (amber after quick relaunches; settle by a week's count), owned by Devon.

## Revision 1 (after the adversarial review)

The coordinator returned 19 confirmed findings and 7 suspected ones (`adversarial-findings.md`). The same three agents were resumed and given only the items in their own remit, each with the facilitator's proposed rule.

**Nadia (record contracts and crash ordering).**
- **Accepted:** items 2, 7, 10, 11, 14, 15, S-c, S-d and S-e.
- **Amended item 1:** an `undo_page` takes the thread of the entry it undoes, and an `undo_release` takes the released edit's file (PageEdits.swift:302).
- **Amended item 12:** a checkpoint fails only on a turn error or an unparsable reply. A reply whose records are all rejected still succeeds, because retrying would resend the same input on every turn. This is accepted as a limitation.
- **Amended item 16:** the recovered entry is `role: client` with `tool: "write_page"`, because the author is unknown.
- **Re-asserted** the `.previous.md` difference guard.
- **Follow-up from the facilitator:** recovery would skip a page whose latest entry is an `undo_page`. She ruled that `undo_page` carries the `hash` of the restored bytes; for an undo that removed a new page, the expected state is no file.
- **Scenario 10 write order:** M → copy to `.previous.md` → page file → notebook.json → `write_page{hash}` → Sophia text → `replied`.

**Devon (context and engines).** He accepted items 3, 6, 8, S-a and S-g, with amendments:
- **Item 4:** a line, not the body, which would cost about 1.2k tokens per turn. Undos of such revisions also get a line.
- **Item 5:** writes to T's own file are left out of Elsewhere.
- **Item 8:** "previous turn" means the previous person message.
- **Item 13:** only person and Sophia entries without `purpose` count.
- **S-f:** a `t-` reference counts only when it is a message tagged with the page.

He confirmed that `page: ""` and `replied` don't break the context rules, and wrote the operator paragraph.

**Marcus (minimality and slices).** He kept all five additions, each tied to a scenario:
- `replied` (#s4, #s10);
- `page: ""` (the legacy cutover for "interrupted", #s10);
- `recovered` (AGENTS.md, #s10);
- the end of a new page's Undo (#s4, #s9, spec:64);
- `clear` before its checkpoint (finding 14, #s10).

Item 9 moved into S1. For item 17 he chose the smaller move, store functions rather than a new type. He ruled each check real, live or by hand, and struck S1 case 9 because it would test nothing once S1 deletes the session writes. He also agreed items 18 and 19.

**Exit test after revision.** All four applicable conditions still hold.
- **Direction:** the refusal set is unchanged (no map, no stored cursor, no summaries, no logging of reads).
- **Added:** two client purposes, one field, and one flag; none is a new file or record type.
- **Dissent unchanged:** Marcus on amber after quick relaunches, owned by Devon. It is now stated plainly for the operator in the decision brief.

## Revision 2 (second adversarial pass; last revision)

The reviewer's second pass found 10 new problems (N1-N10), 4 new suspected ones, and 8 originals only partly resolved. The coordinator asked that findings be resolved by removing or narrowing where possible. The same three agents were resumed, each given only its own items with a proposed rule.

**Nadia.**
- **Accepted:** N1, N9, N2, N7, the #15 and #1 residues, Ns-a, Ns-c, and #12 as a limitation.
- **On N9:** the marker can sit above the clear divider until the pre-clear messages are noted, which she flagged as a minimal reading of spec:23.
- **Amended Ns-b by reordering, adding nothing:** a new page writes its file, then its entry, then notebook.json. Recovery's "no entry" case then applies only to files in neither notebook.json nor the transcript, which skips proposal-era pages and still catches a cut-off new page.

**Devon.**
- **Accepted:** N3, N4, N6, N8 and Ns-d.
- **Amended N5:** report every `undo_page` of a `write_page` on this page; undos of edits stay in `bookChanges`.
- **Ns-d markers:** they are not messages.
- **Moved two pieces of wiring into SophiaCore:** a pure trigger function, and `ClaudeEngine.stop()` setting `stopRequested` (checkable with `/usr/bin/true`; inferred, not run).
- **Facilitator correction:** his proposed `--live` check for `replied` cannot observe NotebookSession, because LiveRun drives `ClaudeEngine` directly. It became a by-hand gate.

**Marcus.**
- **Accepted:** all five narrowings.
- **Wiring:** gave each piece of wiring an exact by-hand step, made `replied`'s step gate S4, and moved recovery to `NotebookStore.open` and the trigger to `nextStep`.
- **Struck outright:** recording changes made outside the app (no scenario needs it, and a hash mismatch already hides Undo), and the duplicate-attempt skip (it rarely matches; kept as a #11 limitation). Nadia had accepted the skip; Marcus owns necessity, and the disagreement is recorded.
- **Stored things:** ruled that all six still earn their place, with `recovered` narrowed to app writes cut off by a crash.

**Removed or narrowed this revision:**
- recording outside changes and their label;
- the duplicate-attempt skip;
- the in-memory arrival origin for the pointer card;
- `recovered` entries in Elsewhere and pointer cards;
- clear's exclusion of uncovered messages;
- non-message entries as "activity";
- thread-only quote matching, which reverts to today's session fallback.

**Added this revision:** no new stored thing.
- New derivations: pending, markers, `quote.entry` matching.
- Two orderings: new-page write, new-page undo.
- Three SophiaCore entry points: `open`, `nextStep`, `stopRequested`.

**Exit test.** All four applicable conditions hold. The direction and refusals are unchanged, and the stored set is unchanged from revision 1. Remaining dissent: Marcus on amber after quick relaunches (owner Devon), and Nadia's skip struck by Marcus (owner Marcus). Operator flags: spec:10, :23, :33, :39 and PLAN.md:189.
