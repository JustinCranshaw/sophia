# Conversation reading position — October 25, 2026

SOP-46 is a local attention change, not the full SOP-25 companion pacing work. Keep following at the end; an intentional upward move stops following; New activity explicitly returns to the latest material. Explicit Send, jump and conversation navigation choose the end. Resize/reflow alone does not create unread material. No text is suppressed, no phrase list/quota, reading-position persistence or scrolling service is added.

## Observed iterations and source

- Baseline main 2918366: controlled later note/memory/page/text activity moved a conversation from 0.76901 to 0.99404 without conversation-reading intent.
- Initial review of c7108e7 found that geometry-only origin changes could repeatedly pull a slow scroll to the end. After the minimal 7b6c8cb repair, slow at-rest 4-point steps accumulated, but actual streaming still pulled them back within the 32-point margin (0.9927→0.9947, no badge). Native Stop and Quit ended that failed experiment.
- a67d0f8: deliberate upward movement stopped following immediately. A live resize exposed delayed native clip adjustment being mistaken for a scroll. The next bounded repair tracks viewport settlement only while already following, targets the full padded content bottom, and distinguishes an actual bottom clamp from movement away. Empty/short content explicitly clears settlement. Send, jump and navigation reset it. No timer is used. Temporary numeric geometry logging was removed.
- 11d70ac: empty→long and short→long lifecycle checks reached end 1, then honored a later 4-point move and showed New activity after appended records. Real live resizing/upward scrolling passed, but completion replaced the streamed Markdown reader with a fresh 30-point reader, moving the visible anchor upward. It did not jump to the bottom; it was a separate real rendering failure.
- Final native source bec540d (including main 2bc5955/source permissions): a pure presentation mapping gives each assistant block a notebook/thread-scoped originating-question+block identity. Stream and committed entry share the same EntryView/MarkdownView subtree. Real transcript IDs remain separate scroll anchors. No Session or persistent IDs change. Before/after completion screenshots now retain paragraph 3 and its equation at identical pixels.

## Synthetic activity evidence

Initial fixtures were created by a temporary helper compiling the production Core sources. Their text is explicitly labeled synthetic. Later note, memory, page and text records also used production stores. A native notebook-separation toggle reloaded the app’s cached records without a conversation navigation. This is controlled appended activity, not provider output or natural event timing.

Wide before/after screenshots show identical paragraph anchors, with New activity appearing. The normalized fraction changes 0.75874→0.70429 because content grew below the view; it is not a position jump. Explicit jump reaches the end and clears the badge. Narrow 900 likewise retains its anchors and exposes the labeled button. Resize alone creates no badge.

The separately planned unrelated-thread check ran on 11d70ac/main 63: while reading Q, synthetic P note/page/memory records and then Contents text were surfaced through a native Notes correction save. Q narrow stayed exactly 0.7953615 with no badge. Wide stayed away with no badge (0.65536→0.65160; slight reflow, not a bottom jump). The final pure mapping’s notebook/thread isolation is also covered by focused checks. Those unrelated-thread cases were not rerun after the renderer-only mapping change.

## Final real streaming observation

An explicit native Send requested a disposable mathematical explanation; no tools/pages/notes/memory were requested. On bec540d, the first 4-point upward move during a real narrow stream immediately exposed New activity and retained the reading position. Jump resumed end-follow. Live wide and narrow resizing both remained at end 1 without a badge. After scrolling into the streamed response, it completed while away; paragraph 3 and the equation retained identical visible positions. A real assistant record t-0031 (7619 characters) and client replied t-0032 were persisted. Final jump reached 1 and cleared the badge. This final reply completed; earlier aborted experiments are not presented as completed replies.

These are actual provider text deltas and native controls, distinct from the synthetic metadata cases. They are scripted internal rendering checks, not people learning, a pacing/latency benchmark, billing attribution, human tolerance or delayed-return evidence.

## Checks and limits

Debug app/MCP packaging and 66 current core checks passed on the final native source. Nine focused cases compile the actual ConversationRows.swift against Core: streamed→recorded identity, separate raw anchor, tool interleaving/multiple blocks, briefing before the first question, Retry after a recorded partial, new-question separation, notebook/thread separation, edits not becoming origins, and row uniqueness/anchors.

From the repository root:

```sh
python3 research/2026-10-25-conversation-follow/check-rows.py
```

The final reviewer/build results are recorded on the PR. Source permission/evidence UI remains outside the transcript reader and is preserved from main; no source research flow was replayed for this change. No raw authentication output or credentials are included. The disposable app was quit and the GUI released after the final observation.
