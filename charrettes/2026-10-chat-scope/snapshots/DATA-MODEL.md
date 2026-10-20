# Notebook data model plan

## Purpose

A notebook holds knowledge that both Justin and Sophia read, rely on, and correct: pages, goals, attempts, Sophia's interpretations, and the conversation they came from. These are shared objects. Each must say who said it, what it rests on, and who may change it, in a form a person can read on screen and an agent can parse without guessing. This plan defines the smallest set of records that does that, and the rules the client enforces so the guarantees hold even when the model misbehaves.

## Scope and exclusions

- Included: the files in a notebook, the record shapes inside them, who may write each, how corrections and deletions work, how page writes are recorded and undone, and how the person and Sophia each read the state back.
- Excluded now: a source catalog, a separate chapter or book object, experiment proposals, chapter proposals, hand-edited goal or note files, and any record that summarizes the person (level, profile, ability).

## Requirements and constraints

- Sophia saves pages directly with `write_page`; there are no drafts to accept (the person's decision, 2026-10-14). Every page write is recorded in the transcript, a revision keeps the version it replaced, and the person can undo either. Tools never delete pages.
- The person's actual words, Sophia's interpretations, and source material stay distinguishable. (AGENTS.md product principles; SOPHIA.md:33, SOPHIA.md:37)
- Progress toward goals is shown as evidence, never as a score. Sophia records goals she hears in the conversation (`set_goal`); they are provisional until the person confirms them, and only the person marks a goal met or dropped. (SOPHIA.md:67)
- Reading or agreeing is not evidence of understanding; assessments stay tentative. (PLAN.md:44; SOPHIA.md:33)
- Attempts are recorded quietly, reviewable and deletable. A page may quote the person's words, as a block quote.
- Notes reference the conversation instead of copying it; the client requests a checkpoint at session end. (PLAN.md:131)
- Storage stays small; complexity is added only for a demonstrated failure or workflow. (AGENTS.md; PLAN.md:133)
- "Specified, but flexible" and "understandable by both the agents and the humans." (User constraint.)

## Evidence used

- PLAN.md §4 defines the current files: notebook.json, pages, one previous page version, transcript.jsonl, learning.jsonl. This plan keeps those files and adds none.
- The MCP tools are `read_page`, `write_page`, `set_chapter`, `set_goal`, `note`, `set_memory`, `recall`, `about_you`, and `link`. They write through the same store code as the app, under a lock on the notebook. There is no tool that writes notes, so notes can only come from the client's checkpoint request.
- The UI mock (mock/index.html) shows every object below in use and exposed two conflicts this plan resolves: two different "next steps" on Goals and Notes, and goal criteria with "Done once / Partly / Not tried" labels that work like a stored score.

## Proposed design

### The files

```text
notebook/
  notebook.json            structure: chapters and page order
  pages/<file>.md          accepted pages (Markdown with a small header)
  pages/<file>.previous.md one previous version per page, for undo
  transcript.jsonl         the conversation, proposals, and decisions, one entry per line
  learning.jsonl           goals, notes, Sophia's memory, reads, takes, corrections, briefings
  .editing.json            what the person has open in the page editor, if anything (cleared on commit, revert, and launch)

library/.sophia/
  about.jsonl              "About you": background and standing preferences shared by every notebook
  links.jsonl              links between pages in different notebooks
```

### Memory, About you, and links

Sophia has three layers of memory.

**Working memory (one notebook).**
- **What it is:** `memory` records in learning.jsonl. At most 10 short lines on where the inquiry stands now. Each line has `refs` that must resolve: notes, messages, pages, or goal criteria. Forgetting a line therefore loses no evidence.
- **Who writes it:** Sophia rewrites the set whole, with `set_memory` or in the checkpoint reply (`{"notes": […], "memory": […]}`). The store keeps unchanged lines, writes a replacing record for a reworded line, and writes a `retired` record for a line left out. A checkpoint reply with no memory, or an empty one, leaves the memory unchanged.
- **The person's control:** they can correct or forget a line, and Sophia can't change or drop a line they corrected.
- **What Sophia sees:** the memory at the start of each conversation, and her notes only through `recall`.

**Long-term notes (one notebook).** The notes described below. `recall` finds them by id, by page reference, or by words (all must appear), and it also finds matching messages from the person.

**About you (every notebook).**
- **What it is:** lines in `<library>/.sophia/about.jsonl`: the person's background and standing preferences, never topic details or judgments of ability.
- **Sophia's proposals:** she proposes a line with `about_you`. It needs a quote that matches the person's words in that notebook, records the notebook it came from, and is limited to 12 lines in all. A proposed line is provisional. It is visible to Sophia only in its notebook until the person confirms it, which writes a replacing record by the person.
- **The person's control:** they can add, reword, or delete lines, and Sophia can't revise a confirmed line.

**Links (between notebooks).**
- **What a link is:** a `links.jsonl` record, `{from: {notebook, page?, section?}, to: {notebook, page, section?}, reason}`.
- **How one is made:** Sophia proposes it with `link`. The target page must exist. The person confirms or removes it.
- **Sections:** a page's `##` and `###` headings, outside code fences. A link can point into a section. The section's title must match one on the page (ignoring case, spacing, and punctuation) and is stored as written there. Following a link scrolls to that section.
- **What Sophia sees across notebooks:** only the other notebooks' chapter, page, and section titles. She can read a page in another notebook, or one section of it, only through a confirmed link (`read_page` with `notebook` and optionally `section`).
- **Keeping a notebook out:** a notebook with `"separate": true` in notebook.json isn't listed, linked, or readable from others. It sees none of them, and can't be linked.
- **Locking:** library files are written under a lock on `<library>/.sophia/.lock`. Deleting a line or link removes its whole chain.

Pages are Markdown because people read them as prose. The two logs are JSON Lines (one JSON object per line) because every entry must carry machine-checked authorship. People read and correct them through the app, which also offers "Show record" on any card so the raw line can be audited.

Page bodies and Sophia's replies use LaTeX math within Markdown: `$...$` for inline expressions and `$$` on separate lines around display equations. The reader also accepts `\(...\)` and `\[...\]`. Store the original Markdown and TeX, not rendered HTML; rendering is local and does not execute page HTML, JavaScript, or LaTeX programs. Existing Unicode notation remains readable.

Pages may also contain music as ABC notation in ```` ```abc ```` fences ([MUSIC.md](MUSIC.md)), optionally starting with one line of JSON options and a `---` line. The fence's text is the record; the reader typesets it locally with abcjs, and nothing about the rendering (SVG, warnings) is stored. Warnings reach Sophia only through her next turn's context.

### Structure: notebook.json

```json
{ "chapters": [ { "number": "0", "title": "Foundations", "pages": ["0-0-probability.md", "0-1-entropy.md"] } ],
  "unfiled": ["roadmap.md"] }
```

This is the only place chapter membership and order live. A page's header holds its title and sources, not its chapter.
- **Chapter number:** optional. Numbered chapters are kept in number order.
- **Page numbers:** a page's section number, if any, is part of its title ("0.1 Entropy"); the app sets it apart in the header and contents.
- **Who files pages:** Sophia puts pages in chapters with `set_chapter`, or with `chapter` on `write_page`. Moving a page never changes its content. A chapter with no pages is removed.

### Pages

```markdown
---
title: Why the Fiedler vector splits a graph
sources:
  - title: A Tutorial on Spectral Clustering
    author: U. von Luxburg
    location: "§5.1, Approximating RatioCut for k = 2"
    summary: The cut indicator is relaxed to real values; the solution is the second eigenvector of L.
    inspected: true        # false when Sophia could not read it
---
Prose and mathematics.

> "The bridge is the only edge across the cut…"  <!-- quote: t-0412 -->
```

A quoted attempt on a page carries the transcript entry it came from, so the page shows the person's words exactly.

### The conversation log: transcript.jsonl

Every entry: `{ "id", "at", "role": "person" | "sophia" | "tool" | "client", ... }`.

- Messages carry `text`, and each belongs to a session (`session`).
- A page write is a `tool` entry: `{ "tool": "write_page", "file", "title", "revised"?: true, "tool_use" }`.
- An undo is a `client` entry: `{ "purpose": "undo_page", "entry": "t-0042", "file" }`.
- When Sophia records a goal, the app adds `{ "role": "client", "purpose": "goal_noted", "record": "g-3" }` so the conversation shows it where it happened.
- The person's edit to a page (EDITING.md) is `{ "role": "person", "purpose": "edit_page", "file", "title", "section", "index"?, "hunks": [{ "before", "after" }] }`. `section` is the section's title, `"(opening)"` for the text before the first section, or `"(page)"` for the whole body; `index` is the section's position. Hunks are whole changed lines, joined with newlines. An edit is not a message: it is never quoted, checkpointed, or treated as evidence of understanding.
- A refused `write_page` is `{ "role": "tool", "tool": "write_page", "refused": true, "reason": "open" | "protected" | "quote", "file", "section", "current", "edits", "edit"?, "why"? }`. Nothing on the page changed; `current` is the section's text that was kept.
- `{ "role": "person", "purpose": "release_edit", "entry": <edit_page id> }` lets Sophia change that edit's lines; `{ "role": "client", "purpose": "undo_release", "entry": <release id> }` takes it back.

**The person's edits.** The person edits one range of a page at a time. While it is open, `.editing.json` records it (`{session, file, key, section, text}`), and a `write_page` that doesn't keep that text intact is refused. A commit is spliced in by lines: every other byte of the file, frontmatter included, stays as it was; a commit that changes nothing writes nothing. The range is found by the hash of its text when the editor opened, so a commit against a range that changed since is refused and the person's text stays in the editor. A saved edit keeps the previous version and can be undone like a page write; only the latest write to a page, by either author, can be undone.

**Protected lines.** A page's protected lines are the `after` lines (not blank) of its `edit_page` entries, not undone or released, that still appear on the page. Nothing else stores them. `write_page` refuses a revision that drops or changes any of them (compared as whole lines, anywhere on the page), and also one that drops or changes a block quote of the person's words (the quote lines around a `<!-- quote: t-… -->` marker). A refusal is recorded and returned to Sophia with the person's current text. Releasing an edit lifts protection from that edit's lines only. If the person deletes or changes their own line, it is no longer protected.

A page write saves in a fixed order: the page file (copying the current version to `.previous.md` first, for a revision), then notebook.json, then the transcript entry. On opening a notebook, any page file missing from notebook.json is listed as unfiled, so a crash part-way through loses nothing. Undo restores `.previous.md` for a revision, or removes a new page and its notebook.json entry; the app offers it until the person's next message.

Older notebooks may hold `proposal` and `decision` entries from when pages were accepted. On opening, any proposal nobody accepted or discarded is saved as a page and marked with a `filed_draft` entry.

### The learning log: learning.jsonl

Every record has the same envelope:

| Field | Meaning | Set by |
|---|---|---|
| `id` | stable identifier | client |
| `at` | time written | client |
| `session` | the session the record came from | client |
| `by` | `person` or `sophia`: who wrote `text` | client, from how the record arrived |
| `kind` | what the record is about; an open string | writer |
| `text` | the record's content in plain language | writer |
| `quote` | optional `{ "entry": "t-0412", "text": "…" }`: the person's exact words | writer, verified by client |
| `refs` | links to evidence: `t-…` transcript entries, `n-…` other records, `p:<file>` pages, `g-…#2` a goal's second criterion | writer |
| `replaces` | optional id of the record this one corrects or updates | writer |

Any other field is kept exactly as written and shown as-is. Code depends only on the envelope. This is the "specified, but flexible" rule: a new kind of knowledge is a new `kind` value, with no migration, but who said it and what it rests on are always fixed fields the client checks.

The kinds used now:

| Kind | Written by | Required beyond the envelope | Shown as |
|---|---|---|---|
| `goal` | Sophia (provisional) or person | `text`; `status`: `working` \| `met` \| `dropped`; optional `criteria` (list of plain text); optional `quote` and `refs` when Sophia wrote it | Goals |
| `take` | person | `refs` to a goal or criterion | "Your take" beside Sophia's read |
| `correction` | person | `replaces` a Sophia record | Person's text in place of Sophia's, with "Was: …" beneath; the original record's `quote` and `refs` still show |
| `attempt` | Sophia | a verified `quote`; `text` is Sophia's read of it | Note: your words, then Sophia's read |
| `read` | Sophia | `refs` to at least one `attempt` record or person transcript entry; about a criterion, also `refs` to it | "Sophia: partly · based on Oct 14, Oct 16" |
| `question` | Sophia | `refs` to where it arose | Open questions |
| `follow_up` | Sophia | a verified `quote` or `refs` | Something to check on later; Sophia revises it to close it |
| `background` | Sophia | a verified `quote` or `refs` | What Sophia learned about the person in relation to this topic (what they know, what's rusty, how they like to work on it); never a general judgment of ability |
| `next_step` | Sophia | `refs`; only the latest is shown | One next step, used by Goals, Notes, and the briefing |
| `briefing` | Sophia | `refs` to every record and page it relies on; no `quote`, because it is written in a new session | The return briefing; a `correction` can replace it |

Example records:

```json
{"id":"n-31","at":"2026-10-14T10:42Z","by":"sophia","kind":"attempt",
 "quote":{"entry":"t-0412","text":"Positive on one triangle, negative on the other, about the same magnitude on all six."},
 "text":"Signs right; magnitudes corrected (the bridge endpoints sit nearer zero).","refs":["t-0412","t-0413","g-1#2"]}
{"id":"g-1","at":"2026-10-14T10:05Z","by":"person","kind":"goal",
 "text":"Get fluent again with why spectral partitioning works","status":"working",
 "criteria":["Explain why the Fiedler vector is a relaxed balanced cut","Predict the vector on a new graph before computing it","Say when zero is the wrong threshold, and what to do instead"],"refs":["t-0401"]}
{"id":"n-44","at":"2026-10-23T09:12Z","by":"person","kind":"correction","replaces":"n-32",
 "text":"I finished the bridge explanation after a hint."}
```

A goal's history is its chain of `replaces`: rewording, adding criteria, confirming, and marking it met are each a new `goal` record. A goal is provisional while its current record is by Sophia; the person's Confirm writes the same goal as a record by the person. References to a goal always use the id of its first record (`g-1#2` means criterion 2 of the goal first recorded as `g-1`), and criteria are only added to the end, never reordered, so references survive rewording. Criterion progress is not stored. The app shows each criterion with the attempts that reference it, Sophia's latest `read` about it (with its dates), and the person's `take`. If a newer attempt references the criterion after Sophia's read, the app marks the read "newer attempt since". No record has a `partly`/`done` value.

### How records arrive, and what the client checks

1. **The person writes** goals, confirmations, takes, and corrections through the app. The client stamps `by: person`.
2. **Sophia writes goals through `set_goal`** during the conversation. The store stamps `by: sophia`, keeps the current `status` (new goals are `working`; Sophia cannot mark one met or dropped), keeps existing criteria and only appends new ones, keeps a `quote` only if it appears exactly in one of the person's messages, and references the person's latest message.
3. **Sophia writes notes in three ways**, all through the same checks:
   - **During the conversation**, with the `note` tool:
     - Kinds `attempt`, `question`, `follow_up` and `background`.
     - At most 8 new notes per session; revising one doesn't count.
     - The store finds the person's message in this session that a quote comes from.
     - Sophia may revise her own notes, for example to close a follow-up, by writing a record that `replaces` the old one. She may not revise a note the person corrected.
     - Each note gets a `{role: "tool", tool: "note", record}` transcript entry, shown as one line in the conversation.
   - **The checkpoint:** a list of `attempt`, `read`, `question`, `follow_up`, `background` and `next_step` records, adding only what the live notes missed.
   - **The return briefing:** one `briefing` record.
   - **Checkpoint scope:** a checkpoint covers the person's messages since the previous checkpoint, across sessions. A session is one app launch, and one sitting can span several.
   - **When it runs:** at End session, or, when the person comes back to a notebook whose last messages have no notes, before the briefing.
   - **The checkpoint's transcript entry** names the last message it covered in `through` and marks `catch_up` when it ran on return. Messages a checkpoint covered are never offered to a later one.
   - **Coming back** means the latest message by the person or Sophia (a briefing counts) is at least 6 hours old. A shorter gap gets neither catch-up notes nor a briefing.
   - **The briefing** is at most two sentences: the one thread worth picking up, then one offer. It may be empty, and then nothing is shown.

   The client applies the same checks to both:
   - stamps `by: sophia`, `id`, and `at`, and discards any `by`, `at`, `status`, or decision fields Sophia supplied;
   - accepts only the kinds `attempt`, `read`, `question`, `next_step`, and `briefing`;
   - drops any reference that does not resolve to an existing transcript entry, record, page, or goal criterion, and applies the next two checks to what remains;
   - rejects a record with no `quote` and no `refs` (an interpretation with nothing behind it cannot be stored), and rejects a `read` that does not reference an attempt or a person's message (reading a page is not evidence of understanding);
   - rejects a `briefing` over 60 words; the app shows nothing in its place;
   - accepts a `quote` only if its entry is one of the `person` messages the checkpoint covers and the quoted text appears in it exactly (ignoring differences in whitespace). Otherwise the quote is removed, and the app shows that record as "Sophia's paraphrase", without quotation marks;
   - shows the person what it dropped or rejected and why (the command-line client prints it; nothing is stored).
4. **Page writes** follow the transcript rules above.

These checks are what make "Sophia never marks a goal met", "your words are quoted exactly", and "no summaries of you" true in code, not only in the prompt.

### Deletion and undo

The person can delete any learning record. The client removes the record and every record whose `replaces` chain leads to it, then rewrites learning.jsonl atomically. Undo holds the removed records in memory until the person's next message. The conversation itself still contains the words, and the app says so. Because checkpoint quotes must come from the session being summarized, a deleted attempt cannot be recreated by a later checkpoint.

### How each side reads the state back

- **The person** sees, after each session, one line such as "Sophia noted 3 attempts · Review" (counted from that session's records). They also see pages in the book, pending proposals under "Not in the book yet", goals with their criteria, evidence, Sophia's dated reads and their own takes, notes with quote/read/correction, and one next step. "Show record" exposes any raw entry.
- **Sophia** receives, at the start of a session: the goals, the accepted pages it needs (through `read_page`), recent learning records, pending proposals, and the latest `briefing` and `next_step`. The briefing it writes must reference those records, so the person can follow every claim to its evidence and correct it.

## Why each retained part is needed

- **One envelope with an open `kind`:** needed so new knowledge needs no migration while authorship and evidence stay checkable. A fixed list of note types would require a migration per new type; free-form notes would lose authorship.
- **Client-stamped `by`, kind allowlist, and evidence-required rule with references that must resolve:** needed because the model's output is untrusted (AGENTS.md). Without them, Sophia could store a statement as the person's, mark a goal met, or store a free-floating judgment of the person. A list of forbidden kinds was rejected: with an open `kind`, a renamed kind evades it.
- **Verified quotes:** needed so "your words" is true (PLAN.md:44). Cost: one substring check per quote. Risk: typographic substitutions may drop valid quotes; see Verification.
- **Proposals in the transcript, with payload and base hashes:** needed so Accept saves exactly what was proposed (PLAN.md:52) and a stale revision cannot overwrite newer text. A separate proposals file was rejected because the transcript already persists entries in order. Cost: two hash fields and one comparison.
- **Fixed Accept order and the `undo` decision:** needed so the pending list and the book agree after Undo or a crash (PLAN.md:105, PLAN.md:133). Cost: one extra decision value and a check on opening.
- **`replaces` on records and proposals:** needed for corrections ("Was: …"), goal history, and marking a superseded draft, without a separate history store.
- **Briefing records:** needed so the return test (PLAN.md §5, correcting a mistaken account) can show whether a correction carries forward. A separate checkpoint record was rejected: the session stamp already tells which records a checkpoint produced.
- **Session stamp and `through`:** needed so quotes can be limited to the messages a checkpoint covers (which prevents a deleted attempt being recreated) and so the app can count what each checkpoint noted.
- **Chapter structure only in notebook.json:** one source of truth for structure; a chapter field in each page header would duplicate it.

## Delivery sequence

1. Give every transcript entry an id and session; append person and Sophia messages. Exit: a session produces a readable transcript.jsonl.
2. `propose_page` writes a proposal entry; Accept, Defer, and Reject write decision entries; Accept writes the stored payload. Exit: PLAN.md's tool delivery and saving check passes; a deferred or undone proposal is still pending after restart; killing the client during Accept loses no page.
3. The person types a goal; the client writes a `goal` record by the person. Exit: the record appears in a print of the learning log, which shows each record's id beside its quote and text so `/correct` can name it.
4. The session-end checkpoint with all client checks. Exit: a print command shows attempts with verified quotes, and the client prints any rejected records with the reason.
5. The return briefing reads goals, recent records, pages, and pending proposals, and is stored as a `briefing`; the person corrects one claim with `/correct`. Exit: the next briefing references the correction record and reflects it.

## Verification

- A model-supplied `by: person`, a goal `status`, or a decision field in Sophia's output is discarded; a record of an unlisted kind, with no quote and no refs, or a `read` that cites only pages, is rejected.
- A correction made with `/correct` is referenced by the next briefing.
- A fabricated reference (an id that does not exist) is dropped, and a `read` left with no valid evidence is rejected.
- A quote that is not in the referenced person entry, or comes from an earlier session, is removed and the record is shown as a paraphrase.
- Accept writes exactly the stored payload; a revision against a changed page is refused.
- Undo after accepting a revision restores the previous version; Undo after accepting a new page removes it; in both cases the proposal is pending again after a restart.
- Killing the client during Accept and reopening leaves no page lost: a written page missing from notebook.json appears as unfiled.
- Deleting an attempt removes its corrections; Undo restores them before the next message; a later checkpoint cannot recreate it.
- First model-backed run: measure the share of checkpoint quotes that pass the exact check. If fewer than about 90% pass, add Unicode normalization before considering a live note tool.
- End to end: after a week away, Justin can see what Sophia recorded and why, correct one claim, and the next briefing reflects it without rereading the whole chat.

## Deferred until triggered

- Goal proposals from Sophia: add when Justin wants Sophia to draft goals after the CLI run.
- Undo that survives a restart: add if Justin needs to undo a deletion after reopening the app.
- Chapter and experiment proposals: add when the native app introduces them; they would be new proposal targets with the same rules.
- Hand-editable goal or note files: reconsider if Justin edits them outside the app or asks to.
- Deleting words from the transcript itself: add if Justin wants a deleted attempt gone from the conversation too.

## Risks and unresolved decisions

- Whether goal proposals belong in the first run. Owner: Justin. Default here: deferred.
- Sophia's `read` texts could still make ability claims while carrying refs. Measure in the first run; the response is labeled rendering plus deletion by the person, not more filtering.
- The quote check may reject quotes that differ only in punctuation. Measured in the first run as above.
