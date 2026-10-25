# S1 final correction round — confirmed independent findings

Worktree: `/private/tmp/sophia-page-owned-conversations-20261020`. Starting code: `1fd9fda`. Same GPT-6.1-sol implementer only; no delegation, commit or push. This is correction round 2 of the maximum 2 after handoff. Do all changes in this round, then leave source stable for root verification. Read the independent report `impl/qc/S1-opus-review.md` and governing source citations. The root confirmed the following by reading source; findings are source scenarios, not observed native failures.

Original S1 allowed files and storage constraints still apply. No schema, record type or runtime file additions, no grouped-Undo exception, no framework or command mode, no weakened/deleted assertions. Root will run documented commands with full access if your child environment retains the earlier sandbox.

## F1 — confirm defect, use the existing per-edit release contract

The current single button releases every ID in a multi-edit refusal, while only its last entry can be undone. Fix the UI/action scope, not the one-latest-action rule. EDITING.md:52–56 explicitly says the button releases **that edit's hunks only**, with one scalar `entry`; DATA-MODEL.md:155–167 says only the latest release can be undone.

Show each quoted edit with its own release/status/Undo controls. One click releases exactly that edit and writes one `release_edit`; Undo names that same release if it is the latest page action. Retain one shared Sophia reason if useful. Do not implement the reviewer's proposed trailing-run grouping: stored adjacency cannot reliably distinguish two separate clicks, and accepting older releases as undoable would change the explicit latest-action rule. No invented group ID or new fields. Make the page banner and each per-edit control agree. Preserve open-editor/quote refusal behavior.

Extend production-backed checks for two protected edits: releasing e1 leaves e2 protected; releasing e2 makes only its release latest; undoing it restores e2 protection and leaves e1's explicit prior permission intact, with no Undo of Undo. The UI must make those separate scopes clear. No single control may misleadingly grant or withdraw both.

## F2 — bound first-turn change notifications

`Prompts.turnPrefix` currently scans from zero when no prior message exists in a page thread. For a first turn derive the start from the later of its clear and checkpoint-through boundary. Continue excluding the outgoing message and including changes made while queued before dispatch. For an existing thread use the proper prior-turn boundary. See DATA-MODEL.md:282–285 and applied S6's first-turn cursor rule (this fixes the already-shipped S1 prefix, not S6 UI).

Give the Q prefix fixture a genuine preceding Q turn where it expects later edits. Add a legacy/never-discussed page case with old changes before through and fresh changes after: old activity/edits/revisions must not be presented as recent. Exercise clear boundaries too.

## F3 — identify actual tool effects independently of app reload timing

A Q send or person edit can reload the store after MCP saves but before `.toolResult`, so result-time diffs lose goal_noted/book reveal. Use `pageWrite(toolUse:)` for the exact successful page write after reload rather than set subtraction.

For goals, prefer recording the existing `goal_noted` transcript entry at the actual goal save under the store lock with the fixed originating thread, then remove duplicate app-side derivation. That avoids depending even on `.toolUse` callback timing and introduces no new record shape. Check existing call sites/tests for unintended duplicate entries. If this cannot fit the existing schema, report before changing it. Add a real writeGoal ownership/completion assertion to the existing checks; explicitly distinguish that from unexercised NotebookSession event delivery.

## F4 — preserve the existing live-note quote constraint

Apply thread-first lookup **within the current app session**, then other threads in that same session, and restrict `quoteEntries` accordingly. The root resolves DATA-MODEL.md:227 together with the explicit earlier-session exclusion at :330 and the user's instruction to keep the store's checks. The quoted-message search priority does not require removing the existing session guard. This changes neither checkpoint coverage across sessions nor goal evidence.

Add a same-thread earlier-session quote case and a same-session cross-thread fallback case. Reject the former quote (a record may survive as paraphrase with valid refs); retain the latter. Do not rewrite the specification docs to conceal ambiguity; the root records the interpretation in QC.

## F5–F7 — prompt, scroll and queue cleanup

- Update `Prompts.context`'s stale claim that a written page appears beside the conversation. Match SOPHIA.md:66 / PLAN.md:224: Open on the card, selection unchanged.
- ConversationView's autoscroll must react to the visible thread's entries, not global transcript count. Foreign-thread completions/tools must not jump the conversation being read (PLAN.md:232). Preserve existing in-thread behavior; no new stored navigation state.
- On billing rejection, cancel and detach current work, clear pending dispatch state/queue without deleting saved person messages, and keep the billing warning. Do not automatically try another provider. On ordinary engine-start failure, finish handling that failed turn and drain remaining queued turns rather than leaving them permanently pending. Keep failure distinct from replied/stopped and preserve identity guards. Add production-helper checks only if they genuinely exercise the selected implementation; do not imitate NotebookSession locally in a check.

## F8 — accurate coverage and missing cases

Label synthetic append-field ownership cases accurately; they do not execute every app/MCP writer. Preserve those assertions and improve actual production coverage where possible, including F3's real goal writer. Add person-edit Undo across both scopes and reopen. Assert the canonical and previous bytes at the pre-Undo boundary as well as exact post-replacement bytes/hash/consumption. Do not claim to observe an OS crash or the instant inside rename.

## Handoff

Run `swift run sophia-checks` and `scripts/make-app.sh debug` from `app/` if your environment permits; otherwise report exact inherited-policy failures without repeated attempts. Root owns the final live rerun. Preserve all previous assertions and map added assertions to production functions. Report each finding's resolution, files changed, observed output, remaining uncertainty and any unresolved issue. Do not start S2.
