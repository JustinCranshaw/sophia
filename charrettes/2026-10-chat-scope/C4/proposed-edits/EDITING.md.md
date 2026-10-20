# Proposed edits: EDITING.md

Review only; the real file is unchanged. Revised after the adversarial review: edit, release, refusal and undo entries are now stamped with the edited page's thread (DATA-MODEL.md edit), which is what makes the placement below true. Line numbers refer to EDITING.md as of 2026-10-19. The protections are unchanged: the open-section refusal, protected lines and quotes, the release marker, hunks reaching Sophia, and commit on leaving. What changes:
- the undo window for edits and releases, which was a gate-2 rule change flagged in C3 (`C3/decision-brief.md`, "Operator flags");
- which conversation the markers appear in.

---

## Replace: in "### Person edits are protected in the store" (line 42), the first bullet

- A person's commit is saved by the store like any page write: the previous version is kept, a transcript entry records it (with the page's hash), and it can be undone until the next change to that page by either author, whatever is said in any conversation.

---

## Replace: in "### When Sophia wants to change the person's text" (line 56), the sentence

> It can be undone until the next message.

becomes

> It can be undone until the next change to that page, like an edit.

---

## Replace: "### How Sophia hears about an edit" (line 64)

### How Sophia hears about an edit

No automatic turn. The edited page's conversation shows a one-line marker ("You edited §2 of *Fiedler vector*") with Undo. Refusals and the release marker also appear in that page's conversation. Each conversation's next message to Sophia summarizes, as hunks, the edits, releases and undos to any page since her last turn in that conversation. An edit made while talking on another page therefore still reaches her there. She mentions an edit only when it matters (a corrected sign that later steps depend on), and fixes dependent steps through the normal rules above. Update SOPHIA.md accordingly.

---

## Replace: in "## States to handle", the "**Two undos.**" bullet (line 70)

- **Two undos.** The page banner's Undo (`BookView.swift`) offers the most recent write to this page, by either author, labelled "Undo your edit" or "Undo Sophia's change", "until the next change to this page". The conversation marker's Undo does the same for its entry. Both are worked out from the transcript and the files on disk, so they survive switching pages and relaunching (DATA-MODEL.md, "The conversation log").
