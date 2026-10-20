# S1 native checks — prepared Gate B checklist

The independent review is complete and its corrections are implemented. The final live check failed, so S1 is not yet ready for acceptance; see [S1.md](S1.md). This checklist is preserved for the native gate once that result is resolved. These checks are not passed by snapshots or core checks. The fixture is reduced and synthetic, not the full historical 240-entry notebook.

## Launch

From `/private/tmp/sophia-page-owned-conversations-20261020/app`:

```sh
SOPHIA_LIBRARY=/private/tmp/sophia-s1-gate-b-20261020/library build/Sophia.app/Contents/MacOS/Sophia
```

Notebook: **Fourier analysis**. P is **1.3 The convolution theorem**, Q is **1.4 Sampling and aliasing**. R does not initially exist. The fixture has a protected person edit and a synthetic refusal card on P. Its small history and notes are explicitly synthetic. Only the disposable library is used.

Fresh copies are ready at `/private/tmp/sophia-s1-gate-b-20261020/undo-library` and `/private/tmp/sophia-s1-gate-b-20261020/contents-write-library`. Substitute one of these for `SOPHIA_LIBRARY` when a check requires an untouched edit or an absent R. The first is for destructive Undo/release checks; the second is for creating R from Contents.

A separate two-edit fixture is ready at `/private/tmp/sophia-s1-gate-b-20261020/multi-edit-library`. In check 7, also use its P refusal card: two quoted edits must each have their own “Let Sophia change this edit” button. Release the first: only that edit shows permission granted. Release the second: only its permission can now be undone. Undo it: the second is protected again, the first still visibly permitted, and no older Undo or Undo of Undo is offered. The orchestrator observed the two controls in a snapshot; clicking them remains a native check.

The orchestrator can inspect `library/Fourier analysis/transcript.jsonl` afterward for ownership/completion counts; the operator need only report what the UI did and the questions used.

## Seven checks

1. **Normal turn and relaunch.** Open P and ask a short question. Wait for completion, close/reopen the notebook. Observable: one answer in P, the same history once after reopening, and exactly one new P-tagged `replied` in the saved log.
2. **Interleaving.** Ask a longer question on P; while it is streaming open Q and ask the sampling/convolution question from scenario 2. Observable: P's text stays on P, Q's question waits and gets one answer in Q. Open Goals and Notes: the named conversation remains Q.
3. **Selection, draft and caret.** On P, hide the book and ask Sophia to create R, titled “1.5 Windowing and spectral leakage.” Type an unsent draft while she writes. Observable: the book reappears on P, conversation stays P, draft and caret remain; only clicking Open on the result selects R. Repeat from Contents in a fresh fixture copy. Record R's actual immutable filename; title-derived creation need not reproduce the historical fixture's short filename.
4. **Durable one-way Undo.** The seeded P edit should remain undoable after a Q message and relaunch. Undo it: original bytes return, and no Undo of Undo appears. On a fresh copy, release the protected edit using the seeded refusal card: release becomes the sole latest undoable action on P; undoing permission does not restore an older Undo offer. Also repeat with a real Sophia revision, then a Q message.
5. **Recovery boundaries.** Separate disposable libraries exist under `recovery-revision`, `recovery-new`, `external-overwrite`, and `copy-only` beside `library`. Launch with each library path. Observable: revision/new-file cases have one recovered record after repeated opens; the orphan is unfiled. Outside overwrite/copy-only cases gain none and offer no Undo. Recovered writes do not appear as conversation activity. These are synthetic saved boundaries, not actual process crashes. The orchestrator has already opened/rendered these variants; do not describe them as pristine pre-open fixtures.
6. **Finish and immediate send.** After a new exchange, click Finish for now and immediately send another question. Observable: exactly one answer in the originating conversation, no stale-process connection error. Saved checkpoint belongs to Contents (`page: ""`); reply belongs to the question's page.
7. **Editing and permission.** Open P's “Where it fails” editor and ask for a conflicting revision. Observable: open-editor refusal has no release action. Commit a parenthetical, then request rewording of the protected line: refusal quotes the relevant edit/reason. Release says it applies on the next message and starts no model turn. With text focused, ⌘Z undoes text rather than a page action.

Checks 1–3, the real-model portion of 4, 6, and actual tool refusals in 7 require the person's Claude login. Snapshot mode disables interaction and suppresses return processing; it cannot establish these results.

The orchestrator will prepare fresh fixture copies where the sequence needs an unmodified P or absent R. Do not reset or overwrite the operator's real notebooks. S2 remains gated on the operator's explicit continuation after S1.
