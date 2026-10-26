# Sophia personal research and learning notebook plan

Status: Native prototype implemented; paid launch and remaining validation proposed
Updated: October 25, 2026
Initial user and platform: Justin on macOS  
Implementation: SwiftUI/AppKit, the local Markdown/math/music reader and editor, local stores, and the official Claude CLI with stdio MCP exist. This documentation reconciliation inspects code and previously recorded observations; it does not rerun provider or native checks.

Sophia is your wise teacher, Socratic thought partner, and research assistant. It helps you investigate questions, develop understanding, and think clearly. A personal notebook emerges from the conversation as you and Sophia negotiate what is useful to preserve.

The next milestone is a small paid local Mac release that tests repeat usefulness and willingness to pay. Keep notebook storage and orchestration on the Mac, use the person's own provider account, and defer Sophia-operated sync and inference. The exact provider access route must be established before selling that integration; successful local authentication does not resolve distribution rights.

## Current implementation and evidence — October 25, 2026

The current implementation is in [app/](app/README.md). It launches the installed official Claude Code directly, without an ACP adapter, Agent SDK or HTTP proposal server. Ordinary native conversations expose WebSearch, permission-gated WebFetch and nine scoped notebook handlers: `read_page`, `write_page`, `set_chapter`, `set_goal`, `note`, `set_memory`, `recall`, `about_you`, and `link`. Internal checkpoint/briefing requests and CLI probes have narrower capabilities. The first-use disclosure and per-request local route guard are implemented; neither proves independent billing attribution or commercial eligibility.

Pages are saved/revised directly, with recorded authored actions and one previous version for durable one-way Undo. Goals recorded by Sophia are provisional until the person confirms. The person can edit a section, and store checks protect those lines. Unknown-provenance disk changes are preserved for inspection, not inferred to be Sophia's undoable writes. Chapters remain optional. Entry carries a question, interest or material into an unsent draft; there is no required page-creation sequence, intake questionnaire or universal canvas.

**Sophia’s Almanac** ([SOP55](https://linear.app/decomposer/issue/SOP-55/shape-sophias-almanac-an-optional-daily-discovery-notebook), implementation [SOP56](https://linear.app/decomposer/issue/SOP-56)/[SOP57](https://linear.app/decomposer/issue/SOP-57)) is the explicitly opted-in exception to ordinary inquiry-led notebooks: Sophia prepares finished readable entries in its own marked notebook. Selected eligible notebook names, optional typed topics and earlier Almanac entry titles guide curation; the source notebooks’ pages, conversations, goals and personal assessments are not supplied. Separate notebooks are excluded; an Almanac itself kept separate uses typed topics only. Existing confirmed cross-notebook access boundaries are unchanged. No quiz, required response, streak, learner profile or activation/retention claim follows from an entry.

Preparation is manual or explicitly enabled daily at a local time while the app remains open and the Mac is awake. Missed days coalesce; one waiting entry blocks automatic accumulation, not another explicit manual preparation. Pause/configuration changes cancel stale work. Preparation uses the existing guarded Claude route with WebSearch summaries or general explanation, not unattended WebFetch or verified source passages. Attended conversations keep their normal source-permission path. Background readiness does not switch the current notebook, page, editor or composer; Read is explicit. Optional generic notifications require a separate in-app Enable action and macOS consent, are attempted only after validated durable save, and do not start generation when clicked. No backend, closed-app daemon or wake assertion is introduced. Actual implementation checks and remaining limits will be recorded separately before this slice is considered verified.

| Recorded evidence | What was actually observed | Limits |
|---|---|---|
| [Original headless spike](spikes/claude-headless/README.md) | Real model tool delivery/resume with Claude Code 2.1.299 and Node 26.0.0 | Historical spike, not the current release configuration |
| [Entry comparison](research/2026-10-25-entry-charrette/README.md) | Native question/material carriage, drafts and responsive book layouts, with explicit source epochs | Internal/synthetic comparison, not human preference or delayed retention |
| [Conversation following](research/2026-10-25-conversation-follow/README.md) | Native streaming/committed reader continuity and deliberate reading position | Recorded scenarios, not universal scroll correctness |
| [Local package/reader/Core/MCP report](research/2026-10-25-packaged-release/README.md) | Targeted ad-hoc release packaging/reader checks on `b2dfa1d`, and a bounded three-turn release-Core/MCP CLI sequence on `7965f04` with actual handled reads, provisional goal, create/revise and exact previous bytes; official CLI 2.1.304, runtime claude-fable-5-1 | CLI caller has no native source bridge; current packaged native Send/edit/Undo, clean Mac, human usefulness and billing remain unproven |
| [Native source-opening report](https://github.com/JustinCranshaw/sophia/pull/12) | Explicit URL approval/denial and actual provider-extracted content, separately attributed to debug-app source epochs | Extraction is potentially lossy; undirected discovery failures remain recorded and parent research acceptance is incomplete |
| [Lifecycle](app/checks/sop7-process-lifecycle.md), [kept edits](app/checks/sop51-page-edit-recovery.md) and [Finish feedback](app/checks/sop54-finish-feedback.md) | Controlled native cancellation/reopen, exact transient recovery copies and explicit checkpoint failures, including partial save uncertainty | Controlled protocol failures are not actual service outages; drafts/recovery are not durable; checkpoint retry is non-atomic |
| [Final release-Core source denial](research/2026-10-25-native-source-denial/README.md) | One actual WebFetch permission request on unchanged release Core/native-engine configuration; controlled denial, no content returned, truthful reply and captured owned cleanup | Instrumented CLI caller, not native UI or successful extraction; empty previous/learning histories, billing/commercial inconclusive |
| [Bounded source return and continuation](research/2026-10-25-source-return-replay/README.md) | Native access to two developer-supplied candidates and a separately authorized continuation using their saved extractions; original pages/order preserved | Useful partial comparison; legacy-side passage missing, arithmetic/attribution/interpretation errors and procedural filler retained; not unseeded discovery or human learning |

A check executable's existence is source evidence, not a passing run. Follow each report's source/version, synthetic-vs-actual attribution and limits. New checks belong to the active issue. The paid offer, genuine delayed return, clean-Mac/release interaction, provider commercial route and customer demand below remain open; technical success does not close them.

### Working identity in the native app

The user selected DC Trued Channel in solid paired Plum, then Palatino for the Sophia wordmark with a tighter inline gap. [SOP68](https://linear.app/decomposer/issue/SOP-68) integrates that fixed identity into the native toolbar, selection and empty-Library treatment, plus a replaceable application-icon treatment. It does not change the companion prompt, provider route, reading/body fonts or notebook data. The design decisions and measured scope are recorded in [brand decisions](docs/brand-decisions.md) and [native checks](app/checks/sop68-native-brand.md); this is local implementation, not release/distribution or human preference validation. [SOP69](https://linear.app/decomposer/issue/SOP-69) carries selective signature/ink roles into existing notebook and Almanac surfaces while keeping native controls, reading fonts and all notebook behaviours steady. Its inactive-window observation limit and the separate orange-contrast follow-up remain explicit.

### Notebook orientation and reading

[SOP59](https://linear.app/decomposer/issue/SOP-59) makes navigation represent content: notebook Home gives the actual contents, confirmed working goals, an optional clearly historical inquiry and a labeled generic companion approach. It does not turn private memory/assessment notes into an introduction, infer mastery or add an intro schema. Goals/notes are management sheets, while About you retains explicit shared-Library scope. Page conversations and window-local drafts keep their existing thread ownership, made visible in every layout; no migration or new thread store is introduced.

Recorded Almanac dates distinguish its entries without changing page titles or using modification times. Routine write banners become contextual page-header Undo; unknown-provenance, refusal, error and kept-edit exceptions stay explicit. Preparation/notification controls are local to the Almanac, with an actionable global new-entry affordance rather than permanent status/options controls. [Native implementation evidence](app/checks/sop59-notebook-orientation.md) separates controlled fixtures, observations and remaining limits; the parallel branding explorations do not change the app’s fonts, palette or identity here.

## Launch scope — founder proposals from October 14, 2026

This section records the proposed paid-release scope, rather than claiming those launch conditions are met. The original ACP/HTTP experiment below remains a fallback investigation, rather than a prerequisite to rebuild before using the existing native prototype. Current page behavior is direct writes with undo, as defined in SOPHIA.md and DATA-MODEL.md.

### Who and what to validate

Start with independent learners and researchers on macOS who already use Claude and want to build understanding over several visits. Recruit around one concrete inquiry per person. The promise is a useful conversation that grows a sourced, personal book and helps the person pick up where they left off.

Test three assumptions separately: people get value beyond an ordinary chat; they return to the same inquiry; and some pay for Sophia while paying their provider separately. Provider setup friction is part of the experiment. The initial cohort will test this audience choice, rather than establish a general market.

### The first paid release

- One Mac, one person, local notebook files, and one supported provider route. No Sophia account is required to use the notebook.
- Create and reopen notebooks; converse beside the book; write and revise sourced Markdown/math pages through conversation; undo a write; inspect, correct, and remove Sophia's notes; confirm provisional goals; return with a grounded briefing.
- Edit a page section directly, with Sophia unable to overwrite the edit unless the person lets her ([EDITING.md](EDITING.md), Phase 1; implemented, with remaining native/manual checks identified there).
- Keep chapters optional. Do not hold launch for automated chapter organization, guided reading, document ingestion, semantic search, or executable artifacts.
- Setup identifies the supported provider installation, sign-in, and billing route. Explain limits, expired login, cancellation, offline state, and recovery. Provider usage is billed directly to the person; never silently change the billing route.
- Local means storage and orchestration, not offline AI. Prompts and relevant notebook context go to the chosen provider, and research may contact the web. State this before the first request. Existing pages remain readable without a working provider connection.
- Let the person locate and copy/export a whole notebook and restore it on another installation. Test backups and recovery before advertising them. Cloud-folder placement is not a supported sync feature; concurrent multi-device editing is outside launch scope.
- Distribute a signed, notarized download with installation instructions, a support contact, and a simple manual update path that preserves notebooks. Use static hosting and hosted checkout; begin with manual purchase support rather than building an identity service or license server.

Proposed offer, owned by Justin: a one-time purchase for the current major version, with AI costs separate and future hosted services priced separately if introduced. Choose a price, evaluation period, refund terms, and update entitlement before the paid pilot. Do not promise lifetime inference, lifetime updates, or cloud sync. Actual purchases are the commercial evidence; interviews and free signups are supporting evidence.

### Provider decision before committing to onboarding

Prefer the existing Claude subscription route only if its exact paid-app arrangement is established as permitted. The October 14 planning assessment cited Anthropic's [legal page](https://code.claude.com/docs/en/legal-and-compliance) both describes end-user sign-in to an unmodified Claude Code binary and restricts third-party apps routing subscription requests; the [SDK overview](https://code.claude.com/docs/en/agent-sdk/overview) also requires prior approval for third-party subscription access. That assessment was dated October 14, 2026; this documentation pass does not re-establish current commercial terms. Sophia's eligibility remains unproven.

If subscription access is unavailable, a user-supplied API key remains compatible with local storage and no Sophia inference backend. This is an explicit product choice for Justin, not an authorized fallback. Decide whether its onboarding and separate usage charges still fit the initial audience. If chosen, implement and verify only that route, including secure credential handling and billing disclosure. Do not build both routes preemptively. No provider messages are authorized by this plan.

### Sequence and proposed decision gates

1. **Establish the offer and access route.** Reconcile the documents with the prototype, resolve permitted distribution/authentication, select the initial audience, and define what the app purchase includes. Continue companion evaluation while access is unresolved.
2. **Prove the inquiry and delayed return.** Use disposable material for a real inquiry, a page revision and undo, and a return about a week later. Correct an inaccurate account and check that the correction persists. Test direct research as well as learning so the companion does not impose exercises. Record observed results separately from source inspection and reports.
3. **Ship a reliable private beta.** Verify the exact supported engine/version, effective restrictions and settings isolation, actual tool calls, save/undo/crash behavior, cancellation and restart, local reader behavior, backup/restore, and clean-Mac installation. Corroborate billing attribution; label unavailable evidence inconclusive. Use the existing commands in app/README.md rather than introducing another harness.
4. **Run a paid pilot.** Proposed cohort: 10–15 qualified Mac users. Track installation, first useful inquiry/page, a meaningful return after roughly a week, purchase/refund, and why people stop. Use scheduled conversations and voluntary local summaries; do not upload notebook content or add analytics infrastructure to measure this. Justin conducts recruitment and outreach separately.
5. **Decide from behavior.** A proposed pilot gate is at least five people returning to an inquiry in week two and at least three actual purchases at the stated price. These are founder decision thresholds, not statistical proof. If return is weak, improve the companion and return experience. If use is strong but purchase is weak, revisit positioning, setup friction, and the offer before expanding infrastructure. Justin owns the final go/no-go decision.

### Infrastructure follows a demonstrated obstacle

| Later investment | Evidence required before scoping implementation |
|---|---|
| Cross-device sync | Several retained paying users repeatedly need the same notebook on two devices and manual transfer blocks continued use; proposed review trigger: five documented requests from active customers |
| Sophia-managed API usage and recurring pricing | Qualified prospects repeatedly abandon BYO setup or paying users request bundled usage; proposed review trigger: five attributable lost activations, plus an affordable unit-cost model and provider eligibility |
| Additional provider | Repeated lost sales or retained-user requests attributable to the current provider; implement one concrete alternative rather than a general adapter platform |
| Search/indexing, richer import, chapter automation | Recorded failures in real notebooks that the current reader and conversation cannot address adequately |

Triggers open a discovery decision; they do not automatically authorize a build. Sync must account for conflicts, recovery, privacy, and migrations when needed. Managed inference must account for payment, metering, abuse, support, and margin when needed. No sync schema, account database, billing ledger, job queue, or backend platform is part of launch.

### Evidence and next-work groups

Use the current implementation/evidence section above for actual observations and their limits. The original spike version is historical; later runs record their exact launched CLI and model separately. Billing attribution, genuine delayed return, clean-Mac distribution and paid demand remain unproven.

Organize next work into four projects: **Access and companion validation**, **Reliable local Mac beta**, **Paid launch and demand validation**, and **Later infrastructure — discovery only**. Keep the last project in backlog; sequence implementation around the first three. Each issue needs a concrete completion observation. Do not create duplicate feature-building issues for behavior already present in the prototype.

## 1. Requirements and product boundaries

The user's latest instructions take precedence over earlier proposals:

- Build a useful native Mac experience, then validate a small paid local release before investing in hosted infrastructure.
- Sophia combines teaching, thoughtful dialogue, and research. It should not turn every conversation into a lesson or examination.
- Organize a Library into Notebooks, optional Chapters, and Pages. Structure and pages develop through conversation.
- Each notebook is an emergent textbook. The person guides each step, and the book grows to their needs rather than following a curriculum Sophia generates in advance.
- Each notebook has Goals: what the person wants from it, in their words, with what reaching each goal would look like. Progress is shown as evidence from actual attempts and current pages, never as a score. Sophia records a provisional goal or refinement; the person confirms it and alone marks a goal met or dropped.
- What becomes a durable page is a negotiation between the person and Sophia. The person can also edit a page directly, a section at a time; the store keeps Sophia from overwriting those edits ([EDITING.md](EDITING.md)).
- Questions flow both ways. Sophia can challenge reasoning and examine understanding when useful, while the person directs the inquiry and challenges Sophia.
- The current engine is the official Claude CLI. Codex remains a deferred alternative; subscription access must be supported and permitted, and API billing is an explicit product decision, never a silent fallback.
- Preserve the longer-term goal of a consistent Sophia experience across engines. Prove usefulness on one engine before investing in parity.

The initial interests are LLM architectures, graph clustering, linear algebra, United States history, and scientifically grounded parenting for children almost three and five as of this plan. Justin has a PhD in computer science and wants to refresh technical knowledge, particularly to develop expertise in graph clustering. These interests exercise one product rather than define separate application modes.

The old social-platform discussion contributes conversation-backed durable pages. Voting, public consensus, feeds, contributor reputation, and community discovery are outside current scope.

## 2. The companion and the notebook

### Adapt to the inquiry

Sophia infers the helpful approach from the conversation rather than requiring a mode picker:

| Need | Useful behavior |
|---|---|
| Understand something unfamiliar or rusty | Explain, develop intuition, work an example, and offer an appropriate check of understanding |
| Think through an idea | Ask questions that expose assumptions, compare alternatives, disagree with reasons, and help refine the argument |
| Investigate a factual question | Find and inspect sources, compare accounts, synthesize evidence, and distinguish findings from uncertainty |

These behaviors can coexist within one exchange. A direct question may deserve a direct answer. Research can end with a useful source comparison without an examination. Socratic dialogue should not become a ritual of withholding explanations. A conversation need not produce a page.

When learning is the goal, Sophia can ask the person to predict, explain, derive, compare, or apply an idea to a changed example. Reading a page or agreeing with Sophia does not demonstrate understanding. Retain actual attempts separately from the agent's tentative assessment. Do not create a permanent ability score or assess the person in conversations that do not call for it.

[SOPHIA.md](SOPHIA.md) is the effective runtime instruction artifact. It defines the companion's judgment, teaching, research, negotiation, tool boundaries, and return behavior. Changes to it need behavior verification; documentation-only work must not silently change the effective prompt.

### A first inquiry

Start a Graph Clustering notebook with one question, such as why eigenvectors help partition a graph. Sophia explores the person's intuition, explains what is needed, examines a small example, and responds to challenges or misunderstandings. It can offer a prediction or application question where appropriate.

Either participant may suggest preserving a useful explanation or counterexample. Sophia writes and revises pages directly as the conversation calls for them, without writing ahead of the person's inquiry. The client records each write, shows the page beside the conversation, and offers undo. Only the person confirms goals or marks them met or dropped.

On return, Sophia gives a brief account grounded in saved evidence: the open question, last relevant idea or attempt, remaining uncertainty, and a useful next step. The person can correct that account or change direction. The next step may be reading a source, discussing an objection, trying an example, or answering a question.

The product hypothesis is that this companionship improves inquiry and makes returning useful. Its deciding observation is a delayed return: can Justin recover context without rereading the whole chat and make meaningful progress, whether through explanation, a fresh example, or a better-supported argument?

## 3. Historical ACP/HTTP experiment design (not the current launch prerequisite)

Historical experiment design: the prototype now uses the unmodified Claude CLI and stdio MCP directly (see app/README.md and spikes/claude-headless/README.md). Retain the pinned ACP alternatives below if the direct route has a demonstrated failure. An HTTP proposal experiment is not a remaining launch requirement; test actual `write_page` delivery and undo on the selected route.

### October 2026 review-reported connection observations

The supplied independent review reports successful no-prompt checks on this Mac: Claude authentication as `claude.ai`, Codex authentication as ChatGPT with a Pro plan, App Server `initialize`/`account/read`, and `initialize` plus `session/new` with both current adapter packages. These supersede the earlier restricted-environment failures for connection feasibility. They do not establish request billing, model-visible tools, companion quality, or commercial permission.

| Component | Pinned baseline | Status |
|---|---|---|
| Initial Claude adapter | `@agentclientprotocol/claude-agent-acp@0.90.0` | Reviewer reports clean session creation |
| Installed Claude Code | `2.1.299` | Recorded during the historical planning revision |
| Deferred Codex adapter | `@agentclientprotocol/codex-acp@2.2.2` | Reviewer reports clean session creation |
| Installed Codex CLI | `0.162.1` | Recorded during the historical planning revision |

Do not use deprecated `@zed-industries/codex-acp@0.16.0`. Pin published packages and retain the lockfile. Record the actual Node, adapter, SDK, and launched engine versions; a bundled binary may differ from the globally installed CLI. Adapter/package session results above are attributed to the review, not independently rerun here.

### Thin client and effective configuration

The historical proposal was a disposable Node command-line ACP client before native work; it is not the current implementation sequence. Run one 20–30 minute graph-clustering inquiry. Use a disposable notebook and a harmless canary file outside it.

Supply these candidate SDK options through the pinned adapter's `_meta.claudeCode.options` support, then verify their effect:

- `settingSources: []` to avoid unintended user/project/local hooks, skills, instructions, connectors, and allow-rules. Confirm the effective configuration; do not assume this overrides managed policy.
- `systemPrompt` containing SOPHIA.md, injected explicitly. Do not depend on discovering a global or project `CLAUDE.md`.
- `tools: ["WebSearch", "WebFetch"]` for built-in tools. Sophia's MCP tools are separate. Do not expose file, shell, process, computer-use, or general code-execution tools.
- A supported permission configuration that can deny the web request exercised by the test. Enabling a tool does not mean it requires an ACP prompt on every call.

The inspected adapter source supports SDK option overrides and custom prompts; the reviewer reports tool/settings restrictions working. Released configuration and model behavior still need verification. Anthropic documents custom prompts for non-coding agents and makes their author responsible for necessary tool and safety guidance. [S3, S8]

Use a clean child environment that retains ordinary OS/CLI login access while excluding API credentials and alternate-provider routing. At minimum do not forward `ANTHROPIC_API_KEY`, `CODEX_API_KEY`, or `OPENAI_API_KEY`. Verify the effective authentication method too: removing environment keys alone does not exclude a configured key helper or another billing route. Do not log secrets, extract subscription tokens, or choose a launch mode that disables subscription authentication.

### Prove tool delivery before the full inquiry

Host an in-process Streamable HTTP MCP server on loopback with per-run authentication. Expose `read_page` and `propose_page`; add `propose_artifact` only when needed. Send it through `session/new.mcpServers`.

The first model-backed test must actually invoke `propose_page` and reach the client's handler. Then exercise Accept, Defer, and Reject. An HTTP capability advertisement or a standalone `tools/list` is insufficient proof of model access.

HTTP is a hypothesis to test, not a demonstrated fix. Claude issue #883 reports missing stdio MCP tools on 0.59.0 through 0.70.0; it does not establish failure on 0.90.0. Both adapters reportedly advertised HTTP support in the review. [S9]

Current native source opening and its actual content/denial evidence are recorded above and in PR12. They use the direct CLI, not this historical HTTP proposal configuration. CLI probes remain WebSearch-only unless supplied a native approval bridge.

### Historical ACP/HTTP acceptance design

| Check | Required observation |
|---|---|
| Billing | Session metadata selects `claude.ai`, excluded credentials are absent, and provider usage corroborates subscription attribution. If attribution is unavailable, mark billing inconclusive rather than equating login with proof |
| Tool delivery and saving | A real HTTP MCP `propose_page` call reaches the client. Accept saves exactly that proposal; Defer and Reject leave canonical pages and ordering unchanged |
| Research and denial | Inspect a supporting source; deny one WebFetch through an effective policy. Sophia acknowledges missing evidence and continues without inventing support. If no permission callback occurs, resolve that configuration before promising a permission UI |
| Cancellation | Cancel a controlled slow tool call, target a `cancelled` response in about two seconds, measure actual latency, and clear pending prompts. Check tool cleanup and client-exit cleanup; an intentionally open agent session is not an orphan |
| Capability limits | Requests to read the external canary or run a shell command fail because no exposed capability provides that access |
| Restart | Kill and relaunch the client with several page threads live. Each thread shows exactly what was stored, without duplicates; a reply cut off shows as interrupted. Each thread's context is rebuilt from storage with nothing shown about it. Produce an accurate return briefing |
| Companion quality | Justin finds the exchange useful and wants to return. During a learning-directed portion, Sophia offers an appropriate understanding check and adapts to an incorrect attempt. During research or discussion, it answers and investigates without imposing a lesson |

Do not count a quota of questions as evidence of quality. Include both a direct research question and a learning-directed question so the experiment can expose a heavy-handed teaching persona.

If tool delivery fails, inspect the HTTP handshake and effective options. If ACP is the obstruction, try the Agent SDK directly with the same instructions, tools, and restrictions. This changes the connection, not subscription permission. If billing cannot be established, Justin decides whether to use explicit API billing for further testing or await clarification. Never silently fall back. If the companion is unhelpful, revise SOPHIA.md and try another focused exchange before further experiments on that historical alternative.

## 4. Notebook tools, saving, and return

The current ordinary MCP tools are `read_page`, `write_page`, `set_chapter`, `set_goal`, `note`, `set_memory`, `recall`, `about_you`, and `link`. They accept notebook-scoped identifiers or content rather than arbitrary host paths. Page writes go through the store's checks and locking, are recorded, preserve one previous version, and are undoable. Tools cannot delete pages, remove the person's records, or confirm or complete goals. Only the person confirms a goal. DATA-MODEL.md governs current record and undo behavior.

The store must enforce this boundary independently of provider permission prompts. Review-reported Codex permission and lifecycle issues reinforce checking its behavior before adding that engine. [S10]

Start with this small format:

```text
notebook/
  notebook.json
  pages/<filename>.md
  pages/<filename>.previous.md
  transcript.jsonl
  learning.jsonl
```

[DATA-MODEL.md](DATA-MODEL.md) defines these files, the record shapes inside them, who may write each, and the checks the client applies. In brief: `notebook.json` holds chapters and page order; page frontmatter holds title and inspectable sources; `transcript.jsonl` holds the conversation, page writes, and undo records (plus legacy proposals); `learning.jsonl` holds goals, Sophia's notes on attempts, the person's takes and corrections, and return briefings, all in one record shape with a client-stamped author and links to evidence. The directory supplies the notebook name. Keep one previous page version for undo. Do not require an examination record for a research-only discussion. Each page, and the notebook's Contents, has its own conversation thread. These threads are kept in the one transcript, each entry tagged with its page. The current native client requests notes through Finish for now and catch-up on return. Core helpers also support legacy clear boundaries; a native fresh-start action and automatic long-thread checkpoint trigger are not implemented. It records the checkpoint as Sophia's account, not an objective measure of the person. Checkpoint notes and working memory are retained as inspectable learning records; no private provider session state is persisted. Connection failures can leave explicit failure/recovery evidence instead of silently advancing a checkpoint.

Replace individual page files atomically. If an unrecorded page exists on disk, index it on reopening with unknown provenance and no destructive Undo. Defer cross-notebook IDs, a separate source catalog, multi-file transaction machinery, and format migrations until a real workflow needs them.

For the return briefing, supply a bounded selection of recent inquiry/learning records and saved pages. Sophia should ground its account in those records and invite correction.

**Rebuilding context.** Sophia's context for a thread is rebuilt from storage whenever that thread's conversation starts:
- her standing context;
- the page;
- her notes on it;
- the thread's last few exchanges before the latest notes, and everything since, word for word.

A checkpoint ends every thread's conversation process, so her view always follows her notes.

**Not resuming.** Provider sessions are not stored or resumed, and nothing is shown to the person when context is rebuilt. A rebuilt thread lacks what its earlier process held privately, such as search results or pages read; SOPHIA.md tells her to look again rather than assume she still has them, and never to claim to restore private provider state she does not possess.

**Deferred: resuming provider sessions.** Resuming a thread's provider session is deferred behind one test, run with the app's exact flags:
1. Resume with a changed `--append-system-prompt` containing a sentinel word, and ask Sophia to quote it.
2. Resume with a changed `--system-prompt`.
3. Resume with an id that does not exist.

Store a map from threads to provider sessions in notebook.json only if both of these hold:
- fresh context reaches the resumed session and the bad id fails detectably;
- a rebuilt thread is shown to lose a step that a resumed one kept.

## 5. Native application: implemented behavior and remaining design

The native prototype already exists. Continue scoped reliability and workflow work against it while separately evaluating a useful inquiry and a genuine return after approximately a week. Check the briefing, continue the inquiry, and correct a mistaken account through dialogue. Accelerated/internal returns do not complete that human validation. The original experiment-before-native ordering is historical.

The October 25 internal entry comparison carries a question or supplied material into an unsent conversation, with an optional notebook name. Empty notebooks begin with the book hidden; an explicitly opened book sits below the conversation when readable columns do not fit, and beside it at wider sizes. Drafts are retained within the current window, separate by notebook and conversation thread; book visibility choices last for the running app. Neither persists across relaunch. [The comparison](research/2026-10-25-entry-charrette/README.md) records the critique-driven revision and actual native/model checks; it does not establish human preference, learning or delayed return.

| Part | Direction and reason |
|---|---|
| Windows, outline, commands, composer | SwiftUI with AppKit where useful; native Mac interaction is the user's preference |
| Mathematical transcript and page reader | Markdown with LaTeX math (`$...$` inline, `$$...$$` display); the Mac app bundles markdown-it, its texmath extension, KaTeX, and DOMPurify in WebKit, with local fonts and no rendering network requests |
| Agent connection | The prototype launches the installed, unmodified Claude CLI with stdio MCP. Keep one connection; revisit ACP or SDK alternatives only for a demonstrated failure and a permitted access route |
| Artifacts | Separate restricted WebKit surface, introduced only when an actual inquiry benefits from one |
| Storage | The minimal local format from section 4, independent of provider sessions |

The book and the conversation are separate surfaces. Before a notebook has a page, the Contents conversation fills the window. Once it has one, selecting a page shows the page and that page's own conversation together. Selecting the Contents shows the notebook-level conversation. Selecting a different page (including a return) starts at its title, except an explicit section link; revisions to the same open page retain the reader identity. Chapters, Goals and Sophia's notes have no conversation of their own. A reply finishes in its own thread if the person moves to another page. The book can be hidden; a new page preserves that choice and the current selection. Its conversation card offers Open, which selects the page and opens the book. Serif type marks what is in the book; the conversation is set in the system face. Sophia saves pages and revisions directly (the person decided drafts added friction); the conversation points to each page written, and the person can undo it or ask for changes. The companion can discuss pages in the conversation. Guided selection-to-question interaction remains a design direction, not a shipped passage-selection feature. [mock/index.html](mock/index.html) is a historical interaction reference with explicit current-vs-exploration labels.

**Unrecorded disk changes.** Hashes and orphan files cannot distinguish a crash-before-entry from outside edits. Index them with unknown provenance, preserve current and previous bytes until a later content-changing recorded write or edit replaces the single previous slot, and offer inspection/manual restoration rather than destructive Undo. Unchanged requests retain both versions and inspection. Normal recorded page writes and personal edits keep durable one-way Undo; automatic Undo of an unrecorded interrupted write is outside the current promise.

**Selection and focus.** Selecting a page selects its conversation, and the title above the composer names it ("1.3 The convolution theorem"; on Contents, "Fourier analysis · notebook conversation"). A write by Sophia never changes the selection or takes focus from the composer: her card in the conversation names the page and offers Open. Goals and Sophia's notes have no conversation of their own; opening them keeps the current conversation beside them, still named. A reply that finishes after the person has moved on marks its row until that conversation is next shown; nothing about it is stored.

**Return (implemented boundary).** On an informed opening after the six-hour quiet threshold, the client may catch up outstanding notes and request a checked, short briefing in the Contents thread. Unacknowledged first use suppresses that opening's automatic request; dismissing the information starts nothing. Opening a notebook starts at Contents. A persistent “Continue on …” navigation affordance, a sticky briefing above a different page, and restoring a saved selection are design ideas, not implemented promises.

**Fresh start and history (design, not current UI).** Core records/context helpers understand legacy clear boundaries, but the current app does not expose the proposed ⇧⌘N fresh-start action, folded “Earlier on this page” history, date separators/older-message loading, or passage-to-question actions. Do not treat the mock's controls as implemented native features. Add them only through a scoped workflow and actual native verification.

Preserve focus, selection/copy, scroll position, and return to writing. Conversation following is local: follow at the end, retain the person’s position above it, and offer an explicit jump for new current-thread activity. Test long streamed mathematics, accessibility, page writes and undo, failures, and restoration on the actual Mac interface.

**Deferred artifact design.** A future client may support HTML/JavaScript proposals without executing them. Before running it, prove the viewer has no credentials, general desktop bridge, host file access, or unrestricted network access. Supply only explicit data and retain experiment parameters when accepted. Check a small graph experiment against a known example before relying on its output.

For the alpha, capability restriction replaces an operating-system sandbox project: no built-in shell/file tools and only scoped notebook handlers. This is not a claim of general host isolation. Use non-sensitive study material until the launch configuration passes its tests. Reconsider stronger isolation before enabling broader execution or sensitive material.

After repeated personal use, try the same product model for linear algebra, LLMs, historical sources, and parenting. Distinguish source findings, Sophia's interpretation, and personal observations. An assessment remains tentative; a citation should reveal what was actually inspected.

## 6. Access and commercial decisions start now

A subscription-backed paid custom client is not an assumed launch route. Resolve provider access in parallel with the personal experiment, before committing to that business model. The documented general third-party route is API billing; accepting that alternative remains Justin's decision.

The October 14 planning review recorded that Anthropic's legal page restricts third-party Claude.ai login and requests routed through subscription credentials on users' behalf. Its SDK overview allows previously approved arrangements. The same legal page describes hosting an unmodified binary with end-user authentication, but that does not establish approval for Sophia's custom ACP/SDK interface. Sophia has no such approval established. Personal experimentation is not explicitly classified in these sources; do not convert technical success into blanket permission. [S4]

The October 14 source assessment recorded restrictions on using OpenAI App Server authentication for commercial or hosted services. That assessment cited Sign in with ChatGPT guidance directing paid applications to an interest process. That historical assessment reported credentials that could drive App Server, but compatibility with the selected adapter and commercial eligibility remain to be established; the ordinary adapter login does not prove support for that route. [S5, S6]

Zed demonstrates subscription-backed external agents. Its June 16, 2026 update also reports postponement of a proposed third-party billing change. These are useful dated precedents, not authorization for Sophia or a guarantee of future costs. [S7]

Historical founder-owned inquiry draft (must be updated to describe the actual direct-CLI architecture before any authorized outreach):

> Sophia is a locally running Mac research and learning notebook with a custom conversation interface over your unmodified agent through an ACP adapter. Users authenticate through your own flow and pay you directly; Sophia does not extract credentials or resell inference. What permission and registration are required for personal experimentation, an open-source release, and a paid local app? Is subscription-backed use available for this arrangement, or must product usage be API-billed?

No provider inquiry is established by this plan or the engineering verification reports. The supplied review does not authorize external messaging. Contacting sales or joining a waitlist is not itself approval.

Before any paid release, choose an actually available access model, confirm the applicable conditions, and test that exact release configuration. Then address dependency redistribution, clean-Mac installation, signing/notarization, updates, backups, and any necessary format conversion.

## 7. Deferred work and decision triggers

- **Codex and parity:** add only after repeated Claude use proves value and a concrete need justifies another engine. Repeat live workflow and billing checks before claiming parity.
- **Cross-notebook identity, source catalog, and transaction framework:** add only when actual reuse or coupled changes defeat the minimal format.
- **Scheduled review or a dashboard:** add when manual return suggestions are useful and Justin wants automation or a separate view. Do not infer mastery from reading.
- **Semantic search:** add after representative notebooks show retrieval failures or unacceptable delay.
- **Sync, other operating systems, social features:** require an actual use case beyond the single-user Mac product.
- **General code execution:** require a demonstrated inquiry need and an adequate tested boundary before enabling it.

The main unknowns are repeat companion usefulness, whether the release configuration reliably enforces its capability limits, which access model supports a paid product, and whether customers will buy it. Resolve those before broad infrastructure work.

## 8. Independent review brief and evidence

Review this plan and SOPHIA.md without implementing them. Prioritize the launch scope, companion behavior, effective tool/prompt configuration, store-enforced page writes and undo, minimal return records, subscription permission, and paid-demand experiment. Distinguish reported observations, inspected source, released behavior, inference, and untested claims. For each material finding, cite the relevant section and source, explain the consequence, and propose the smallest correction or deciding test. Reject complexity justified only by possible future scale or reuse.

Evidence status: the headless spike README now reports a model-backed tool call and resume; those observations were not rerun during this product-planning pass. Successful adapter session creation and account metadata in the original experiment plan are supplied by the independent review; its probe artifacts were not included in the pasted text. Source inspection is not proof of released behavior or a completed live workflow. Paid distribution rights, billing attribution, delayed return, and customer demand require their own evidence.

Sources inspected October 14, 2026; recheck consequential provider conditions before acting:

- **S1 — ACP interfaces:** [Overview](https://agentclientprotocol.com/protocol/v1/overview), [authentication](https://agentclientprotocol.com/protocol/v1/authentication), and [session setup](https://agentclientprotocol.com/protocol/v1/session-setup).
- **S2 — Adapter projects:** [Claude ACP](https://github.com/agentclientprotocol/claude-agent-acp) and [current Codex ACP](https://github.com/agentclientprotocol/codex-acp). Use the exact package baselines in section 3, not archived package names.
- **S3 — Claude implementation:** [SDK options, prompt configuration, and authentication](https://github.com/agentclientprotocol/claude-agent-acp/blob/main/src/acp-agent.ts). Inspected source supports custom options; the pinned release still needs live verification.
- **S4 — Anthropic conditions:** [Legal and compliance](https://code.claude.com/docs/en/legal-and-compliance) and [Agent SDK overview](https://code.claude.com/docs/en/agent-sdk/overview).
- **S5 — Official OpenAI guidance:** [App Server protocol, authentication, and limitations](https://learn.chatgpt.com/docs/app-server).
- **S6 — Official OpenAI plan access:** [Sign in with ChatGPT eligibility](https://developers.openai.com/siwc/token-sharing-open-source) and [App Server configuration](https://developers.openai.com/siwc/token-sharing-open-source/codex-app-server).
- **S7 — Zed precedent:** [Existing subscriptions](https://zed.dev/docs/ai/use-an-existing-subscription) and [billing discussion updated June 16, 2026](https://zed.dev/blog/anthropic-subscription-changes).
- **S8 — Explicit instructions:** [Anthropic's custom-system-prompt guidance](https://code.claude.com/docs/en/agent-sdk/modifying-system-prompts).
- **S9 — Claude tool-delivery risk:** [Issue 883](https://github.com/agentclientprotocol/claude-agent-acp/issues/883), with reports covering 0.59.0 through 0.70.0. Failure on 0.90.0 and success over HTTP are not established.
- **S10 — Deferred Codex risks:** [MCP lifecycle issue 628](https://github.com/agentclientprotocol/codex-acp/issues/628), including a 2.2.2 reproduction, and [permission issue 401](https://github.com/agentclientprotocol/codex-acp/issues/401), reported on adapter 1.2.0/Codex 0.147.0. Do not generalize the older reproduction to every current call.
- **S11 — Later implementation aids:** [Community Swift ACP libraries](https://agentclientprotocol.com/libraries/community) and [ACP compatibility testing](https://agentclientprotocol.com/libraries/testing).

Local readiness slice (SOP47): show dismissible first-use Connection & Data information before an opening can automatically send return/checkpoint context; suppress that opening’s automatic return while unacknowledged, and do not start it on dismissal. Reading and drafts remain local and usable. Explicit local auth status is a bounded, allowlisted installation/login check, not a model probe or notebook-specific route guarantee. Intended status-ready requires claude.ai/firstParty. SOP48 adds a separate per-request route guard before inference starts or notebook content is delivered: the exact executable, notebook working directory, scrubbed environment, restricted/empty-source isolation and explicit permission settings are shared with the bounded local auth-status check. Only claude.ai/firstParty without an API-key source proceeds, including reused and internal requests; failed checks preserve saved questions and failed checkpoint evidence. Status is point-in-time, with the runtime source check retained. Clean-Mac, human comprehension, independent billing attribution and commercial eligibility are not established here.
