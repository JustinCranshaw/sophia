# Sophia (Mac app)

A native SwiftUI app. Sophia runs on the person's own Claude Code installation: the app launches the unmodified `claude` binary in headless mode with SOPHIA.md as its instructions, a restricted tool set (web search, source opening with explicit permission, and Sophia's scoped notebook tools), and the person's own Claude sign-in. Notebook files follow [DATA-MODEL.md](../DATA-MODEL.md). The approach was tested first in [spikes/claude-headless](../spikes/claude-headless/README.md).

## Requirements

- macOS 14 or later, and the Xcode Command Line Tools (Swift 6.2). Full Xcode is not required to build.
- Claude Code installed and signed in: run `claude` once in Terminal. The app looks for the official binary at `~/.local/bin/claude` (or `SOPHIA_CLAUDE`), not a wrapper on PATH. Before each ordinary or internal request, the app runs a bounded local auth-status check in the notebook’s effective process context and permits only claude.ai / firstParty with no API-key source. Unverified, signed-out, alternate-provider and failed checks withhold the request before inference starts; runtime API-source checking remains in place. This is point-in-time route evidence, not independent billing proof or commercial permission.

## Build and run

Run the following commands from `app/` (or pass `--package-path app` to Swift commands from the repository root).

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
python3 checks/root-page-tools.py       # persistent local MCP root revision/filing checks; build sophia-mcp first
swift build --product sophia-mcp        # required adjacent tool server for the live commands below
swift run sophia-checks --live <dir>    # end-to-end against real Claude Code in a disposable notebook
swift run sophia-checks --probes <dir>  # teaching probes (plain question, pushback, "I don't remember", declined exercise, …); prints replies to read
swift run sophia-checks --music <dir>   # Sophia writes a tune page with tab, then fixes a tune the app reports warnings for (two turns)
```

Swift's test frameworks ship with full Xcode, so the checks are a small executable instead. The live helpers are source-adapted for canonical Markdown pages and whole-page proposals; these broad live scenarios have not been rerun for this migration. Offline Core passes and the focused native flow do not establish their companion-quality outcomes. The live run uses your Claude Code login and provider usage: three initial turns, a checkpoint and briefing, two recall/link questions, an in-place revision and a page-origin write turn: nine scripted turns on the normal successful path, with a tenth if a proposed cross-notebook link can be confirmed and read. Each turn can involve several underlying model calls and tool exchanges, so this is not a model-call or usage estimate. These are live provider requests, not offline checks; use a fresh disposable directory. CLI probes have no native source-approval bridge and remain WebSearch-only.

`swift run sophia-checks --attribution <empty-dir>` runs a focused, nonhuman attribution regression. It labels a seeded prior exchange/page from the October 24 simulation, sends the actual phase-wording challenge to Claude, then explicitly asks to retain accurate notes. The probe fails if the known erroneous fixture opening was not revised; read the repaired passage and actual notes manually. Read the printed reply, page, notes and memory together: a valid correction of Sophia must stay separate from the person’s earlier fixed-length misconception. A later direct page-editor correction checks fresh model context and briefing influence; it does not stand in for native Notes UI verification. The probe uses the same Claude Code login and refuses a nonempty test notebook.

The reader checks need a normal macOS desktop session where WebKit can launch its rendering process; they start no Claude session and use synthetic text. Set `SOPHIA_READER_SNAPSHOT=/tmp/math.png` to capture the math fixture. The Node checks exercise the same bundled parser and TeX configuration, but do not verify sanitization, native sizing, selection, or accessibility.

To look at the interface without clicking through it, render the window to PNGs (contents, goals, notes, first page). This starts no conversation process and doesn't take keyboard focus:

```sh
SOPHIA_SNAPSHOT=/tmp/shots SOPHIA_LIBRARY=<library with one notebook> \
  SOPHIA_SNAPSHOT_SIZE=1440x900 SOPHIA_SNAPSHOT_APPEARANCE=dark build/Sophia.app/Contents/MacOS/Sophia
```

Add `SOPHIA_SNAPSHOT_SECTION="<section title>"` to render the first page scrolled to that section, as following a deep link does, or `SOPHIA_SNAPSHOT_EDIT="<section title>"` (or `(opening)`, `(page)`) to render it with that section open in the editor.

### Native UX simulations

With the debug harness, `checkpoint-<UUID>.json` records the internal response, coverage target, provider failure flag and persistence outcome for disposable return/Finish diagnostics. `notebook-tool-<UUID>.json` records attempted notebook-tool input separately from the store’s actual write/proposal outcome. Ordinary launches write no such files; use non-sensitive fixture material.

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

## Working visual identity

The app uses the selected DC Trued Channel mark in solid Plum (`#6E2F55` light, `#E3A9C8` dark), with a compact Palatino wordmark and tighter inline spacing. Reading and interface typography remain native; semantic errors, source decisions and recovery controls keep their existing treatments. The local bundle includes a generated icon; no installation or distribution step is implied. See [brand decisions](../docs/brand-decisions.md), [identity verification](checks/sop68-native-brand.md) and [surface verification](checks/sop69-native-surfaces.md). Selective Plum labels name Sophia; person quotes/corrections and neutral statuses use ink, while links and semantic error/proposal treatments stay native. Almanac preparation actions are small bordered controls.

The mark is a generated static path, not a runtime SVG parser. Check its locked-source parity from `app/` with `python3 scripts/gen-brand-mark.py --check`; regenerate deliberately by omitting `--check`. Normal app packaging copies the checked-in `Resources/Sophia.icns` and sets `CFBundleIconFile`. The optional icon generator is documented in the verification note; it is not a normal build dependency.

## What this version does

An unanswered question stays in its conversation with **Retry** and a link to the official Claude Code setup guide. Retry rechecks the existing connection and sends the saved question without creating another person entry; a partial reply is labeled interrupted. This local recovery path is checked with debug missing-install injection and an existing signed-in installation. Fresh installation/sign-in on a clean Mac remains separate validation.

- Talk with Sophia beside Contents or a page; each has its own conversation. Chapter introductions, Goals, Sophia’s notes and Working memory each use the selected page’s own file conversation. Web search is available. Replies and queued messages stay in their originating conversation.
- Sophia writes and revises pages directly; a write preserves the selection and composer focus. Open on the conversation card takes you to the page. Sophia can group pages into chapters ("Chapter 0: Foundations"); section numbers in titles ("0.1") are set apart in the page header, contents, and sidebar. The latest write, edit or permission release on each page can be undone once, across messages and relaunch, until another action changes that page. A revision keeps the previous version. A write that already matches is labelled unchanged, ends any earlier Undo on that page, and creates no Undo.
- An unrecorded page change found on reopening has unknown authorship, and no Undo. Its current text is kept; when a previous version exists, Previous version opens a read-only source view with copy-into-editor guidance. This handles possible interrupted writes without deleting outside edits or outside-added pages. It is not automatic restoration of a crash-before-entry.
- Selecting another page, including returning to one read earlier, starts at its title. An explicit section link lands at that section. Cited-page evidence offers Open page and numbered Open section choices, including distinct duplicate headings. Choices are checked against the current page; changed/deleted targets are reported instead of guessed. Legacy title links require one matching visible section. The page header’s Sections menu uses the same checked choices without leaving the page. Finish source editing before choosing a section; a blocked request is not deferred. Navigation does not revise a page. A revision or edit to the same open page retains its reader identity and scroll behavior; positions are not stored per page.
- Conversation replies follow while you are at the end. Scrolling up keeps that reading position as current-thread text and tools arrive; New activity explicitly jumps to the latest material. Sending a question or selecting a different conversation intentionally goes to its end. Reflow and unrelated-thread activity do not create unread material. This is local view state, not stored reading history. A streamed text block keeps its Markdown reader when the transcript records it, preserving the visible content through completion.
- Historical note/memory update groups remain readable in conversation, with their original source records. New Notes and Working memory saves use the ordinary page-write card, Open and durable Undo; audit candidates alone are not shown as a successful save.
- You can edit a page yourself ([EDITING.md](../EDITING.md)): hover a section heading (or the opening text) and click ✎ in the margin, or press ⌘E for the whole page. The section becomes its Markdown source, with math source shown and the formula at the caret previewed beneath it. Done (⌘↩) or a click elsewhere in the book saves; Esc reverts. Only the lines you changed are written, the previous version is kept, and Undo follows the same rule as a page write. Sophia is told about your edit with your next message, and can't overwrite your lines: a revision that would is refused and shown in the conversation, where "Let Sophia change this" lets Sophia try again.
- Sophia proposes a complete Goals Markdown replacement supported by your words. Review shows formatted current/proposed pages, optional exact source, evidence, and whole-page line counts. Accept is person-owned, checks the entire file hash, and uses the ordinary person edit and Undo. Any intervening edit makes the proposal stale. There are no criterion/status cards or separate goal editor.
- Sophia’s notes is an ordinary notebook page. The `note` tool supplies a complete evidence-checked Markdown body, with at most eight changed live updates per session. Your actual words, tentative interpretations and evidence remain distinguishable. Historical record/criterion links still resolve as audit evidence; they do not describe later prose edits.
- Working memory is an ordinary notebook page, using the same reader, source editor, protection and Undo. `set_memory` supplies the complete evidence-checked body; direct person edits reach fresh/ongoing/return context. Historical memory records are retained as evidence, not a second current version.
- About you: a shared Markdown page using the ordinary reader, source editor and Undo, with its own stable conversation. Sophia proposes complete changes supported by your exact words; a pending change stays within its originating notebook (or the separate About conversation) until you review and accept it. The full current/proposed pages, source and evidence remain inspectable.
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

The reader bundles markdown-it **15.0.2**, markdown-it-texmath **1.0.0**, KaTeX **0.19.0**, and DOMPurify **3.4.17** with local WOFF2 fonts and upstream licenses. The page editor ([EDITING.md](../EDITING.md)) adds CodeMirror, loaded only when editing begins: @codemirror/state **6.7.6**, view **6.43.14**, commands **6.11.1**, language **6.13.1**, lang-markdown **6.5.2**, and @lezer/markdown **1.8.0**, with their dependencies, prebundled into `vendor/codemirror.min.js` by esbuild **0.28.2** from `reader/editor-entry.js`. Music adds abcjs **6.7.1** (MIT), loaded only for a page with an `abc` fence: npm publishes no build without audio (its "basic" build includes the synth, which can fetch soundfonts), so the same esbuild bundles just its renderer from the package's sources (`reader/music-entry.js`) into `vendor/abcjs.min.js` (454 KB; the published `abcjs-basic-min.js` is 512 KB), with no audio or network code. The exact tarballs (including the transitive packages and the esbuild binaries for Apple silicon and Intel) and SHA-512 integrity values are in [reader/assets.lock.json](reader/assets.lock.json). No Node installation, network request, or CDN is needed to build or use the app. To refresh the checked-in browser assets, run `python3 -I reader/vendor.py`; it verifies each locked archive before copying or bundling, and checks that esbuild reports its locked version. The asset script was run with Python 3.15; the parser checks with Node 26.0.0. Those are reader build-tool observations, not the launched engine version. The current app has no provider adapter or SDK dependency. The original headless spike used CLI 2.1.299; the October 25 [package/Core/MCP probe](../research/2026-10-25-packaged-release/README.md) actually launched official CLI 2.1.304 and observed claude-fable-5-1. Do not infer another run's model/version from those records.

Raw HTML is displayed as text, generated HTML is sanitized, and KaTeX's trusted commands are disabled. A restrictive content security policy blocks network resources and inline scripts. Images keep their descriptions without fetching them. Source links open in the default browser only when clicked. The only WebKit message handler reports readiness, content height, a page's notation warnings, and, while editing, the editor's caret, draft, and commit; the app checks every commit against the range it opened before saving. Visual math includes MathML and the original TeX for accessibility and copying; VoiceOver behavior still needs a desktop check.

Historical validation recorded by the development agent (October 15, 2026): the app builds; all core checks, the parser checks, and the WebKit reader and editor checks pass, including the scroll spike, in a desktop session. Music (same day): the parser, reader, and core checks for `abc` fences pass; reading tunes by eye in the app, VoiceOver on a tune, and a live turn with warnings are still to do. Later issue-specific native reports cover selected math/music, editing and scroll cases; they do not establish VoiceOver, physical trackpad behavior or universal focus/selection correctness (see EDITING.md).

### Copy, back up and restore

Use the ellipsis **Notebook actions** menu beside a notebook’s title in the Library sidebar and choose **Show Notebook in Finder** or **Copy & Restore…**. The same actions are available by right-clicking the notebook title. Let any reply finish, finish page edits, save any text you need from unsent composer drafts, then quit Sophia before copying. Copy the entire notebook folder, including hidden files; selecting only Markdown pages does not preserve the inquiry.

The notebook folder contains `notebook.json` (ordering, chapters and identity high watermarks), `pages/` (current and single previous versions), `transcript.jsonl`, and `learning.jsonl` (goals, notes, corrections, memory and evidence references). Those relative identities survive a whole-folder copy. Provider credentials/authentication caches are not stored there. Unsent composer drafts and pending in-memory Undo for deleted learning records do not survive quitting; a backup is a snapshot, not an unlimited history or a substitute for those unsaved states.

To restore, quit Sophia and put the complete notebook folder in the Library (normally `~/Documents/Sophia`; Show Library in Finder identifies this app’s actual location). Use an empty destination and the original notebook folder name. Do not merge, overwrite, or replace an existing notebook to test a backup: preserve it elsewhere first, or use a fresh Library. Launch Sophia and select the restored notebook. Opening may index previously unrecorded disk changes as unknown provenance; it does not create destructive Undo for them. As with any notebook opened after a break, an acknowledged Sophia may start its usual return request and add records to the restored copy; keep the original backup outside the Library.

A single notebook does **not** contain the Library’s shared About you or confirmed links. To move the whole Library, copy its entire folder while Sophia is quit, including hidden `.sophia/about/` (the canonical page, conversation, proposals and history), historical `.sophia/about.jsonl`, and `.sophia/links.jsonl`, and retain all linked notebooks under their original names. Copying the enclosing Library folder includes hidden `.sophia` too. Restore that whole Library to an empty Library location while Sophia is quit. Claude Code installation/login is separate and is not backed up by these folders.

Copying a notebook or putting it in a cloud folder does **not** provide supported concurrent sync. Do not use the same Library from multiple running Sophia instances. Cross-Mac/cloud conflict resolution, automatic backups and importing/merging notebooks are outside this path. Development checks use disposable libraries only: `swift run sophia-checks` includes whole-notebook byte/evidence/Undo/watermark continuation and historical shared About you/link record roundtrips; focused About checks separately cover canonical migration, proposals, protection and exact-byte Undo.

### Local Claude readiness and first-use information

Connection & Data (toolbar or application menu) explains local notebook storage, relevant context sent for questions/Finish for now/later returns, web research, and separate Claude usage. The first-use card is dismissible; reading and drafting remain available. Before acknowledgement, opening an older notebook suppresses that opening’s automatic return request. Dismissal records acknowledgement only and never starts the suppressed request. An explicit Send and later informed return keep the existing connection path.

Recheck runs only the selected installed Claude Code’s `--restricted --setting-sources '' auth status --json`, asynchronously in a fresh empty directory, with the engine’s provider/API environment exclusions. It has a five-second deadline and 64KiB output limit, discards stderr and raw output, and retains only constant missing/unchecked/signed-out/unknown/ready-to-attempt labels. Ready requires `loggedIn: true`, `authMethod: claude.ai`, `apiProvider: firstParty`, and no alternate API-key source. This is installation/login status, not a live request, notebook-specific effective-route enforcement, billing proof or commercial permission. No login, credential/cache reads, settings changes, fallback, or model preflight is performed. Each outbound request separately checks the intended route in the engine’s actual notebook context before sending content; clean-Mac and human comprehension/commercial checks remain open.

Debug UX runs isolate the acknowledgement preference by harness directory. `SOPHIA_UX_CONNECTION_STATUS=missing|unknown|signed-out` injects a visibly labeled synthetic status only when a debug harness is active; normal/release runs ignore it. The existing `--without-claude` launch fault still exercises actual saved-question Retry behavior.

Cancellation and shutdown controls are recorded in [SOP7 lifecycle checks](checks/sop7-process-lifecycle.md). Quit keeps AppKit alive for bounded cleanup of exact owned Claude/status descendants; a question interrupted by shutdown remains available for explicit Retry, while intentional Stop keeps its existing meaning. New engines reconstruct saved local context rather than resuming provider state.

If an edited page range disappears before it can be saved, its unsaved text is kept separately from connection errors. Review kept edits offers selectable read-only text, Copy and individual Dismiss; Close only hides the sheet. Repeated failures and Send/Retry do not replace earlier kept edits. This recovery exists only while that notebook stays open: finish editing and copy any recovery before closing or switching notebooks. A failure first discovered during closure may not be recoverable. See [SOP51 recovery checks](checks/sop51-page-edit-recovery.md).

Explicit **Finish for now** reports a connection, unusable reply, or save failure without retrying automatically. A disk failure may leave some notes saved before completion is recorded: inspect Sophia's notes before choosing Finish again. Automatic return-note failures stay quiet. See [SOP54 feedback checks](checks/sop54-finish-feedback.md).
Linked notebook page reads and link-title discovery use an existing-only reader: missing or corrupt notebooks remain unavailable, without creating pages, defaults or recovery records. MCP `read_page` also avoids writable startup for its source notebook. See [the focused checks](checks/sop52-linked-read-only.md); this does not change the writable context used by other tools such as local `recall`.

## Notebook Home and navigation

The sidebar represents notebooks, chapters and pages. Clicking a notebook or chapter opens its actual introduction page with a live child outline. Introductions start empty and use the same reader and editor as ordinary pages; historical inquiry, goal summaries and private working memory are not regenerated as introduction prose. Starting a new notebook with a question still carries that text into an unsent composer. Goals remain available through notebook settings until their dependent page migration.

Goals and Sophia’s notes live in notebook settings, available from the notebook’s ellipsis/context menu and their existing conversation actions. They do not retarget the selected page or its conversation. About you is a separately labeled shared-Library Markdown page and conversation using whole-page review, direct source editing and Undo. A conversation header always identifies its page or the notebook; Home’s history can be expanded, and explicit Send expands it. A newly arriving relevant reply or return briefing labels that same Show conversation control without overriding a deliberate hide choice; opening it clears this window-local indicator. Composer drafts remain window-local and keyed by notebook/page, not durable across Quit.

Routine page-write banners are quieted. The page header’s contextual Undo retains the same authored-action eligibility and previous bytes; its accessible label names the action and page. It does not capture ⌘Z from the editor/composer. Unknown-provenance changes, refusals, connection errors and kept-edit recovery remain explicit.

Almanac entries show recorded publication dates without rewriting titles or using file modification times. Ordinary pages stay ordinary; unavailable dates are not invented. Preparation, timing, pause/disable and optional notifications are grouped on the Almanac’s Home/settings. A global **New Almanac entry** action appears only while a saved entry is waiting; opening an entry is not a claim that it was read or understood.

See [SOP59 native checks](checks/sop59-notebook-orientation.md) for the rendered design loop, controlled interaction evidence and limits. Focused read-only presentation checks, from `app/`:

```sh
swift build --product Sophia
SOPHIA_BIN=$(swift build --show-bin-path)
SOPHIA_CHECK_DIR=$(mktemp -d /tmp/sophia-orientation-checks.XXXXXX)
swiftc -I "$SOPHIA_BIN/Modules" Sources/Sophia/NotebookPresentation.swift checks/notebook-presentation.swift "$SOPHIA_BIN"/SophiaCore.build/*.o -o "$SOPHIA_CHECK_DIR/checks"
"$SOPHIA_CHECK_DIR/checks" "$SOPHIA_CHECK_DIR/fixtures"
```

## Sophia’s Almanac

Use **Sophia’s Almanac…** in the Library or app menu to open its Home or opt in. Choose eligible notebook names and optional topics; these and earlier Almanac entry titles go to Claude for thematic curation. The source notebooks’ pages, conversations, goals and personal assessments are not sent. Separate notebooks are excluded; if the Almanac itself is kept separate, only typed topics guide it. Enabling creates a uniquely named, marked notebook rather than converting an ordinary same-name notebook.

Manual preparation can make another entry even when an earlier one is waiting. Daily preparation is a separate explicit choice: set a local time and leave Sophia open with this Mac awake. The app checks on its timer, activation and wake; it does not run a closed-app daemon, wake the Mac, or create catch-up entries for missed days. One waiting entry blocks automatic accumulation. Pause daily preparation leaves manual preparation available; Disable stops preparation while keeping saved pages. Changing settings cancels stale preparation. Connection & Data must be acknowledged before requests; closing that information starts nothing by itself.

Entries use ordinary pages, conversation, Undo and protected editing. Background preparation keeps the current notebook, page, editor and unsent composer in place. Selecting an entry explicitly navigates; opening is not a claim of reading or learning. Prepare another entry creates another page, rather than silently replacing an edited one. Failed/cancelled preparation keeps earlier pages readable. The generation source basis is WebSearch summaries or general explanation, never a claim of inspected passages; attended conversation retains its normal source-opening permission controls.

Notifications are independently optional. **Enable notifications…** is the only action that may ask macOS for alert permission. The generic notification contains no topic or source-notebook title and is attempted only after an entry is saved. Denial or submission failure does not prevent reading/preparation; automatic notification retry does not repeatedly announce the same entry. A notification click only opens its revalidated saved target. Controlled adapter checks do not establish actual OS delivery, Focus behavior or ad-hoc-package permission behavior.

Almanac automatic opt-in is stored with its notebook and survives a whole-folder copy. Pause/disable before copying if the destination is intended only as an archive; reopening an enabled copy can prepare when eligible. Notification intent is a local per-Library preference, and OS authorization is not portable.

Controlled notification verification (no OS permission or delivery): from repository root,

```sh
swiftc app/Sources/Sophia/AlmanacNotifications.swift app/checks/almanac-notifications.swift -o /tmp/sophia-almanac-notifications
/tmp/sophia-almanac-notifications
```

Core/worker and native build observations remain separate from these adapter checks; see [SOP57 native verification](checks/sop57-almanac-native.md). Two bounded actual entries establish delivery, not factual certification: the first exposed a physical-model error; a narrow assumptions instruction improved the second sample without establishing general accuracy.

## Shared page roots and workspace

The workspace has one column order at every supported size: Library, conversation, main page. The window minimum is 1140×600; it does not stack or switch layouts. New Notebook stays in the sidebar footer (also ⌘N). Collapse the conversation with its header control; the middle rail restores it and indicates pending source decisions, errors, kept edits, replies and activity. The preference is global across notebooks/pages and survives restart. Debug harness runs isolate it from the person's preferences. Unsent drafts retain their conversation ownership.

Notebook and chapter roots open actual initially empty Markdown introduction pages through the ordinary page reader, Edit/⌘E source editor, protected writes and Undo. The current child outline is attached after the authored text. Root filenames and role/scope are recorded in notebook.json; opening preserves the previous ordering metadata once as notebook.before-page-roots.json and never replaces existing page bodies. A chapter with an introduction remains selectable when its child list becomes empty. Sidebar titles occupy one line with tail ellipsis and full hover text; new companion titles are prompted toward short, specific wording.

Connection & data is in **Sophia → Settings…** (⌘,), with contextual access beside a failed request. The first-use disclosure still precedes inference. About you uses the same actual `NotebookStore.Page`, reader, source editor and Undo as notebook pages. Its shared store owns a stable conversation, with two MCP handlers (`read_page` for this page only, and `about_you` for a reviewed proposal) plus the existing attended WebSearch capability. It has no other-notebook access or ordinary note/checkpoint processing. Accepted content is shared; pending proposals remain model-visible only at their origin. Goals, notes and memory use the canonical pages described below.


Unresolved page edits block page and notebook/About switches, Quit and the main workspace’s close action before process cleanup. A conflict requires an explicit person decision; retrying navigation does not act as Keep mine. A missing-range draft stays in the current session’s kept-edit review, including when conversation is collapsed. Resolve the editor or copy/dismiss kept text before leaving. Settings closes normally; crash recovery and unsent composer drafts keep their existing limits.

### Unified notebook pages

Goals, Sophia’s notes and Working memory are canonical Markdown pages opened in the main page pane from notebook context actions or notebook settings links. The reader, section/source editor, person-edit protection and latest-action Undo are shared with ordinary content and introductions. These auxiliary pages add no permanent sidebar rows. Their historical learning records remain inspectable as read-only evidence, not another current card editor.

`set_goal` proposes a whole Goals body for person review. `note` and `set_memory` write complete evidence-checked Markdown bodies. Checkpoints use complete bodies or null, advance coverage only after successful writes, and preserve an earlier recorded write if a later persistence step fails. Immutable migration snapshots retain raw legacy records and IDs; migration never refreshes over later prose edits.
