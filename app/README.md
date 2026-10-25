# Sophia (Mac app)

A native SwiftUI app. Sophia runs on the person's own Claude Code installation: the app launches the unmodified `claude` binary in headless mode with SOPHIA.md as its instructions, a restricted tool set (web search, source opening with explicit permission, and Sophia's scoped notebook tools), and the person's own Claude sign-in. Notebook files follow [DATA-MODEL.md](../DATA-MODEL.md). The approach was tested first in [spikes/claude-headless](../spikes/claude-headless/README.md).

## Requirements

- macOS 14 or later, and the Xcode Command Line Tools (Swift 6.2). Full Xcode is not required to build.
- Claude Code installed and signed in: run `claude` once in Terminal. The app looks for the official binary at `~/.local/bin/claude` (or `SOPHIA_CLAUDE`), not a wrapper on PATH. Before each ordinary or internal request, the app runs a bounded local auth-status check in the notebook’s effective process context and permits only claude.ai / firstParty with no API-key source. Unverified, signed-out, alternate-provider and failed checks withhold the request before inference starts; runtime API-source checking remains in place. This is point-in-time route evidence, not independent billing proof or commercial permission.

## Build and run

```sh
scripts/make-app.sh            # builds build/Sophia.app (release; pass "debug" for a debug build)
open build/Sophia.app
```

Notebooks live in `~/Documents/Sophia/<name>/`. Set `SOPHIA_LIBRARY=/some/dir` to use another folder (useful for disposable notebooks when testing; launch the binary inside the bundle directly so the variable is passed).

## Checks

```sh
swift run sophia-checks                 # record checks, page writes and undo, two writers, goals, crash recovery, deletion
swift run sophia-reader-checks          # actual WebKit reader, offline fonts, math, music, isolation, and resizing
swift run sophia-reader-checks --scroll-spike  # the page editor in the page's scroll view: caret visibility, revisions around it
node reader/check.mjs                   # parser-only checks; optional Node, no npm install
swift run sophia-checks --live <dir>    # end-to-end against real Claude Code in a disposable notebook
swift run sophia-checks --probes <dir>  # teaching probes (plain question, pushback, "I don't remember", declined exercise, …); prints replies to read
swift run sophia-checks --music <dir>   # Sophia writes a tune page with tab, then fixes a tune the app reports warnings for (two turns)
```

Swift's test frameworks ship with full Xcode, so the checks are a small executable instead. The live run uses your Claude Code login (about four short turns).

`swift run sophia-checks --attribution <empty-dir>` runs a focused, nonhuman attribution regression. It labels a seeded prior exchange/page from the October 24 simulation, sends the actual phase-wording challenge to Claude, then explicitly asks to retain accurate notes. The probe fails if the known erroneous fixture opening was not revised; read the repaired passage and actual notes manually. Read the printed reply, page, notes and memory together: a valid correction of Sophia must stay separate from the person’s earlier fixed-length misconception. A later direct-store correction checks fresh model context and briefing influence; it does not stand in for native Notes UI verification. The probe uses the same Claude Code login and refuses a nonempty test notebook.

The reader checks need a normal macOS desktop session where WebKit can launch its rendering process; they start no Claude session and use synthetic text. Set `SOPHIA_READER_SNAPSHOT=/tmp/math.png` to capture the math fixture. The Node checks exercise the same bundled parser and TeX configuration, but do not verify sanitization, native sizing, selection, or accessibility.

To look at the interface without clicking through it, render the window to PNGs (contents, goals, notes, first page). This starts no conversation process and doesn't take keyboard focus:

```sh
SOPHIA_SNAPSHOT=/tmp/shots SOPHIA_LIBRARY=<library with one notebook> \
  SOPHIA_SNAPSHOT_SIZE=1440x900 SOPHIA_SNAPSHOT_APPEARANCE=dark build/Sophia.app/Contents/MacOS/Sophia
```

Add `SOPHIA_SNAPSHOT_SECTION="<section title>"` to render the first page scrolled to that section, as following a deep link does, or `SOPHIA_SNAPSHOT_EDIT="<section title>"` (or `(opening)`, `(page)`) to render it with that section open in the editor.

### Native UX simulations

The opt-in debug harness drives the same native window, accessibility actions, text editors, menus, and scroll views as the app. It never calls `NotebookSession`, stores, or the engine directly. Build a debug bundle first; from the repository root:

```sh
app/scripts/make-app.sh debug
python3 app/scripts/ux.py app/build/ux-sim/example launch
python3 app/scripts/ux.py app/build/ux-sim/example inspect
python3 app/scripts/ux.py app/build/ux-sim/example press --id 41
```

Use IDs from the latest response, not the example above. Every command preserves its UI tree and window PNG under the run's `results/`. `set --id N --text '…'` replaces native field text through its editor; `type --text '…'` inserts at the focused editor's caret. `key --code 53` sends Escape, `key --code 36 --modifiers command` commits an open page editor, and `menu` lists the actual menu commands. Other key codes need `--text` with the actual character (for example `--code 12 --modifiers command --text q` for Quit). `scroll --id N --dy 500` operates an `AXScrollArea` (negative goes up). `click --x X --y Y` and `hover` use coordinates from the top left of the window screenshot; coordinates are window points; on a Retina capture, divide PNG pixel coordinates by its display scale. `resize --width 1440 --height 850` changes the window size.

Each run uses its own disposable `library/`; the debug bridge starts only when both `SOPHIA_UX_HARNESS` and a nested `SOPHIA_LIBRARY` are explicitly set. Release builds omit it, and the driver refuses to launch a release bundle. Launch clears stale queued actions and refuses a second app for the same run directory. It needs no cross-app Accessibility permission. Screenshots cover only Sophia's own window or attached sheet; rendered reader content may require visual inspection rather than accessibility text. Commands are not topic answers, and the harness supplies no simulated model responses. Sending through the composer uses the installed Claude connection and normal provider usage. It never copies authentication files or introduces an API fallback.

The normal return threshold is six hours. After closing an idle run with `key --code 12 --modifiers command --text q` (⌘Q), relaunch the same directory with `launch --return-gap 60` to exercise an explicitly accelerated return after a one-minute pause. This tests the UI path, not delayed retention. Preserve notebook data and distinguish harness interruptions from product failures. The October 24 four-persona study and its Linear findings are recorded in `../research/2026-10-24-ux-simulation/`.

For a first-time setup walkthrough, `launch --without-claude` injects unavailable executable discovery in the debug process and exercises the app's real missing-install error. It does not remove the person's installation or change their login. Relaunching without that flag supplies the machine's existing connection; it does not prove a fresh installation, account creation, sign-in, or billing attribution. Native Help/menu tracking is not supported by this driver; use `menu` to inspect menu commands. The study includes a fourth, onboarding-focused learner.

## Layout

- `Sources/SophiaCore`: notebook files (`NotebookStore`), the client checks on everything Sophia writes (`RecordChecks`), the Claude Code process (`ClaudeEngine`), and the text the app adds to Sophia's instructions (`Prompts`).
- `Sources/Sophia`: the app. `NotebookSession` queues work for the open notebook and keeps conversation processes by page in memory; the views are the sidebar, the book, and the conversation.
- `Sources/SophiaReader`: the shared, read-only Markdown and LaTeX reader in WebKit, with its local scripts, styles, and fonts.
- `Sources/sophia-mcp`: `read_page`, `write_page`, `set_chapter`, `set_goal`, `note`, `set_memory`, `recall`, `about_you`, and `link`, served to Claude Code over stdio. They write through `NotebookStore`, under a lock on the notebook, so the app and the tools never overwrite each other; the app rereads the files when a tool finishes.

## What this version does

An unanswered question stays in its conversation with **Retry** and a link to the official Claude Code setup guide. Retry rechecks the existing connection and sends the saved question without creating another person entry; a partial reply is labeled interrupted. This local recovery path is checked with debug missing-install injection and an existing signed-in installation. Fresh installation/sign-in on a clean Mac remains separate validation.

- Talk with Sophia beside Contents or a page; each has its own conversation. Goals and Notes keep the conversation you were in. Web search is available. Replies and queued messages stay in their originating conversation.
- Sophia writes and revises pages directly; a write preserves the selection, composer focus, and the person’s choice to hide the book. Open on its conversation card takes you to the page and opens the book. She can group pages into chapters ("Chapter 0: Foundations"); section numbers in titles ("0.1") are set apart in the page header, contents, and sidebar. The latest write, edit or permission release on each page can be undone once, across messages and relaunch, until another action changes that page. A revision keeps the previous version. A write that already matches is labelled unchanged, ends any earlier Undo on that page, and creates no Undo.
- An unrecorded page change found on reopening has unknown authorship, and no Undo. Its current text is kept; when a previous version exists, Previous version opens a read-only source view with copy-into-editor guidance. This handles possible interrupted writes without deleting outside edits or outside-added pages. It is not automatic restoration of a crash-before-entry.
- Selecting another page, including returning to one read earlier, starts at its title. An explicit section link lands at that section. A revision or edit to the same open page retains its reader identity and scroll behavior; positions are not stored per page.
- Conversation replies follow while you are at the end. Scrolling up keeps that reading position as current-thread text and tools arrive; New activity explicitly jumps to the latest material. Sending a question or selecting a different conversation intentionally goes to its end. Reflow and unrelated-thread activity do not create unread material. This is local view state, not stored reading history. A streamed text block keeps its Markdown reader when the transcript records it, preserving the visible content through completion.
- Adjacent successful note and memory updates in the same person turn, thread and session share a compact disclosure. Expand it for the original details and Notes actions; deleted notes remain labeled unavailable. Updates are never grouped across assistant prose, page writes, source outcomes, goals, refusals, Undo or checkpoint boundaries. This changes bookkeeping presentation, not reply content or model latency.
- You can edit a page yourself ([EDITING.md](../EDITING.md)): hover a section heading (or the opening text) and click ✎ in the margin, or press ⌘E for the whole page. The section becomes its Markdown source, with math source shown and the formula at the caret previewed beneath it. Done (⌘↩) or a click elsewhere in the book saves; Esc reverts. Only the lines you changed are written, the previous version is kept, and Undo follows the same rule as a page write. Sophia is told about your edit with your next message, and can't overwrite your lines: a revision that would is refused and shown in the conversation, where "Let Sophia change this" lets her try again.
- Sophia records goals she hears in the conversation. Review opens the complete title, criteria, quotation and revision context before you confirm. You can leave a proposal provisional or reject a new goal with "Not my goal" (with Undo). A revised goal can be dropped as a whole without changing its criteria or evidence; "Keep the earlier version" is available only when its criteria match exactly, because deleting/reusing criterion positions could relabel saved or undoable evidence. Individual criterion removal is not supported.
- Notes during the conversation: Sophia keeps a few notes as you talk (things to follow up, what she's learned about how you relate to the topic, attempts, open questions). Each shows as one line in the conversation, at most 8 new ones a session, and she can close or revise her own. Based on links in Notes, memory and welcome-back briefings reveal the actual exchange, goal criterion, note or current local page. One item expands at a time per group; exact words, Sophia’s interpretation and your correction stay distinct. Missing/deleted items remain visibly unavailable, with the identifier available for inspection.
- Memory: Sophia keeps a short working memory per notebook ("What Sophia is keeping in mind", at the top of Sophia's notes), each line citing the notes behind it, and looks up her long-term notes with `recall` when a topic comes back. You can correct or forget any line.
- About you: background and standing preferences shared by every notebook. Sophia proposes lines from your words; a line stays in its notebook until you confirm it.
- Links between notebooks: Sophia sees only other notebooks' chapter, page, and section titles, proposes links (to a page or straight to a section) with a reason, and reads a linked page only after you confirm the link. "Keep this notebook separate" (in the notebook's contents) takes a notebook out of all of this.
- Notes on your attempts: when you come back after at least 6 hours, Sophia first writes notes on whatever you said last time; Finish for now does it sooner. Notes are kept only if they rest on something you said or did, and quotes must match your words exactly. This processing stays quiet; an invalid reply saves nothing.
- Coming back: a briefing of at most two sentences, with the one thread worth picking up and one offer. You can type straight away; your message waits for the notes. Reopening sooner (a relaunch) shows nothing. If the window was left open for hours, Sophia is told how long it has been instead. Set `SOPHIA_RETURN_GAP=<seconds>` to try this without waiting.
- Goals, with criteria, which you can also add, reword, mark met, or drop; Sophia's notes and working memory, whose saved person corrections remain editable and prefilled; "Show record" on any note or goal. Learning IDs are reserved in notebook metadata before append and never recycled by deletion. Undo refuses identity collisions without discarding the pending deleted records. Failed correction saves retain the editor and typed draft.
- Markdown pages, replies, and Sophia's notes with LaTeX mathematics: inline formulas, display equations, fractions, matrices, and aligned derivations. Literal code stays code. Earlier Unicode notation remains readable.
- Music on pages ([MUSIC.md](../MUSIC.md)): ABC notation in an `abc` fence is typeset as staff notation, optionally with a fret-number tab line. Notation warnings show, collapsed, under the tune, and Sophia is told about them with your next message. No playback.

WebSearch discovers candidate links and summaries. In ordinary native conversations, Sophia can request built-in WebFetch: the URL appears with **Allow once** and **Don't open**. There is no remembered approval. Stop, process exit or a notebook switch retires access; switching conversations denies pending access, and returning permits a fresh request. Internal checkpoint/briefing requests cannot fetch. CLI checks/probes retain WebSearch-only behavior unless supplied a native approval bridge.

A returned extraction appears as selectable text under **Provider-extracted source**, with the requested URL, actual returned URL/status when present, and a collapsible content block. It is the provider's potentially lossy extraction, not raw full text or an independently verified quotation. Source errors and refusals remain visible. Sophia can also discuss person-pasted passages and notebook pages. A successful search, approval or advertised capability alone is not proof of actual source access.

Not yet: guided reading, distribution signing.

## Markdown and mathematics

Notebook files keep the original Markdown and LaTeX source. Use `$...$` inline and `$$` on separate lines for display math (the reader also accepts `\(...\)` and `\[...\]`):

```markdown
The Rayleigh quotient of $L$ is

$$
R(x) = \frac{x^\top Lx}{x^\top x}.
$$
```

Use `\$` for literal currency dollars. Equations in code fences remain literal. Unsupported or incomplete math remains visible rather than preventing the rest of a reply from rendering. This is LaTeX math notation, not a full TeX document compiler. Page titles, goal titles, and criteria stay plain text; the person's own messages and quoted attempts remain literal text.

Music is ABC notation in an `abc` fence. An optional first line of JSON, then `---`, sets `tablature` (`instrument`: guitar, violin, fiddle, mandolin, or fiveString; `tuning`; `capo`), `scale`, and `staffwidth`; anything else is ignored:

````markdown
```abc
{"tablature": {"instrument": "guitar", "capo": 2}}
---
X:1
T:A scale
K:C
C D E F | G A B c |
```
````

The music scales to the text column and takes the text color. Warnings from abcjs are listed, collapsed, under the tune; if it can't be typeset at all, its source shows instead. A tune copies as its ABC fence.

The reader bundles markdown-it **15.0.2**, markdown-it-texmath **1.0.0**, KaTeX **0.19.0**, and DOMPurify **3.4.17** with local WOFF2 fonts and upstream licenses. The page editor ([EDITING.md](../EDITING.md)) adds CodeMirror, loaded only when editing begins: @codemirror/state **6.7.6**, view **6.43.14**, commands **6.11.1**, language **6.13.1**, lang-markdown **6.5.2**, and @lezer/markdown **1.8.0**, with their dependencies, prebundled into `vendor/codemirror.min.js` by esbuild **0.28.2** from `reader/editor-entry.js`. Music adds abcjs **6.7.1** (MIT), loaded only for a page with an `abc` fence: npm publishes no build without audio (its "basic" build includes the synth, which can fetch soundfonts), so the same esbuild bundles just its renderer from the package's sources (`reader/music-entry.js`) into `vendor/abcjs.min.js` (454 KB; the published `abcjs-basic-min.js` is 512 KB), with no audio or network code. The exact tarballs (including the transitive packages and the esbuild binaries for Apple silicon and Intel) and SHA-512 integrity values are in [reader/assets.lock.json](reader/assets.lock.json). No Node installation, network request, or CDN is needed to build or use the app. To refresh the checked-in browser assets, run `python3 -I reader/vendor.py`; it verifies each locked archive before copying or bundling, and checks that esbuild reports its locked version. The asset script was run with Python 3.15; the parser checks with Node 26.0.0. No provider adapter, SDK, or launched engine versions changed for this work.

Raw HTML is displayed as text, generated HTML is sanitized, and KaTeX's trusted commands are disabled. A restrictive content security policy blocks network resources and inline scripts. Images keep their descriptions without fetching them. Source links open in the default browser only when clicked. The only WebKit message handler reports readiness, content height, a page's notation warnings, and, while editing, the editor's caret, draft, and commit; the app checks every commit against the range it opened before saving. Visual math includes MathML and the original TeX for accessibility and copying; VoiceOver behavior still needs a desktop check.

Validation in the development agent (October 15, 2026): the app builds; all core checks, the parser checks, and the WebKit reader and editor checks pass, including the scroll spike, in a desktop session. Music (same day): the parser, reader, and core checks for `abc` fences pass; reading tunes by eye in the app, VoiceOver on a tune, and a live turn with warnings are still to do. Focus, trackpad scrolling, hover, and VoiceOver in the app still need checking by hand (see EDITING.md).

### Copy, back up and restore

Use the ellipsis **Notebook actions** menu beside a notebook’s title in the Library sidebar and choose **Show Notebook in Finder** or **Copy & Restore…**. The same actions are available by right-clicking the notebook title. Let any reply finish, finish page edits, save any text you need from unsent composer drafts, then quit Sophia before copying. Copy the entire notebook folder, including hidden files; selecting only Markdown pages does not preserve the inquiry.

The notebook folder contains `notebook.json` (ordering, chapters and identity high watermarks), `pages/` (current and single previous versions), `transcript.jsonl`, and `learning.jsonl` (goals, notes, corrections, memory and evidence references). Those relative identities survive a whole-folder copy. Provider credentials/authentication caches are not stored there. Unsent composer drafts and pending in-memory Undo for deleted learning records do not survive quitting; a backup is a snapshot, not an unlimited history or a substitute for those unsaved states.

To restore, quit Sophia and put the complete notebook folder in the Library (normally `~/Documents/Sophia`; Show Library in Finder identifies this app’s actual location). Use an empty destination and the original notebook folder name. Do not merge, overwrite, or replace an existing notebook to test a backup: preserve it elsewhere first, or use a fresh Library. Launch Sophia and select the restored notebook. Opening may index previously unrecorded disk changes as unknown provenance; it does not create destructive Undo for them. As with any notebook opened after a break, an acknowledged Sophia may start its usual return request and add records to the restored copy; keep the original backup outside the Library.

A single notebook does **not** contain the Library’s shared About you or confirmed links. To move the whole Library, copy its entire folder while Sophia is quit, including hidden `.sophia/about.jsonl` and `.sophia/links.jsonl`, and retain all linked notebooks under their original names. Copying the enclosing Library folder includes hidden `.sophia` too. Restore that whole Library to an empty Library location while Sophia is quit. Claude Code installation/login is separate and is not backed up by these folders.

Copying a notebook or putting it in a cloud folder does **not** provide supported concurrent sync. Do not use the same Library from multiple running Sophia instances. Cross-Mac/cloud conflict resolution, automatic backups and importing/merging notebooks are outside this path. Development checks use disposable libraries only: `swift run sophia-checks` includes whole-notebook byte/evidence/Undo/watermark continuation and whole-Library shared About you/link roundtrips.

### Local Claude readiness and first-use information

Connection & Data (toolbar or application menu) explains local notebook storage, relevant context sent for questions/Finish for now/later returns, web research, and separate Claude usage. The first-use card is dismissible; reading and drafting remain available. Before acknowledgement, opening an older notebook suppresses that opening’s automatic return request. Dismissal records acknowledgement only and never starts the suppressed request. An explicit Send and later informed return keep the existing connection path.

Recheck runs only the selected installed Claude Code’s `--restricted --setting-sources '' auth status --json`, asynchronously in a fresh empty directory, with the engine’s provider/API environment exclusions. It has a five-second deadline and 64KiB output limit, discards stderr and raw output, and retains only constant missing/unchecked/signed-out/unknown/ready-to-attempt labels. Ready requires `loggedIn: true`, `authMethod: claude.ai`, `apiProvider: firstParty`, and no alternate API-key source. This is installation/login status, not a live request, notebook-specific effective-route enforcement, billing proof or commercial permission. No login, credential/cache reads, settings changes, fallback, or model preflight is performed. Each outbound request separately checks the intended route in the engine’s actual notebook context before sending content; clean-Mac and human comprehension/commercial checks remain open.

Debug UX runs isolate the acknowledgement preference by harness directory. `SOPHIA_UX_CONNECTION_STATUS=missing|unknown|signed-out` injects a visibly labeled synthetic status only when a debug harness is active; normal/release runs ignore it. The existing `--without-claude` launch fault still exercises actual saved-question Retry behavior.

Cancellation and shutdown controls are recorded in [SOP7 lifecycle checks](checks/sop7-process-lifecycle.md). Quit keeps AppKit alive for bounded cleanup of exact owned Claude/status descendants; a question interrupted by shutdown remains available for explicit Retry, while intentional Stop keeps its existing meaning. New engines reconstruct saved local context rather than resuming provider state.

If an edited page range disappears before it can be saved, its unsaved text is kept separately from connection errors. Review kept edits offers selectable read-only text, Copy and individual Dismiss; Close only hides the sheet. Repeated failures and Send/Retry do not replace earlier kept edits. This recovery exists only while that notebook stays open: copy before closing or switching notebooks. See [SOP51 recovery checks](checks/sop51-page-edit-recovery.md).
