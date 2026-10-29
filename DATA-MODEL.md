# Notebook data model and implementation boundaries

Documentation reconciled October 25, 2026. Current store behavior is described below; historical proposal rationale and remaining verification are labeled explicitly. This document is not evidence that every scenario has passed.

## Purpose

A notebook holds Markdown pages that both the person and Sophia read, rely on, and correct. Notebook introductions, chapter introductions, Goals, Sophia’s notes and Working memory use that same page object; role and scope are external metadata. Conversations and evidence remain distinct audit records. Each must say who said it, what it rests on, and who may change it, in a form a person can read on screen and an agent can parse without guessing. This plan defines the smallest set of records that does that, and the rules the client enforces so the guarantees hold even when the model misbehaves.

## Scope and exclusions

- Included: the files in a notebook, the record shapes inside them, who may write each, how corrections and deletions work, how page writes are recorded and undone, and how the person and Sophia each read the state back.
- Excluded now: a source catalog, a separate chapter or book object, experiment proposals, chapter proposals, and any record that summarizes the person (level, profile, ability).

## Requirements and constraints

- Sophia saves ordinary content directly with `write_page`; whole-page Goals and About changes instead require person review (the person's decision, 2026-10-14). Authored content-changing page writes are recorded, a revision keeps the version it replaced, and the latest eligible action can be undone. An unchanged request has no Undo; unknown-provenance interrupted disk states are preserved for inspection instead of inferred destructive Undo. Tools never delete pages.
- The person's actual words, Sophia's interpretations, and source material stay distinguishable. (AGENTS.md product principles; SOPHIA.md, teaching and evidence)
- Progress toward goals is shown as evidence, never as a score. Sophia records goals Sophia hears in the conversation (`set_goal`); they are provisional until the person confirms them, and only the person marks a goal met or dropped. (SOPHIA.md, goals)
- Reading or agreeing is not evidence of understanding; assessments stay tentative. (PLAN.md, companion requirements; SOPHIA.md:33)
- Attempts are recorded quietly, reviewable and deletable. A page may quote the person's words, as a block quote.
- Notes reference the conversation instead of copying it; the native client requests a checkpoint through Finish for now or catch-up on return; quitting does not save notes. (PLAN.md, saving and return)
- Storage stays small; complexity is added only for a demonstrated failure or workflow. (AGENTS.md; PLAN.md, minimal storage)
- "Specified, but flexible" and "understandable by both the agents and the humans." (User constraint.)

## Evidence used

- PLAN.md §4 defines the current files: notebook.json, pages, one previous page version, transcript.jsonl, learning.jsonl. Current role pages reuse Markdown and the existing logs; immutable migration snapshots and external whole-page proposal history preserve earlier information.
- The MCP tools are `read_page`, `write_page`, `set_chapter`, `set_goal`, `note`, `set_memory`, `recall`, `about_you`, and `link`. They write through the same store code as the app, under a lock on the notebook. The live `note` and `set_memory` handlers and the client-requested checkpoint all use the store checks; they have distinct timing and quotas described below.
- The historical UI mock (mock/index.html) explored these objects and exposed two earlier design conflicts: two different "next steps" on Goals and Notes, and goal criteria with "Done once / Partly / Not tried" labels that work like a stored score.

## Current files and record rules

### The files

```text
notebook/
  notebook.json            structure: chapters and page order
  pages/<file>.md          current pages (Markdown with a title header)
  pages/<file>.previous.md one previous version per page, for undo
  transcript.jsonl         conversation, tool outcomes and client actions, one entry per line
  learning.jsonl           goals, notes, Sophia's memory, reads, takes, corrections, briefings
  .editing.json            what the person has open in the page editor, if anything (cleared on commit, revert, and launch)

library/.sophia/
  about.jsonl              historical About records (read-only after migration)
  about/                    shared About NotebookStore
    notebook.json           role/scope metadata and stable page identity
    pages/about-you.md      canonical About you Markdown
    pages/about-you.previous.md  one previous version, when present
    transcript.jsonl        the shared page’s own conversation and edit/Undo records
    page-proposals.jsonl    proposed whole-page changes and person decisions
    legacy-about.json       immutable migration snapshot, preserving original evidence
  links.jsonl              links between pages in different notebooks
```

### Memory, About you, and links

Sophia has three layers of memory.

**Working memory and Sophia’s notes (one notebook).** These are ordinary Markdown pages with `memory` and `notes` roles in `notebook.json`. The person reads, edits and undoes changes in the main page pane, using the same source editor and protections as any other page. Notebook context actions and settings links navigate to these pages; there is no second card editor or permanent sidebar row.

Sophia supplies a complete Markdown body through `note` or `set_memory`, plus checked evidence references and an optional exact person quote for notes. Each successful changed body is a normal recorded `write_page` with the existing single previous version and Undo. A `page_evidence` learning record is written as a candidate before the body; only the successful page write and `notebook_page_evidence` link establish that it was applied. A candidate alone is not a save or confirmation. Person edits and imported exact quotes/corrections remain protected.

Fresh conversation context, ongoing turn prefixes and return briefings read the canonical Markdown, including direct person edits. `recall` includes those pages and can still resolve historical record identities and messages. No per-line memory records are a second editable authority.

**About you (shared across the Library).**
- **What it is:** an ordinary Markdown page at `<library>/.sophia/about/pages/about-you.md`, represented by the same `NotebookStore.Page` as other pages, with external role `about` and scope `library`. It uses the same reader, byte-exact section/whole-page editor, personal-line protection, previous version and Undo. The body has no structured record markers.
- **Sophia’s proposals:** `about_you` takes a complete Markdown replacement and an exact quote from the originating conversation. The external proposal records the whole current file hash, proposed body, origin and source evidence. Pending content is visible to Sophia only within its originating notebook, or within the separate About conversation for About-origin proposals. Only the person accepts or rejects; accepting uses the ordinary person-edit path and can be undone until the next eligible page action. A changed file hash stales the proposal; an open editor blocks acceptance.
- **The person’s control:** edit the page directly or inspect the complete formatted current/proposed bodies, optional source and evidence before deciding. Accepting replaces the whole body. The page-level label makes its Library scope explicit even when the sidebar is hidden.
- **The page’s conversation:** one stable `about-you.md` thread in the shared store, independent of the selected notebook. The engine receives an explicit real Library root and shared-About scope. Its two MCP handlers can read only this page and propose About changes; no other notebook reads, links, generic writes, goals, notes or memory tools are available. Existing attended WebSearch remains available; this native scope has no WebFetch bridge. Ordinary return/checkpoint/role-page initialization does not run here.
- **Visibility:** accepted Markdown is supplied to ordinary notebook conversations; internal Almanac preparation still excludes About content. About-origin proposals use `.sophia/about`, which cannot collide with an ordinary notebook leaf name. The model sees only that origin’s pending proposals; the person may review all origins.
- **Migration:** a snapshot is saved before importing person-confirmed text. Legacy provisional records become pending whole-page proposals at their original base and origin; migration never confirms them. Original IDs, quotes and replacement history remain in the snapshot and original `about.jsonl`, now historical rather than a second content authority. Reopening preserves edited canonical bytes and does not rebase old proposals onto newer edits. Initialization has no destructive new-page Undo.

**Links (between notebooks).**
- **What a link is:** a `links.jsonl` record, `{from: {notebook, page?, section?}, to: {notebook, page, section?}, reason}`.
- **How one is made:** Sophia proposes it with `link`. The target page must exist. The person confirms or removes it.
- **Sections:** a page's `##` and `###` headings, outside code fences. A link can point into a section. The section's title must match one on the page (ignoring case, spacing, and punctuation) and is stored as written there. Following a link scrolls to that section.
- **What Sophia sees across notebooks:** only the other notebooks' chapter, page, and section titles. Sophia can read a page in another notebook, or one section of it, only through a confirmed link (`read_page` with `notebook` and optionally `section`).
- **Keeping a notebook out:** a notebook with `"separate": true` in notebook.json isn't listed, linked, or readable from others. It sees none of them, and can't be linked.
- **Locking:** links and legacy Library operations use `<library>/.sophia/.lock`; the shared About store uses its own notebook lock for page edits, proposals and decisions. About migration takes the Library lock before that store lock. Removing a link removes its chain; current About changes use the page editor or reviewed proposals.

Pages are Markdown because people read them as prose. The two logs are JSON Lines (one JSON object per line) because every entry must carry machine-checked authorship. People read and correct them through the app, which also offers "Show record" on any card so the raw line can be audited.

Page bodies and Sophia's replies use LaTeX math within Markdown: `$...$` for inline expressions and `$$` on separate lines around display equations. The reader also accepts `\(...\)` and `\[...\]`. Store the original Markdown and TeX, not rendered HTML; rendering is local and does not execute page HTML, JavaScript, or LaTeX programs. Existing Unicode notation remains readable.

Pages may also contain music as ABC notation in ```` ```abc ```` fences ([MUSIC.md](MUSIC.md)), optionally starting with one line of JSON options and a `---` line. The fence's text is the record; the reader typesets it locally with abcjs, and nothing about the rendering (SVG, warnings) is stored. Warnings reach Sophia only through Sophia's next turn's context.

### Structure: notebook.json

```json
{ "chapters": [ { "number": "0", "title": "Foundations", "pages": ["0-0-probability.md", "0-1-entropy.md"] } ],
  "unfiled": ["roadmap.md"],
  "overview": "notebook-introduction.md",
  "pageProperties": {"notebook-introduction.md": {"role": "notebook", "scope": "notebook"}} }
```

`learning_ids` is a small per-prefix high watermark, for example `{"n": "37", "g": "4"}` (decimal strings avoid JSON number precision loss). Learning writes reserve the next ID here under the notebook lock before appending; failed writes may leave gaps. Deletion preserves the watermark, and reopening never recycles an issued identity. Legacy notebooks seed the floor from existing learning IDs and known structured references, not prose. Restore refuses an ID collision before changing records and keeps the pending Undo available with an error. Existing duplicated identities are not guessed apart or repaired automatically; preserve the notebook and a known-good backup before resolving past ambiguity.

This is the only place chapter membership and order live. A page's header holds its title and sources, not its chapter.
- **Chapter number:** optional. Numbered chapters are kept in number order.
- **Page numbers:** a page's section number, if any, is part of its title ("0.1 Entropy"); the app sets it apart in the header and contents.
- **Who files pages:** Sophia puts pages in chapters with `set_chapter`, or with `chapter` on `write_page`. Moving a page never changes its content. Chapters with an introduction keep their identity and introduction even when their child list becomes empty. Legacy empty chapters without an introduction stay hidden and can still be removed. An explicit chapter rename updates the introduction title only while that title still matches the previous default; this is an ordinary recorded revision. Customized introduction titles and their Undo remain unchanged by filing or renaming the group.

Notebook and chapter introductions are ordinary Markdown pages with the same file identity, source editor, checked writes, person-edit protection, previous version and Undo as other pages. `overview` names the notebook introduction; each chapter may have an `intro` filename. The file is also the chapter's stable identity. `pageProperties` adds role and scope without putting structural markers in the Markdown body; those labels grant no additional agent permissions. Roles currently reserved are `content` (legacy default), `notebook`, `chapter`, `about`, `goals`, `notes` and `memory`; scope defaults to `notebook`.

On opening the native notebook, introduction filenames are reserved under the lock before initially empty files are created. Reopening resumes those same reservations and never regenerates an existing body. A one-time `notebook.before-page-roots.json` keeps the original ordering metadata; existing Markdown and JSONL are preserved. Initialization is a client `initialize_page` record, not an authored change with destructive new-page Undo. Later writes and edits use normal page actions. The outline is a current projection of membership, attached after the authored body; it is never inserted into the source or generated on navigation.

### Pages

```markdown
---
title: Why the Fiedler vector splits a graph
---
Prose and mathematics.

> "The bridge is the only edge across the cut…"  <!-- quote: t-0412 -->
```

The current `write_page` API writes title frontmatter and a Markdown body; citations, source locations and inspection limits belong in the body, not a client-validated `sources` header. Older or hand-authored extra frontmatter is not a source-verification schema. The example quote above is illustrative; a real quoted attempt names its actual transcript entry so its attribution remains inspectable.

### The conversation log: transcript.jsonl

Every entry: `{ "id", "at", "role": "person" | "sophia" | "tool" | "client", ... }`.

- Messages carry `text`, and each belongs to a session (`session`), one app launch.
- **Threads.** Each page has one conversation thread, and so does the notebook's Contents. Chapter introductions use their actual page files; notebook introductions retain the legacy Contents thread (`""`). Shared About has its own store and `about-you.md` thread. An entry's `page` names its thread by the page's file name; `""` means Contents. An entry with no `page` was written before threads existed and also belongs to Contents. Entries take their thread as follows:
  - Messages, WebSearch, WebFetch, `goal_noted`, `stopped`, `replied` and the tool server's entries take the conversation they came from, not the page on screen. A reply that finishes after the person moves on stays where it began. The tool server is launched for one thread and stamps that thread on what it writes.
  - Entries that act on a page take that page: an edit, a release, a refused write, an undo of a revision or edit, and an undo of a release (which takes the edited page). An undo of a new page takes the conversation where the page was written, since the page itself is gone.
  - Checkpoint, briefing and memory entries belong to Contents.

  A file name never changes once used: a revision keeps its file whatever the title becomes, moving a page between chapters changes only notebook.json, and a new page never reuses a file name already in the transcript.
- A page write is a `tool` entry: `{ "tool": "write_page", "file", "title", "revised"?: true, "tool_use", "hash", "page" }`. `file` is the page written. `page` is the thread the request came from, which may be another page. `hash` is the SHA-256 of the page's bytes as written.
- A byte-identical revision records the same `write_page` shape with `unchanged: true`, without rewriting the page. It is the latest action and ends earlier Undo, but has no Undo of its own. Current and existing previous bytes are retained; unchanged requests do not establish authorship or hide unknown-provenance inspection.
- **An unrecorded disk change** uses the compatibility shape `{ "role": "client", "tool": "write_page", "recovered": true, "file", "page": <file>, "hash", "revised"?: true }`. On opening, the app indexes two possible interruption states; neither hashes nor orphanhood establish who authored them:
  - a page whose bytes don't match the latest recorded hash while `.previous.md` does (the copy was made, then the crash came);
  - a page file listed in neither notebook.json nor the transcript.

  An outside edit or outside-added page can match these states too. The entry records unknown provenance, never an authored Sophia revision or conversation activity, and offers no destructive Undo. Current and previous bytes remain available for inspection and manual restoration through the page editor until a later content-changing recorded write or edit replaces the single previous slot.
- An undo is a `client` entry: `{ "purpose": "undo_page", "entry": "t-0042", "file", "page", "hash"? }`. `hash` is the SHA-256 of the restored page; there is none when the undo removed a new page.
- When Sophia records a goal, the app adds `{ "role": "client", "purpose": "goal_noted", "record": "g-3", "page" }` so the conversation shows it where it happened.
- **Legacy/proposed clear boundary.** `{ "role": "client", "purpose": "clear", "page" }`. Existing context readers recognize this boundary, but no current source writes it and no native fresh-start action is implemented. The historical design called for a successful checkpoint before clearing; its queued-message and failure behavior below is proposed, not shipped.
- **An interrupted app/session shutdown.** `{ "role": "client", "purpose": "interrupted", "page" }` keeps the saved question eligible for explicit Retry after reopening. It does not claim a delivered reply or successful checkpoint. An explicit Stop keeps its existing intentional `stopped` boundary and does not become an unanswered question automatically.
- **A finished reply.** `{ "role": "client", "purpose": "replied", "page" }`, written when Sophia's turn in that thread ends normally.
- The person's edit to a page (EDITING.md) is `{ "role": "person", "purpose": "edit_page", "file", "page": <file>, "title", "section", "index"?, "hunks": [{ "before", "after" }], "hash" }`.
  - `section` is the section's title, `"(opening)"` for the text before the first section, or `"(page)"` for the whole body; `index` is the section's position.
  - Hunks are whole changed lines, joined with newlines.
  - An edit is not a message: it is never quoted, checkpointed, or treated as evidence of understanding.
- A refused `write_page` is `{ "role": "tool", "tool": "write_page", "refused": true, "reason": "open" | "protected" | "quote", "file", "page": <file>, "section", "current", "edits", "edit"?, "why"? }`. Nothing on the page changed; `current` is the section's text that was kept.
- `{ "role": "person", "purpose": "release_edit", "entry": <edit_page id>, "page" }` lets Sophia change that edit's lines; `{ "role": "client", "purpose": "undo_release", "entry": <release id>, "page" }` takes it back.

**What a thread shows and what Sophia receives.** Nothing below is stored; each is worked out from the entries above when the thread is shown or a message is sent. A thread's "messages" are its person and Sophia entries without a `purpose`.
- **What Sophia has word for word.** A thread's messages from just after the latest checkpoint's `through`, counted from the position of `through` rather than of the checkpoint entry, because a message sent while notes were being written falls between the two. Before that point Sophia has Sophia's notes. Sophia also gets the thread's last 6 messages at or before `through` (the carried exchanges). Nothing before the thread's latest `clear` is sent again. The message being answered is not repeated in the context; it arrives as the turn itself. Sophia's context also shows, where they happened, one line for each page write, refused write and release in the thread, plus each WebFetch response (failed/declined requests are labeled as outcomes, not extracted passages); these are not messages. None of this is marked for the person: a thread reads as one conversation, and the exact words of anything older come back through `recall`.
- **Earlier on this page (proposed UI).** Fold a thread's entries before its latest legacy/proposed `clear`; the current native app does not show this control.
- **Creating exchange (implemented context helper; proposed card UI).** A page's origin is derived from the `write_page` entry that created it, and remains in the transcript. Its `page` names the thread; the person's message before it in that thread is the question; Sophia's first text in that same turn, before the next person message, is Sophia's first line, and if there is none the card shows the question alone. The derived exchange is supplied in that page thread's context. A persistent “Started from” card/link and folded-history reveal are not present in the current native UI; a page with no creating entry has no derived exchange.
- **Opened source evidence.** A `role: "tool", tool: "WebFetch"` transcript entry retains the exact provider `content`, `is_error`, requested `url` and `tool_use_id` in the originating conversation. `returned_url`, `http_status` and `location` are included only when the actual tool result reports them. The viewer shows plain selectable extraction text, distinct from Sophia's interpretation; it does not execute HTML or claim raw full text/independently verified quotation. Approval itself is temporary process state, never a notebook allowlist. Denied/failed tool outcomes are evidence too.
- **An unfinished question.** The latest person question in a thread without a later `replied`, `stopped` or `clear` boundary is eligible for explicit **Retry** when that thread has no running or queued reply. It shows **Not answered yet**, or **Reply interrupted** if partial Sophia text exists. Retry reuses the exact saved id/text and stores no new person entry. Older questions without a `page` field are eligible when they have no later reply or tool output, or when page-stamped reply or tool output identifies a newer retry attempt (shared-memory housekeeping is excluded); genuinely old output is ambiguous because old clients wrote no completion markers. A crash after a complete-looking reply but before `replied` is recorded still counts as interrupted.

**The person's edits.** The person edits one range of a page at a time. While it is open, `.editing.json` records it (`{session, file, key, section, text}`), and a `write_page` that doesn't keep that text intact is refused. A commit is spliced in by lines: every other byte of the file, frontmatter included, stays as it was; a commit that changes nothing writes nothing. The range is found by the hash of its text when the editor opened, so a commit against a range that changed since is refused and the person's text stays in the editor. A saved edit keeps the previous version and can be undone like a page write, by the rule below.

**Protected lines.** A page's protected lines are the `after` lines (not blank) of its `edit_page` entries, not undone or released, that still appear on the page. Nothing else stores them. `write_page` refuses a revision that drops or changes any of them (compared as whole lines, anywhere on the page), and also one that drops or changes a block quote of the person's words (the quote lines around a `<!-- quote: t-… -->` marker). A refusal is recorded and returned to Sophia with the person's current text. Releasing an edit lifts protection from that edit's lines only. If the person deletes or changes their own line, it is no longer protected.

A page write saves in a fixed order. Each entry records the page's `hash`:
- **A revision:** copy the current version to `.previous.md`, write the page file, then append the transcript entry.
- **A new page:** write the page file, append the transcript entry, then add the page to notebook.json.

**On opening a notebook,** the app, holding the notebook lock, first indexes matching unrecorded disk changes with unknown provenance (checking files against notebook.json and the transcript as they were at launch), and only then lists any missing page as unfiled. It preserves both versions and records a given observed state once. The order matters: a page listed as unfiled first would no longer be recognized as previously unrecorded.

An interruption before the write's transcript entry can therefore leave inspectable current and previous versions, but cannot safely earn automatic Undo. Its author is unknown, even for a genuine crash-before-entry; the app offers read-only previous-version inspection and copy-into-editor guidance instead. Outside edits are never inferred to be authored Sophia writes or made destructively undoable. Pages whose latest entry predates `hash` are left as they are.

**Undo.** Undo restores `.previous.md` for a revision or an edit, replacing the page in one step. For a new page, it removes the page from notebook.json and then deletes the file; anything said in that page's conversation stays in the transcript and is reachable through `recall`. One rule covers recorded authored actions on a page: the latest of its writes, edits, releases and undos can be undone, until the next of these on that page, whatever is said in any thread. Undo is one way: an undo cannot itself be undone, because it consumes the previous version. Nothing records that an action is undoable; it is worked out from what is stored, so it survives relaunch.

A write is undoable when all of these hold:
- it is the latest non-refused write, edit, release or undo for its file;
- the page's current bytes still match its `hash`;
- for a revision or edit, `.previous.md` exists and differs from the page;
- the entry is neither unchanged nor an unknown-provenance `recovered` entry (including markers written by earlier versions).

The hash check stops a crash between a page write and its entry from making an earlier write look undoable. The `.previous.md` check stops a crash between the copy and the write from offering an Undo that would change nothing.

If the app quits after deleting a new page's file but before recording the undo, the page is gone as asked, and nothing records it. Entries written before `hash` existed offer no Undo after a relaunch.

A release (below) follows the same rule: it can be undone only while it is the latest write, edit, release or undo on its page.

Older notebooks may hold `proposal` and `decision` entries from when pages were accepted. On opening, any proposal nobody accepted or discarded is saved as a page and marked with a `filed_draft` entry.

### Canonical Goals, Notes and Working memory pages

`NotebookStore.ensureNotebookPages` reserves each role’s stable filename in `notebook-pages-migration.json` and snapshots the complete original learning records before initializing Markdown. Confirmed goal ancestors become prose; unresolved Sophia goal versions become external whole-page proposals against the original body hash. Original IDs, quote/evidence metadata and JSONL remain history. Restart is idempotent and never regenerates a body over later person edits. Missing previously initialized files fail rather than being silently recreated. Migration protection entries carry `migrationSource`, no authored-action hash or Undo, and never appear as new person activity.

`set_goal` proposes the complete Goals body against a whole-file base hash. Only the person accepts or rejects; any intervening edit makes a proposal stale. Accept uses the ordinary whole-page checked person edit and Undo. Goals have no required body markers, criterion parser or special status controls. A person can describe an aim or its completion in normal prose. Old `g-…#criterion` references resolve historical evidence, never a claim about later prose.

Checkpoint JSON is `{ "notes": "complete Markdown or null", "memory": "complete Markdown or null", "refs": ["checked evidence IDs"], "quote": "optional exact person words" }`. `null` leaves a body unchanged. Evidence and protection for both pages are validated before writes; the covered `through` boundary advances only after both succeed. A later persistence failure may leave an earlier recorded, undoable body write while the boundary remains pending; retry uses current Markdown and is not a cross-file transaction. Checkpoint writes neither enforce nor consume the live Notes quota. A nonmatching quote is removed and tagged as a paraphrase only when valid references still support the body; no quote and no valid references is refused. Goals proposals still require a matching quote. Automatic checkpoint/briefing prompts exclude full `page_evidence` body snapshots, while keeping current Markdown and the original records in history. Ordinary `write_page` rejects these reserved roles so it cannot bypass the checked proposal/evidence paths.

### Historical learning records and checks

The following envelope, structured kinds and compatibility mutations describe retained historical evidence and legacy checks. They are not current page authoring controls. Current content is the Markdown described above; the native history disclosure and evidence resolver retain access to the original records.


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

Historical kinds retained for evidence:

| Kind | Written by | Required beyond the envelope | Shown as |
|---|---|---|---|
| `goal` | Sophia (provisional) or person | `text`; `status`: `working` \| `met` \| `dropped`; optional `criteria` (list of plain text); optional `quote` and `refs` when Sophia wrote it | Goals |
| `take` | person | `refs` to a goal or criterion | "Your take" beside Sophia's read |
| `correction` | person | `replaces` a Sophia record | Person's text in place of Sophia's, with "Was: …" beneath; the original record's `quote` and `refs` still show |
| `attempt` | Sophia | a verified `quote`; `text` is Sophia's read of it | Note: your words, then Sophia's read |
| `read` | Sophia | `refs` to at least one `attempt` record or person transcript entry; about a criterion, also `refs` to it | Sophia's dated interpretation, with its actual evidence |
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

### Historical structured record delivery and compatibility checks

1. **The person writes** goals, confirmations, takes, and corrections through the app. The client stamps `by: person`.
2. **Sophia writes goals through `set_goal`** during the conversation. The store stamps `by: sophia`, keeps the current `status` (new goals are `working`; Sophia cannot mark one met or dropped), keeps existing criteria and only appends new ones, keeps a `quote` only if it appears exactly in one of the person's messages, and references the person's latest message.
3. **Sophia writes notes in three ways**, all through the same checks:
   - **During the conversation**, with the `note` tool:
     - Kinds `attempt`, `question`, `follow_up` and `background`.
     - At most 8 new notes per session; revising one doesn't count.
     - The store finds the person's message that a quote comes from: first in this conversation, then anywhere in this session. A goal Sophia records cites the latest message in the conversation Sophia is answering.
     - Sophia may revise Sophia's own notes, for example to close a follow-up, by writing a record that `replaces` the old one. Sophia may not revise a note the person corrected.
     - Each note gets a `{role: "tool", tool: "note", record}` transcript entry, shown as one line in the conversation.
   - **The checkpoint:** a list of `attempt`, `read`, `question`, `follow_up`, `background` and `next_step` records, adding only what the live notes missed.
   - **The return briefing:** one `briefing` record.
   - **Checkpoint scope:** a checkpoint covers the person's messages since the previous checkpoint, in every thread and across sessions. A session is one app launch, and one sitting can span several.
   - **When it runs:**
     - at Finish for now;
     - when the person comes back to a notebook whose last messages have no notes, before the briefing;
     - automatic long-thread checkpointing remains a design direction; the current native callers are Finish for now and return catch-up.
   - **How it runs:** in its own short-lived conversation process, never in a thread's. Its entries belong to the Contents thread. It is not limited by the `note` quota. The UI can show checking activity or connection failure; no private provider context is presented as saved notebook data.
   - **What it is shown:** the request lists each message with its page, and every record written since the previous checkpoint entry, whatever the session, as already noted. A crash between saving a checkpoint's records and its entry can still leave repeated records, which the person can delete.
   - **If it fails:** an engine error, unreadable reply or wholly rejected reply writes no accepted learning records, memory or successful checkpoint/cursor entry. A persistence exception is different: earlier notes or memory may already be on disk when a later write or completion marker fails. The boundary does not advance; explicit Finish reports the uncertainty and asks the person to inspect Sophia's notes before trying again. Retry is not transactional or idempotent and can repeat a note. Automatic return failures stay quiet. No current clear producer exists. See [SOP54 checks](app/checks/sop54-finish-feedback.md).

     A reply with no records is valid: Sophia found nothing worth noting, and the entry is written. A reply whose records the checks all reject is a failure, and nothing moves.
   - **The checkpoint's transcript entry** names the last message it covered in `through` and marks `catch_up` when it ran on return. Messages a checkpoint covered are never offered to a later one. Every thread's word-for-word context starts just after `through`.
   - **Coming back** means the latest message by the person or Sophia in any thread (a briefing counts) is at least 6 hours old. A shorter gap gets neither catch-up notes nor a briefing. The briefing belongs to the Contents thread.
   - **The briefing** is at most two sentences: the one thread worth picking up, then one offer. It may be empty, and then nothing is shown.

   The client applies the same checks to both:
   - stamps `by: sophia`, `id`, and `at`, and discards any `by`, `at`, `status`, or decision fields Sophia supplied;
   - accepts only the kinds `attempt`, `read`, `question`, `follow_up`, `background`, `next_step`, and `briefing`;
   - drops any reference that does not resolve to an existing transcript entry, record, page, or goal criterion, and applies the next two checks to what remains;
   - rejects a record with no `quote` and no `refs` (an interpretation with nothing behind it cannot be stored), and rejects a `read` that does not reference an attempt or a person's message (reading a page is not evidence of understanding);
   - rejects a `briefing` over 60 words; no unchecked briefing text is shown;
   - accepts a `quote` only if its entry is one of the `person` messages the checkpoint covers and the quoted text appears in it exactly (ignoring differences in whitespace). Otherwise the quote is removed, and the app shows that record as "Sophia's paraphrase", without quotation marks;
   - does not save rejected checkpoint items as learning records. The CLI can print rejection reasons; separate connection/tool failure evidence is not a successful checkpoint or accepted interpretation.
4. **Page writes** follow the transcript rules above.

These checks are what make "Sophia never marks a goal met", "your words are quoted exactly", and "no summaries of you" true in code, not only in the prompt.

### Historical record deletion and undo

The person can delete any learning record. The client removes the record and every record whose `replaces` chain leads to it, then rewrites learning.jsonl atomically. Undo holds the removed records in memory until the person's next message, in any thread. The conversation itself still contains the words, and the app says so. Because checkpoint quotes must come from the session being summarized, a deleted attempt cannot be recreated by a later checkpoint.

Page writes and edits are undone by the rule in "The conversation log", not this one.

### How each side reads the state back

The person reads every current role page in the main reader, with the same source editor and Undo. Goals, Notes and Working memory open from notebook context/settings actions; they add no permanent sidebar rows. The page’s notebook context remains visible when the sidebar is hidden. Notebook history/evidence and source references expose original JSONL, exact quotes, interpretations and IDs without a second authoring surface.

Ordinary fresh context includes current Goals, Notes, Working memory, accepted About, the selected page and that page’s carried/window conversation. Pending proposals are explicitly unaccepted and origin-scoped. Ongoing prefixes refresh canonical prose and relevant page changes; the engine does not silently regain unrelated threads’ conversations. Saved child outlines are deterministic metadata projections, never generated prose. Other notebooks’ title indexes exclude auxiliary role pages; explicit confirmed links still govern cross-notebook reads. About’s dedicated scoped conversation remains separate as described above.

## Why each retained part is needed

- **One kind-tagged envelope:** keeps authorship and evidence checkable across goals, notes and corrections. The client still allowlists accepted kinds; extending those checks need not introduce another storage format.
- **Client-stamped `by`, kind allowlist, and evidence-required rule with references that must resolve:** needed because the model's output is untrusted (AGENTS.md). Without them, Sophia could store a statement as the person's, mark a goal met, or store a free-floating judgment of the person. A list of forbidden kinds was rejected: with an open `kind`, a renamed kind evades it.
- **Verified quotes:** needed so "your words" is true (PLAN.md, companion requirements). Cost: one substring check per quote. Risk: typographic substitutions may drop valid quotes; see Verification.
- **`replaces` on historical learning records:** preserves earlier corrections and goal confirmation chains. Current proposal decisions and canonical Markdown do not use those chains as a parallel editable authority.
- **Briefing records:** needed so the return test (PLAN.md §5, correcting a mistaken account) can show whether a correction carries forward. A transcript checkpoint entry separately records the covered message boundary; the session stamp alone cannot establish that boundary.
- **Session stamp and `through`:** needed so quotes can be limited to the messages a checkpoint covers (which prevents a deleted attempt being recreated) and so the app can count what each checkpoint noted.
- **Chapter structure only in notebook.json:** one source of truth for structure; a chapter field in each page header would duplicate it.
- **`page` on transcript entries, stamped where each entry is written:** needed so each page's thread shows only its own conversation, refusals and edit markers, and so a page Sophia writes from another page's thread names where it started. Two simpler options were rejected:
  - Assigning entries by position fails: a message sent in one thread while Sophia answers in another lands among Sophia's later entries.
  - A file per thread was rejected because the transcript already orders everything.

  A missing `page` means Contents, so older notebooks need no migration.
- **The legacy/proposed `clear` entry:** retained in context readers for historical records. A future fresh-start producer would need an explicit workflow; changing the app-launch session alone would not express its thread boundary.
- **The `replied` entry:** needed so a reply cut off by a crash shows as interrupted, while a turn that ends in a page write does not. Two simpler options were rejected:
  - Judging by the last entry's author fails both cases, and also when checkpoint entries follow a message.
  - Keeping it in memory loses it in exactly the crash.
- **`hash` on page writes, edits and undos:** needed so Undo, now worked out from records and kept across relaunch, can't be offered for a write a crash has already overwritten, and so unrecorded disk states can be found without inferring authorship. Cost: one SHA-256 per write. Rejected: file modification times, which have seconds resolution and are changed by other programs.
- **Unrecorded disk states:** the existing `recovered` flag indexes unknown provenance without a new record kind. Hashes and orphanhood do not prove who wrote a file. Current and previous bytes are preserved until a later content-changing recorded write or edit replaces the single previous slot; unchanged requests retain both versions.
  - Inferred destructive Undo was rejected because a copy-success/write-failure followed by an outside edit is indistinguishable from a genuine crash-before-entry.
  - Automatic restoration would require additional durable intent evidence. A write-ahead journal is deferred; the current boundary is inspection and manual restoration, not automatic interrupted-write Undo.
- **No stored provider session, cursor, or undo state:** Sophia's context is rebuilt from these records whenever a thread's conversation starts, so storage stays independent of provider sessions. A map from threads to provider sessions waits on the test in PLAN.md §4.

## Historical proposal rationale and delivery sequence

The original ACP/HTTP design persisted page proposals and payload/base hashes, then used Accept/Defer/Reject and a fixed Accept order. That rationale described a different page workflow. Current pages use direct `write_page`, current/previous hashes and the Undo rules above. Older `proposal`/`decision` entries remain readable; the existing `fileUndecidedDrafts` compatibility path files undecided legacy drafts on opening. No current native Accept queue or HTTP proposal server is required.

The following original CLI delivery sequence is retained as history, not instructions for new implementation:

1. Give every transcript entry an id and session; append person and Sophia messages. Exit: a session produces a readable transcript.jsonl.
2. `propose_page` writes a proposal entry; Accept, Defer, and Reject write decision entries; Accept writes the stored payload. Exit: PLAN.md's tool delivery and saving check passes; a deferred or undone proposal is still pending after restart; killing the client during Accept loses no page.
3. The person types a goal; the client writes a `goal` record by the person. Exit: the record appears in a print of the learning log, which shows each record's id beside its quote and text so `/correct` can name it.
4. The session-end checkpoint with all client checks. Exit: a print command shows attempts with verified quotes, and the client prints any rejected records with the reason.
5. The return briefing reads goals, recent records, pages, and pending proposals, and is stored as a `briefing`; the person corrects one claim with `/correct`. Exit: the next briefing references the correction record and reflects it.

## Verification: current checks and remaining observations

The commands in [app/README.md](app/README.md) exercise the existing core/store and reader checks. Their existence is not a passing run: [the package report](research/2026-10-25-packaged-release/README.md) and the issue-specific native reports pin actual source epochs and limits. The list below mixes source-supported checks and still-required workflow/human observations; it is not a completed acceptance report. `/correct`, Accept and pending-proposal scenarios refer only to the historical CLI design, not current native controls.


- A model-supplied `by: person`, a goal `status`, or a decision field in Sophia's output is discarded; a record of an unlisted kind, with no quote and no refs, or a `read` that cites only pages, is rejected.
- A correction made with `/correct` is referenced by the next briefing.
- A fabricated reference (an id that does not exist) is dropped, and a `read` left with no valid evidence is rejected.
- A quote that is not in the referenced person entry, or comes from an earlier session, is removed and the record is shown as a paraphrase.
- A recorded direct revision keeps its previous version; protected/open edits are refused. Undo is available only for the latest eligible authored action with matching disk hashes.
- Undo of a recorded new page removes it; undo of a revision restores the previous version. It does not create a pending proposal.
- An interruption before recording is unknown provenance: preserve current/previous bytes and index an orphan as unfiled, without destructive Undo.
- Deleting an attempt removes its corrections; Undo restores them before the next message; a later checkpoint cannot recreate it.
- Entries from two threads, interleaved, are shown each in their own thread. Entries with `page: ""` or no `page` show in Contents. An edit, a refusal and an undo show in the page they act on.
- A message sent while notes are being written stays in its thread's word-for-word context, and the message being answered is not also in the context.
- P's Undo is still offered after a message in Q and after reopening. In each of these cases the crashed state is handled correctly:
  - **write cut off before its entry:** indexed with unknown provenance and not undoable; current and previous bytes are inspectable and preserved. A new unrecorded page is visible and unfiled without deletion Undo. Outside-added pages and copy-success/write-failure followed by outside edits receive the same non-destructive treatment, including old recovered markers on reopen;
  - **cut off after the copy to `.previous.md`:** no Undo;
  - **undo cut off:** the page is replaced in one step, so it never goes missing.
- A turn ending in a page write is not interrupted; one cut off after Sophia's text but during a tool call is.
- A checkpoint reply that can't be read writes nothing. One whose records are all rejected writes nothing and cancels a waiting clear; one with no records at all counts. A queued message is never shown as interrupted.
- After a clear, nothing before it is sent to Sophia again. A clear whose notes fail doesn't happen, leaves the thread unchanged, and leaves a message typed meanwhile unsent in the composer. A message typed while a clear's notes are being written is sent after the clear. An undone new page's file name is not reused.
- After a clear, the open step of the derivation that preceded it (scenario 5 in the charrette fixture) can still be continued from Sophia's notes.
- After an edit is released, only the release is undoable, not the edit; after an undo, nothing on that page is.
- A page written from another conversation still has its creating exchange in context after a checkpoint, and its card's first line never comes from a later turn.
- A page write succeeds, the turn is cut off, and Ask again produces no duplicate page.
- In a long mathematical exchange, after an automatic checkpoint, the next step is still right and one exact older attempt comes back through `recall`; record the delay.
- Measure checkpoint quote fidelity separately from whether the live `note` tool exists (it is implemented). Whitespace is normalized for quote matching; broader Unicode normalization needs a demonstrated quote failure, not an old pre-note-tool gate.
- End to end: after a week away, Justin can see what Sophia recorded and why, correct one claim, and the next briefing reflects it without rereading the whole chat.

## Deferred until triggered

- Undo of a record deletion that survives a restart: add if Justin needs to undo a deletion after reopening the app. (Page undo already survives restart; see "The conversation log".)
- A map from threads to provider sessions in notebook.json: add only if all of these are shown:
  - a resumed session receives fresh context;
  - a bad session id fails detectably;
  - a rebuilt thread loses a step a resumed one kept (PLAN.md §4).
- A proposal/Accept interface for chapters or executable artifacts is not implemented. Current `set_chapter` directly files existing pages without changing their bytes; execution/viewer work requires its own demonstrated workflow and restricted boundary.
- Hand-editable goal or note files: reconsider if Justin edits them outside the app or asks to.
- Deleting words from the transcript itself: add if Justin wants a deleted attempt gone from the conversation too.

## Risks and unresolved decisions

- Sophia's `read` texts could still make ability claims while carrying refs. Measure in the first run; the response is labeled rendering plus deletion by the person, not more filtering.
- The quote check may reject quotes that differ only in punctuation. Measured in the first run as above.

## Optional Sophia’s Almanac

An explicitly created/opted-in Almanac stores a versioned `almanac` object in its existing `notebook.json`; a notebook’s name alone never opts it in. Settings contain enabled, automatic (initially false), pause-daily, local minute-of-day, explicitly selected notebook names, and person-supplied topics. The small run state contains a configuration revision, last attempted local date, current UUID/scope, phase/error, and latest/waiting recorded entry identities. No new journal, learner profile, inferred ability or goal is created. Pausing daily preparation still permits an explicit manual entry; disabling rejects both. Config changes invalidate the old run.

The dedicated generation context contains only selected existing non-separate notebook **names**, explicit topics and prior Almanac entry titles. It excludes page/section titles and bodies, personal history, About you, notes, memory and goals. A separate Almanac draws no other notebook names; typed topics still work. Missing/corrupt metadata fails closed. Generation has no notebook MCP tools, and cannot bypass confirmed links to read another notebook. This is the explicit agent-authored exception to ordinary inquiry-led page creation.

Preparation uses the existing intended-route check/process ownership, WebSearch only, and no unattended WebFetch. Actual search inputs/results are retained as `WebSearch` transcript records with `purpose: almanac_source`, run and tool-use identities. Search summaries/candidate links remain distinct from opened passages, general knowledge and Sophia’s synthesis. The host supplies an evidence footer from actual returned text; empty, missing and failed results cannot support a search-summary draft, while a nonempty summary need not contain a URL. Only the observed performed-search result objects and their HTTP(S) URL fields supply candidate links; query echoes, bare domains, budget refusals and unknown formats do not. A performed result with a nonempty summary needs no URL. Provenance is not factual certification. A draft that needs an opened source is not marked ready.

The host validates one complete response and saves a **new** ordinary page through `writePage`, with `tool_use: almanac:<run UUID>`. Existing recorded Undo and later person-edit protection apply. The ready callback follows a verified recorded save, never merely a started request. If an exact recorded run cannot yet be exposed after a listing failure, new preparation is refused pending inspection/reopen, while disabling/deselection still applies and retains the exact pending identity. An interrupted metadata completion reconciles only an exact recorded run; later person edits retain that identity and are preserved. An unrecorded disk change remains unknown provenance. Agent-commissioned entries have no inherited person creating question. Opening clears only the matching waiting marker and means opening, not understanding. Manual entries may be requested despite an earlier waiting page; the one-waiting restriction governs automatic preparation only.

Automatic admission requires enabled/automatic consent, disclosure acknowledgement, an awake/open app, time reached, no active run/waiting page, and no attempt on that local date. The reservation is persisted under the notebook lock before delivery. Skipped days do not create catch-up entries. Failure/cancellation requires explicit Retry, including on later days. The app-level timer/wake/notification behavior is integrated separately; this Core contract does not schedule closed-app work or grant notification permission.

## Person-owned recoverable removal

Only the person can delete ordinary content pages (including Almanac entries) or move a whole notebook to macOS Trash. No deletion or restoration tools are exposed to Sophia. Notebook/chapter introductions, Goals, Sophia’s notes, Working memory and About you retain their required page identities: use the ordinary editor to clear their bodies. Removing one content page never deletes its chapter or chapter introduction.

Page deletion copies the exact Markdown and any single previous version into `deleted-pages/<UUID>/`, with `record.json` retaining the title and original filing position. Under the notebook lock it records a person `delete_page` action, adds a `deletedPages` reservation to notebook metadata, removes the page from active ordering, and removes the current/previous files from `pages/`. The durable reservation prevents orphan reconciliation and stale revisions from recreating the page, including interrupted removals with physical leftovers. Original transcript/learning/source evidence and proposals remain historical. New pages do not reuse historical filenames. Deletion and restoration end old page Undo eligibility.

Restore… beside the deleted-page count in the notebook’s Contents opens the recovery list. Choosing a page restores original bytes, previous version and filing position (or unfiled if the original chapter is unavailable), without overwriting different existing files. Byte-identical interrupted-removal leftovers are allowed. A person `restore_page` action is recorded; retained archive copies remain recovery evidence. There is no permanent page-purge action or promise to erase copies in conversations, prompts, backups or history. An interrupted archive operation may leave a recovery copy accessible in Finder even if it did not reach the list; original files are kept until the durable removal reservation exists.

Notebook removal waits for the app’s owned conversation/checkpoint and Almanac processes to stop, then holds the notebook lock through the macOS Trash move. A store captures the directory’s birth identity and a writer generation; missing/replaced/moved directories and pre-removal cached stores cannot write after removal or Put Back. MCP opens existing notebooks only, never recreating a missing directory. Page removal also advances the writer generation. Supported removal is through this app in one running Library; arbitrary concurrent external file edits are not supported sync.

Links involving removed page/notebook identities are retired as person-authored replacement records, preserving their history but ending grants. Restoring the target does not silently reconfirm permission. Removed notebook names are also removed from Almanac source selections. A trashed Almanac is saved disabled; after Finder Put Back, explicitly enable preparation again. Whole-notebook restoration uses Finder Put Back or the documented empty-destination folder recovery, with Sophia quit; do not merge or overwrite another notebook. About you and Library link history live separately in `.sophia` and do not move with an ordinary notebook.
