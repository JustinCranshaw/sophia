# Sophia (Mac app)

A native SwiftUI app. Sophia runs on the person's own Claude Code installation: the app launches the unmodified `claude` binary in headless mode with SOPHIA.md as its instructions, a restricted tool set (web search plus Sophia's two notebook tools), and the person's own Claude sign-in. Notebook files follow [DATA-MODEL.md](../DATA-MODEL.md). The approach was tested first in [spikes/claude-headless](../spikes/claude-headless/README.md).

## Requirements

- macOS 14 or later, and the Xcode Command Line Tools (Swift 6.2). Full Xcode is not required to build.
- Claude Code installed and signed in: run `claude` once in Terminal. The app looks for the official binary at `~/.local/bin/claude` (or `SOPHIA_CLAUDE`), not a wrapper on PATH. If Claude Code reports an API key instead of a subscription login, the app stops rather than bill separately.

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

- Talk with Sophia beside Contents or a page; each has its own conversation. Goals and Notes keep the conversation you were in. Web search is available. Replies and queued messages stay in their originating conversation.
- Sophia writes and revises pages directly; a write preserves the selection, composer focus, and the person’s choice to hide the book. Open on its conversation card takes you to the page and opens the book. She can group pages into chapters ("Chapter 0: Foundations"); section numbers in titles ("0.1") are set apart in the page header, contents, and sidebar. The latest write, edit or permission release on each page can be undone once, across messages and relaunch, until another action changes that page. A revision keeps the previous version. A write that already matches is labelled unchanged and creates no Undo.
- You can edit a page yourself ([EDITING.md](../EDITING.md)): hover a section heading (or the opening text) and click ✎ in the margin, or press ⌘E for the whole page. The section becomes its Markdown source, with math source shown and the formula at the caret previewed beneath it. Done (⌘↩) or a click elsewhere in the book saves; Esc reverts. Only the lines you changed are written, the previous version is kept, and Undo follows the same rule as a page write. Sophia is told about your edit with your next message, and can't overwrite your lines: a revision that would is refused and shown in the conversation, where "Let Sophia change this" lets her try again.
- Sophia records goals she hears in the conversation, provisional until you confirm them (or choose "Not my goal").
- Notes during the conversation: Sophia keeps a few notes as you talk (things to follow up, what she's learned about how you relate to the topic, attempts, open questions). Each shows as one line in the conversation, at most 8 new ones a session, and she can close or revise her own.
- Memory: Sophia keeps a short working memory per notebook ("What Sophia is keeping in mind", at the top of Sophia's notes), each line citing the notes behind it, and looks up her long-term notes with `recall` when a topic comes back. You can correct or forget any line.
- About you: background and standing preferences shared by every notebook. Sophia proposes lines from your words; a line stays in its notebook until you confirm it.
- Links between notebooks: Sophia sees only other notebooks' chapter, page, and section titles, proposes links (to a page or straight to a section) with a reason, and reads a linked page only after you confirm the link. "Keep this notebook separate" (in the notebook's contents) takes a notebook out of all of this.
- Notes on your attempts: when you come back after at least 6 hours, Sophia first writes notes on whatever you said last time; Finish for now does it sooner. Notes are kept only if they rest on something you said or did, and quotes must match your words exactly. This processing stays quiet; an invalid reply saves nothing.
- Coming back: a briefing of at most two sentences, with the one thread worth picking up and one offer. You can type straight away; your message waits for the notes. Reopening sooner (a relaunch) shows nothing. If the window was left open for hours, Sophia is told how long it has been instead. Set `SOPHIA_RETURN_GAP=<seconds>` to try this without waiting.
- Goals, with criteria, which you can also add, reword, mark met, or drop; Sophia's notes, which you can correct or delete; "Show record" on any note or goal.
- Markdown pages, replies, and Sophia's notes with LaTeX mathematics: inline formulas, display equations, fractions, matrices, and aligned derivations. Literal code stays code. Earlier Unicode notation remains readable.
- Music on pages ([MUSIC.md](../MUSIC.md)): ABC notation in an `abc` fence is typeset as staff notation, optionally with a fret-number tab line. Notation warnings show, collapsed, under the tune, and Sophia is told about them with your next message. No playback.

Not yet: guided reading, web fetch with a permission prompt, distribution signing.

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
