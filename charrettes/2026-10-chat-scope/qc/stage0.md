# QC: Stage 0 grounding brief

**Result: pass** (first attempt).

## What I checked directly

Opened the cited lines in the files and compared them with the brief's claims:

| Claim | Citation | Holds? |
|---|---|---|
| Session id is `s-` + max used + 1, from transcript and learning | NotebookStore.swift:175-178 | yes |
| `unnotedMessages` = person messages after the furthest checkpoint's `through`, across sessions | NotebookStore.swift:201-211 | yes |
| `claudeSession` lives in notebook meta | NotebookStore.swift:227-235 | yes |
| ConversationView reads all of `store.transcript`, filtered only by role/purpose | ConversationView.swift:94-103 | yes |
| "single running conversation"; restart restores one session; reconstruct if resume fails | PLAN.md:203, :161, :189 | yes |
| Mock says "One conversation per notebook, in dated sessions"; selection popover; reconstructed-basis marker | mock/index.html:99, :564-568, :769 | yes |
| `write_page` refusals `open`, `protected`, `quote` | PageEdits.swift:273-292 | yes |
| Sophia answers questions on selected passages; memory at the start of every conversation | SOPHIA.md:44, :93 | yes |
| `--resume` appended when a stored id exists; context via `--append-system-prompt` | ClaudeEngine.swift:59-60 | yes |

Word count 894 (subagent's count; brief is within the limit by inspection).

## Defects

None requiring a retry. Notes for later stages:

1. Section 9: Codex, Cursor, NotebookLM, and Notion AI entries rest on search-result summaries of the vendor pages, not fetched pages. The brief says so per entry, which is what the brief required. Treat these as lower-confidence than the Claude Code entry, which was read from the docs pages directly.
2. Section 4's inference that a resumed Claude Code conversation may keep the original system prompt (so the fresh `--append-system-prompt` context may not reach it) is marked as unverified. C4 must treat it as an open test, not a fact.
3. "Ask Sophia about this" exists only in the mock, not in the app. C1 through C4 must design it, not assume it.
4. The subagent reported (outside the brief) that DATA-MODEL.md:215 still mentions "pending proposals" from the retired draft model. Carry to C4's proposed edits as a cleanup.

## What changed

Nothing; no retry was needed.
