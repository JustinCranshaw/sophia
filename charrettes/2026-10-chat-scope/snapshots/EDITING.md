# Editing pages plan

Status: Phase 1 built and checked by machine, October 15, 2026; the by-hand checks below are still open. Revised after a three-voice UX review (Design, Product, CEO); Justin chose to build now rather than wait for a week's log.

The person can edit pages directly. Reading stays the default. Editing is a deliberate mode, scoped to one section, and byte-exact: nothing changes in the file except what the person typed. Sophia sees each edit, and the store, not the prompt, stops her from overwriting the person's words.

This reverses the earlier "no conventional editor" scope. It came from outside research (October 2026). That research was documented and anecdotal; nothing in it was tried hands-on.

## What exists today

Source inspection, October 15, 2026:

- Each page renders in one `WKWebView` (`SophiaReader`): markdown-it 15.0.2, texmath, KaTeX 0.19.0, DOMPurify, a strict CSP, no network. The only bridge message reports readiness, height, and heading offsets.
- `write_page` replaces a whole page body. A revision copies the old file to `<file>.previous.md` (one version), and the transcript gets a `write_page` entry. Undo restores `.previous.md` or removes a new page, and is offered until the person's next message.
- Sections (`##`/`###` outside code fences) are already parsed in `NotebookStore.sections(in:)` and are the unit of links and `read_page(section:)`.
- No revision log, no authorship tracking, and the person has no way to write a page.

## Decisions

### Editor: CodeMirror 6 in the reader's web view

The raw Markdown is the document; all rendering is view-only decoration, so a round trip is byte-identical by construction. Math in the editor uses the same KaTeX build and options as the reader (`markdown.js`), so the two views cannot disagree.

Rejected: ProseMirror-family WYSIWYG (Tiptap, Milkdown, Lexical) and Quarto-style visual editors. They parse and reserialize, which rewrites text the person never touched, and every manufactured change would reach Sophia as a human edit. Also rejected: native TextKit 2 (a second math renderer to keep in step, plus known regressions), side-by-side preview (halves the reading column).

### Styled source first, live preview only if it wins

Ship **styled source** first: syntax visible but dimmed, math source always shown, and a rendered KaTeX preview pinned under the display or inline formula holding the caret. It has no reflow or cursor-jump problems around math and is the cheaper build.

**Live preview** (Obsidian-style: KaTeX everywhere except at the caret) is the same editor plus replace-decorations, so it can be added later without throwing work away. Decide with the test in Phase 2.

### Scope: one section at a time

Enter editing only from an Edit affordance that appears on hovering a section heading, or ⌘E for the whole body. The opening text before the first heading gets the same affordance, with the same look and position (in the left margin, at its top-left); its edits are recorded with section "(opening)", and ⌘E's as "(page)". ⌘E leaves out a repeated `# Title` line the reader hides and splices around it, so its bytes stay identical. Double-click keeps its usual meaning (select a word), so text selection and "Ask Sophia about this" keep working. Only that section (heading to the next heading of the same or higher level) becomes an editor; the rest of the page stays rendered. A thin strip frames it: "Editing §2 · Done ⌘↩ · Revert Esc". Done (⌘Return) commits; Esc reverts to the text the editor opened with, as Esc cancels elsewhere on macOS; clicking elsewhere in the book commits. Moving to the conversation's composer leaves the section open (still closed to Sophia), with the strip visible but dimmed: "Editing §2 · open". Switching page, hiding the book, closing the window, or quitting commits; nothing ever discards an edit. The open-section marker never outlives the session: it is cleared on commit, on revert, and on launch, in case of a crash. A commit that changes nothing writes nothing: no previous version, no transcript entry, no protected line. The title in the frontmatter is not edited here (deferred).

Sections are already the unit of links and of Sophia's reads, so diffs stay small and deep links stay stable.

### Person edits are protected in the store

The Cursor lesson: a prompt asking the agent to keep manual edits is a guideline, and edits still get overwritten. So:

- A person's commit is saved by the store like any page write: the previous version is kept, a transcript entry records it, and it can be undone until the next message.
- The entry records the changed lines: `{role: "person", purpose: "edit_page", file, section, hunks: [{before, after}]}`. Hunks are whole lines, so a sign flip protects its whole line, not one character. A Markdown paragraph is usually one line, so this is coarse; narrow it to the changed words only if real use shows Sophia's own revisions refused more than about twice a week (count refusals in the transcript).
- **Protected lines** of a page are the `after` lines of its `edit_page` entries that still appear in the current page. Nothing is stored beyond the transcript; if the person later deletes the line or releases it (below), it stops being protected.
- `write_page` refuses a revision that drops or alters any protected line. The refusal names the section and returns the person's current text. Block quotes of the person's words (`<!-- quote: t-… -->`) get the same check; nothing enforces them today.
- While a section is open for editing, the app records it in a small marker the MCP process reads under the notebook lock; `write_page` refuses changes to that section until the commit. That refusal tells Sophia to answer in the conversation and not retry.

### When Sophia wants to change the person's text

A refused `write_page` is recorded in the transcript (`{role: "tool", tool: "write_page", refused: true, file, section, edit, why}`) and shown in the conversation as a release marker. Without one, "go ahead, rewrite §2" could never work. The marker shows, from data the store already has:

1. the person's own edited text, quoted from the `edit_page` hunk and marked as theirs: "Your edit in §2: 'λ₂ ≈ 0.44'";
2. Sophia's one-line reason, from an optional `why` argument on `write_page`;
3. a button named for its scope, "Let Sophia change this" (not "Unlock §2").

The button writes `{role: "person", purpose: "release_edit", entry: <edit_page id>}`, which lifts protection from that edit's hunks only; other protected lines stay protected. It can be undone until the next message. Sophia learns of the release in her next turn's context and may retry. Nothing is applied on the person's behalf, so this is not a blind unlock.

Phase 3 adds a **suggestion**: her refused revision is kept as a pending change, shown as a compact word-level diff with Accept and Reject. Accepting is an ordinary undoable Sophia revision.

Her own untouched prose keeps today's behavior: direct write, undo, "say what you changed".

### How Sophia hears about an edit

No automatic turn. The conversation shows a one-line marker ("You edited §2 of *Fiedler vector*") with Undo. Edits since her last turn are summarized in her next turn's context as the hunks. She mentions an edit only when it matters (a corrected sign that later steps depend on), and fixes dependent steps through the normal rules above. Update SOPHIA.md accordingly.

## States to handle

- **Refused commit.** Sophia changed the open section after editing began: the editor stays open with the person's text, a strip line says "Sophia revised this section while you were editing · Show her version", and Done is disabled until the person chooses Keep mine (commits against the new base) or Revert.
- **Sophia revises another section** while one is open: allowed; the open editor keeps its text and caret, and the rendered sections around it update without moving it.
- **Two undos.** The page banner's Undo (`BookView.swift`) offers the most recent write to this page, by either author, labelled "Undo your edit" or "Undo Sophia's change". The conversation marker's Undo does the same for its entry.
- **Strings** that become false: the mock's "Read-only · changes go through Sophia" and the app's "To change it, ask Sophia". Replace with the Edit affordance and nothing else.

## Phases

**Phase 1: edit a section, safely.** Done when the person can fix a typo and a sign in a math-heavy page, Sophia is told, she cannot overwrite it, and the person can let her change it.

0. **Scroll spike first.** The page is a content-sized web view inside a SwiftUI `ScrollView` (`BookView.swift`), and CodeMirror expects to own its scroller. Mount CodeMirror in that view on a long math page; arrow through a section taller than the window; have `write_page` revise the section above the open one. If the caret stays visible and the editor doesn't jump, keep this layout. If not, the reader gets its own scroller while editing.

   *Result, October 15, 2026 (`swift run sophia-reader-checks --scroll-spike`, real WebKit in a SwiftUI `ScrollView` laid out as the page, 600 pt window, 67-line math section about 4× the window's height):* on its own the layout fails. With nothing added, the caret left the screen on 98 of 121 ↓ steps, and growing the section above by 8 paragraphs moved the editor 791 pt. Two small additions in `ReaderDocument` fix both. The editor reports the caret rect and the app calls `scrollToVisible`; when content above the editor changes height, the reader reports the shift and the app scrolls by the same amount. With those, real ↓/↑ key events through the whole section, 12 typed lines at its end, and revisions above and below kept the caret on screen at every step, the editor at 0 pt movement, and the editor's text intact. CodeMirror drew all 67 lines (no virtualization surprises) and loaded lazily in about 50 ms. **Keep the content-sized layout.** Not observed: whether a single frame shows the editor displaced before the compensating scroll (the check samples after 60–400 ms), and anything involving a key window, trackpad scrolling, or VoiceOver. Check those by hand.
1. Vendor CodeMirror 6 (state, view, commands, language, lang-markdown, the lezer Markdown parser) as one prebundled script, loaded only when editing begins so chat bubbles don't pay for it. CSP stays `script-src 'self'`. Pin exact versions in `reader/assets.lock.json`; `vendor.py` verifies archives as now. The bundling step needs a pinned bundler (see open decisions).
2. Reader: source-line mapping from markdown-it token `map`s, so the caret opens at the right place; section extraction matching `NotebookStore.sections(in:)`; styled-source theme in the page's serif; KaTeX preview under the caret's formula with `throwOnError: false` and an error squiggle; ⌘Z inside the editor routed from the Edit menu.
3. Bridge: a second message, `commit {file, section, baseHash, text}`. Swift validates it and never trusts it as more than proposed text.
4. Store: `editPage(file:section:baseHash:text:session:)` splices the section under the lock, refuses on a hash mismatch for that section, writes the previous version and the `edit_page` entry. Generalize `undoPageWrite` to person edits.
5. `write_page`: protected-line and open-section checks, the refused entry, and the optional `why`. The release marker and `release_edit`. Prompts: edits and releases since the last turn.
6. DATA-MODEL.md: the `edit_page` entry and protected-line rule. SOPHIA.md: the refusal and acknowledgement behavior. app/README.md: commands and versions.

**Phase 2: decide live preview.** Take three real math-heavy pages and make the same ten edits in each mode: two typos, two sign flips, three changes inside display math, three paragraph rewrites. Count cursor surprises and time. Build live preview only if it reads clearly better and never jumps the view when an equation collapses.

**Phase 3, only after Phase 1 is in real use:**
- Suggestions (above), if releases come up often enough to annoy.
- Word-level protection, behind the refusal-rate trigger above.
- Select a passage → "Ask Sophia…", answered as a suggestion anchored to that range.
- A hairline margin mark on sections with protected lines; an Authorship toggle that tints them. Derived from the transcript; nothing added to the Markdown.
- Title editing; history beyond one previous version, if a lost version is ever missed.

## Checks

Implemented: the store checks are in `swift run sophia-checks`, the WebKit checks in `swift run sophia-reader-checks` (with the scroll spike under `--scroll-spike`). The ⌘E-with-repeated-title no-op and a titled page in the byte-identity check were added at the panel's request.

Add to `sophia-checks`:
- Splicing a section leaves every other byte of the file identical, including frontmatter, code fences, and trailing whitespace.
- A commit against a section Sophia changed since editing began is refused, and the person's text is returned, not lost.
- `write_page` that drops or rewords a protected line, or a quoted block, is refused; one that leaves them intact succeeds; once the person deletes their line it is no longer protected.
- `write_page` to a section marked open is refused; other sections succeed.
- Undo of a person edit restores the previous version and records an undo entry.
- A commit with no change writes nothing.
- A release lifts only that edit's lines; a retried `write_page` then succeeds; undoing the release protects them again.

Add to `sophia-reader-checks` (needs a desktop session):
- Opening and committing an editor with no keystrokes returns the exact input bytes, for the math fixture and a page with CRLF, tabs, and unusual list markers.
- The editor loads with no network request, under the existing CSP.
- Invalid TeX keeps typing possible and shows the source.

By hand, in the app: VoiceOver in the editor, Edit ▸ Undo routing, Esc reverting, double-click still selecting a word, scroll position on enter and exit, whether a frame shows the editor displaced before the compensating scroll, trackpad scrolling while editing, the dimmed strip while the composer has focus, and the Edit buttons appearing on hover.

## Open decisions

- **Bundler.** *Decided:* `vendor.py` downloads the locked esbuild 0.28.2 binary for the Mac's architecture, checks its integrity and reported version, and bundles `reader/editor-entry.js` into `vendor/codemirror.min.js` (one IIFE exposing `window.CM`, about 307 KB minified; the output is checked in and identical across runs). Building the app still needs no Node.
- **Whether the person's edits count as evidence for goals.** Default: no. An edit is a contribution to the book, not an attempt; Sophia may note one through the normal note rules if it shows understanding.
