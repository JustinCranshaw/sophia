# SOP26: saved attempts beside optional criteria

The Goals reader projects existing saved evidence, without changing goal status or adding records. A criterion shows current attempt revisions linked directly or through an explicit saved read → attempt-ID chain. A cited older attempt revision resolves to its current known chain; a missing/deleted reference is not guessed. Shared words or transcript references do not imply a criterion association. `shownNotes` preserves Sophia's interpretation beneath a person's correction. Latest criterion reads use saved timestamp and monotonic note ID, so restoring an older read does not make it the latest. Sophia records within one checkpoint timestamp are not falsely treated as newer because of their JSON order; the person’s correction can use the ID tie-break. Newer attempts/corrections are flagged without asserting mastery.

An attempt's saved quote remains distinct from Sophia's tentative interpretation. Where a note only has a paraphrase, the reader says so and its checked evidence link can reveal the full cited exchange. Criteria with no linked attempt say that, rather than “No attempts yet.” Captured attempts without any current criterion link have a separate optional section, explicitly allowing that a read may exist elsewhere. No goal or note is required on every turn. The note-tool description adds only guidance to attach known criterion refs when a noteworthy actual attempt is saved, preserving help/partial/unshown limits.

## Checks

From the repository root:

```
swift run --package-path app sophia-checks
app/scripts/make-app.sh debug
```

Integrated baseline: main `b69dd14fd46c2fa48c2002a2bf3e0446cd3a2c98` (route guard landed). All **89 core checks** pass: 86 base plus three focused projection checks. The debug app and MCP bundle build. The checks cover direct links with no read, explicit older-attempt links across revisions, multi-criterion linkage, no prose matching, correction preservation, deletion/unavailable/Undo/reopen, stable latest-read order after restore, honest unlinked attempts, unchanged file bytes and provisional goal status. No new persistence, status inference, schema or navigation state.

## Native directed replay

Disposable `/tmp/sophia-sop26-ui/library/Goal evidence replay`; source head before freeze is the scoped SOP26 diff on the baseline above. The local fixture explicitly labels itself a developer replay, **not new human learning evidence**. It copies two actual recorded statements from the 2026-10-24 study (`n-14` and `n-23`) into a short synthetic prior exchange, including the fact that the first followed help. Fixture transcript timestamps are synthetic and are not retention evidence. A three-criterion optional goal is created with the production MCP, then explicitly reviewed and confirmed through the native UI: `g-2` is authored by the person, replaces `g-1`, and stays `working` throughout. No mastery or completion decision is inferred.

One subsequent actual model request, through the existing official Claude Code connection and unchanged product model/default, asks to retain those attempts and their limitations, without page changes or marking goals met. This is **directed capture**, not spontaneous note-taking. Two actual attempt notes result:

- `n-1`: refs `t-0004`, `g-1#1`; fixed ratio/non-mode restatement after help, not an unprompted derivation.
- `n-2`: refs `t-0006`, `g-1#3`; scale/amplitude prediction only, with eigenvalue-as-omega-squared and frequency derivation explicitly unshown.

Quote matching was refused in this replay. Both notes are marked paraphrases, and the actual reply discloses that. Checked transcript refs still reveal the complete exact statements separately. No claim that the paraphrase is an exact quote. Two working-memory lines also retain the stated limits. No criterion-level read is generated in this turn, so the UI honestly says no criterion-level read saved; criterion 2 has no linked attempt. The response is substantive but long: this directed audit does not establish SOP25 pacing. Raw canonical model metadata was not captured; the official CLI connection and real persisted tool/reply records are observed, not independent billing/commercial proof.

Native correction of `n-1` saves: “I restated the fixed-ratio argument after help; I have not derived the eigenvalue condition.” Goals shows this as **Your correction**, preserving the original Sophia interpretation and cited exchange. Deleting that note removes it from the criterion; Notes Undo restores both original and correction. Native Quit/relaunch with an explicitly huge return threshold confirms they remain visible, with no additional provider request. Goal count/status are unchanged, and the only page write is developer setup, before Send. `/tmp/sophia-sop26-native-proof.json` and the disposable transcript/learning files retain the records.

Original-resolution screenshots in `/private/tmp/sophia-sop26-ui/results/`:

- `1792929188013052000-9b1a42.png`: exact fixed-shape exchange expanded separately from paraphrase.
- `1792929218670574000-2830d6.png`: person correction, empty derivation criterion, amplitude limits.
- `1792929235374053000-ccae2a.png`: amplitude source expansion.
- `1792929245472645000-833892.png`: deletion state.
- `1792929308427268000-61f024.png`: restored correction after reopen.

A separately labeled synthetic unlinked attempt is added through the production note tool solely to inspect the unlinked section; it is not model- or human-generated evidence. The MCP correctly refuses a developer attempt to write a `read` note (reads are checkpoint records); this refused request creates no read. Explicit read-mediated projection is covered by core checks, not represented as a new native model observation.

- `1792929460584903000-fb09a0.png`: after the extra fixture/reopen, the amplitude limitation, empty criterion, and explicitly unlinked synthetic attempt appear together. The section says a read may exist elsewhere and does not infer relevance/completion. Original-resolution images were inspected. Final app PID 99494 quit through native Cmd-Q and was verified gone. No further inquiry was sent after the single completed model turn.


## Independent review fixes

The first Opus5.5 adaptive review found three concrete gaps; all were fixed without new state. The note guidance requests the person’s message ref alongside a known criterion. A criterion association is not source evidence: each row excludes all goal association refs from attempt source citations, and a source-less paraphrase explicitly says no exact words or exchange were saved. The attempt itself remains visible; no words are invented. The extra native fixture `n-7` deliberately has only a criterion ref, and `1792930176631270000-8f4914.png` shows that honest missing-source state on the fixed build; no provider call was made for this check. It is separate from the earlier genuine empty-criterion observation. App PID10611 quit through native Cmd-Q and was verified gone.

The newer flag now compares Sophia records strictly by time, retaining ID ordering for a person's same-second correction. An explicit saved read citing a correction resolves that known attempt chain, preserving the original interpretation and correction. The third regression pins timestamps, checks both false newer cases and the true person-correction case, then deletes the earlier read so only the correction-ID linkage remains. The final check command set `TMPDIR=/tmp/sophia-sop26-owned-checks`, but the review verified that Foundation’s `tempStore` still writes to the shared per-user temporary directory on this Mac; that setting isolates build temporaries only. Both final 89-check runs leave shared fixture directories untouched.


The integration owner did not accept deferring the same missing-source case for multi-criterion associations. The shared read-only `attemptSourceReferences` helper now removes every goal ref (including whole-goal and deleted-goal criterion refs) from the source-evidence list, while the projection still keeps every association. The focused regression checks two-criterion-only refs produce no sources, and a genuine person-message ref (including quoted-entry deduplication) remains. The developer fixture was revised through the note tool to link only criteria 1 and 3; `1792930884390815000-6a8044.png` shows both rows saying no exact words or exchange were saved, with no criterion presented as source evidence. The real amplitude and corrected fixed-shape source links remain visible, criterion 2 returns to its honest empty state. No model rerun. Native app quit and its PID was verified gone.


The follow-up reviewer found that whole-goal and deleted-goal criterion refs also must not become source evidence. The filter is now the simpler existing `g-` namespace test, independent of whether the goal still resolves. The same focused check covers a whole goal and a genuinely deleted provisional goal. Their stored references remain unchanged; only source presentation excludes them. No additional UI state or model request.
