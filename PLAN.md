# Sophia personal research and learning notebook plan

Status: Product launch scope proposed; implementation and evidence reconciled  
Updated: October 14, 2026  
Initial user and platform: Justin on macOS  
Implementation: A native Mac prototype and a Claude headless spike exist. This planning pass inspected their source and recorded results; it did not rerun the app or live checks.

Sophia is your wise teacher, Socratic thought partner, and research assistant. It helps you investigate questions, develop understanding, and think clearly. A personal notebook emerges from the conversation as you and Sophia negotiate what is useful to preserve.

The next milestone is a small paid local Mac release that tests repeat usefulness and willingness to pay. Keep notebook storage and orchestration on the Mac, use the person's own provider account, and defer Sophia-operated sync and inference. The exact provider access route must be established before selling that integration; successful local authentication does not resolve distribution rights.

## Launch scope — October 14, 2026

This section records the latest product direction and governs the next work. The original ACP/HTTP experiment below remains a fallback investigation, rather than a prerequisite to rebuild before using the existing native prototype. Current page behavior is direct writes with undo, as defined in SOPHIA.md and DATA-MODEL.md.

### Who and what to validate

Start with independent learners and researchers on macOS who already use Claude and want to build understanding over several visits. Recruit around one concrete inquiry per person. The promise is a useful conversation that grows a sourced, personal book and helps the person pick up where they left off.

Test three assumptions separately: people get value beyond an ordinary chat; they return to the same inquiry; and some pay for Sophia while paying their provider separately. Provider setup friction is part of the experiment. The initial cohort will test this audience choice, rather than establish a general market.

### The first paid release

- One Mac, one person, local notebook files, and one supported provider route. No Sophia account is required to use the notebook.
- Create and reopen notebooks; converse beside the book; write and revise sourced Markdown/math pages through conversation; undo a write; inspect, correct, and remove Sophia's notes; confirm provisional goals; return with a grounded briefing.
- Edit a page section directly, with Sophia unable to overwrite the edit unless the person lets her ([EDITING.md](EDITING.md), Phase 1; being built now).
- Keep chapters optional. Do not hold launch for automated chapter organization, guided reading, document ingestion, semantic search, or executable artifacts.
- Setup identifies the supported provider installation, sign-in, and billing route. Explain limits, expired login, cancellation, offline state, and recovery. Provider usage is billed directly to the person; never silently change the billing route.
- Local means storage and orchestration, not offline AI. Prompts and relevant notebook context go to the chosen provider, and research may contact the web. State this before the first request. Existing pages remain readable without a working provider connection.
- Let the person locate and copy/export a whole notebook and restore it on another installation. Test backups and recovery before advertising them. Cloud-folder placement is not a supported sync feature; concurrent multi-device editing is outside launch scope.
- Distribute a signed, notarized download with installation instructions, a support contact, and a simple manual update path that preserves notebooks. Use static hosting and hosted checkout; begin with manual purchase support rather than building an identity service or license server.

Proposed offer, owned by Justin: a one-time purchase for the current major version, with AI costs separate and future hosted services priced separately if introduced. Choose a price, evaluation period, refund terms, and update entitlement before the paid pilot. Do not promise lifetime inference, lifetime updates, or cloud sync. Actual purchases are the commercial evidence; interviews and free signups are supporting evidence.

### Provider decision before committing to onboarding

Prefer the existing Claude subscription route only if its exact paid-app arrangement is established as permitted. Anthropic's current [legal page](https://code.claude.com/docs/en/legal-and-compliance) both describes end-user sign-in to an unmodified Claude Code binary and restricts third-party apps routing subscription requests; the [SDK overview](https://code.claude.com/docs/en/agent-sdk/overview) also requires prior approval for third-party subscription access. Rechecked October 14, 2026. These sources do not establish Sophia's eligibility.

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

### Current evidence and next-work groups

Source inspection confirms SwiftUI code, local notebook/store checks, a subprocess-based Claude engine, stdio notebook tools, and a bundled Markdown/math reader. The spike README records a real model tool call and resume with Claude Code 2.1.299 / Node 26.0.0. Its billing attribution is inconclusive; delayed return, clean-Mac distribution, and paid demand remain unproven. The app README's reader and tool descriptions also need reconciliation with current code. Do not count an existing check executable as a passing check.

Organize next work into four projects: **Access and companion validation**, **Reliable local Mac beta**, **Paid launch and demand validation**, and **Later infrastructure — discovery only**. Keep the last project in backlog; sequence implementation around the first three. Each issue needs a concrete completion observation. Do not create duplicate feature-building issues for behavior already present in the prototype.

## 1. Requirements and product boundaries

The user's latest instructions take precedence over earlier proposals:

- Build a useful native Mac experience, then validate a small paid local release before investing in hosted infrastructure.
- Sophia combines teaching, thoughtful dialogue, and research. It should not turn every conversation into a lesson or examination.
- Organize a Library into Notebooks, optional Chapters, and Pages. Structure and pages develop through conversation.
- Each notebook is an emergent textbook. The person guides each step, and the book grows to their needs rather than following a curriculum Sophia generates in advance.
- Each notebook has Goals: what the person wants from it, in their words, with what reaching each goal would look like. Progress is shown as evidence from actual attempts and accepted pages, never as a score. Sophia may propose a goal or a refinement; the person accepts it and alone marks a goal met.
- What becomes a durable page is a negotiation between the person and Sophia. The person can also edit a page directly, a section at a time; the store keeps Sophia from overwriting those edits ([EDITING.md](EDITING.md)).
- Questions flow both ways. Sophia can challenge reasoning and examine understanding when useful, while the person directs the inquiry and challenges Sophia.
- Use Claude Code and/or Codex as the engine. Prefer existing user subscriptions where supported and permitted; API billing is an explicit alternative, not a silent fallback.
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

[SOPHIA.md](SOPHIA.md) is the initial explicit instruction artifact. It defines the companion's judgment, teaching, research, negotiation, tool boundaries, and return behavior. The first experiment must test its effective delivery and usefulness, not just the agent connection.

### A first inquiry

Start a Graph Clustering notebook with one question, such as why eigenvectors help partition a graph. Sophia explores the person's intuition, explains what is needed, examines a small example, and responds to challenges or misunderstandings. It can offer a prediction or application question where appropriate.

Either participant may suggest preserving a useful explanation or counterexample. Sophia writes and revises pages directly as the conversation calls for them, without writing ahead of the person's inquiry. The client records each write, shows the page beside the conversation, and offers undo. Only the person confirms goals or marks them met or dropped.

On return, Sophia gives a brief account grounded in saved evidence: the open question, last relevant idea or attempt, remaining uncertainty, and a useful next step. The person can correct that account or change direction. The next step may be reading a source, discussing an objection, trying an example, or answering a question.

The product hypothesis is that this companionship improves inquiry and makes returning useful. Its deciding observation is a delayed return: can Justin recover context without rereading the whole chat and make meaningful progress, whether through explanation, a fresh example, or a better-supported argument?

## 3. The next experiment

Historical experiment design: the prototype now uses the unmodified Claude CLI and stdio MCP directly (see app/README.md and spikes/claude-headless/README.md). Retain the pinned ACP alternatives below if the direct route has a demonstrated failure. An HTTP proposal experiment is not a remaining launch requirement; test actual `write_page` delivery and undo on the selected route.

### What has already been established

The supplied independent review reports successful no-prompt checks on this Mac: Claude authentication as `claude.ai`, Codex authentication as ChatGPT with a Pro plan, App Server `initialize`/`account/read`, and `initialize` plus `session/new` with both current adapter packages. These supersede the earlier restricted-environment failures for connection feasibility. They do not establish request billing, model-visible tools, companion quality, or commercial permission.

| Component | Pinned baseline | Status |
|---|---|---|
| Initial Claude adapter | `@agentclientprotocol/claude-agent-acp@0.90.0` | Reviewer reports clean session creation |
| Installed Claude Code | `2.1.299` | Version independently rechecked during this revision |
| Deferred Codex adapter | `@agentclientprotocol/codex-acp@2.2.2` | Reviewer reports clean session creation |
| Installed Codex CLI | `0.162.1` | Version independently rechecked during this revision |

Do not use deprecated `@zed-industries/codex-acp@0.16.0`. Pin published packages and retain the lockfile. Record the actual Node, adapter, SDK, and launched engine versions; a bundled binary may differ from the globally installed CLI. Adapter/package session results above are attributed to the review, not independently rerun here.

### Thin client and effective configuration

Use a disposable Node command-line ACP client before building SwiftUI or a custom terminal interpreter. Run one 20–30 minute graph-clustering inquiry. Use a disposable notebook and a harmless canary file outside it.

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

### Acceptance checks

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

If tool delivery fails, inspect the HTTP handshake and effective options. If ACP is the obstruction, try the Agent SDK directly with the same instructions, tools, and restrictions. This changes the connection, not subscription permission. If billing cannot be established, Justin decides whether to use explicit API billing for further testing or await clarification. Never silently fall back. If the companion is unhelpful, revise SOPHIA.md and try another focused exchange before native work.

## 4. Notebook tools, saving, and return

The current MCP tools are `read_page`, `write_page`, and `set_goal`. They accept notebook-scoped identifiers or content rather than arbitrary host paths. Page writes go through the store's checks and locking, are recorded, preserve one previous version, and are undoable. Tools cannot delete pages, remove the person's records, or confirm or complete goals. Only the person confirms a goal. DATA-MODEL.md governs current record and undo behavior.

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

[DATA-MODEL.md](DATA-MODEL.md) defines these files, the record shapes inside them, who may write each, and the checks the client applies. In brief: `notebook.json` holds chapters and page order; page frontmatter holds title and inspectable sources; `transcript.jsonl` holds the conversation, page writes, and undo records (plus legacy proposals); `learning.jsonl` holds goals, Sophia's notes on attempts, the person's takes and corrections, and return briefings, all in one record shape with a client-stamped author and links to evidence. The directory supplies the notebook name during the experiment. Keep one previous page version for undo. Do not require an examination record for a research-only discussion. Each page, and the notebook's Contents, has its own conversation thread. These threads are kept in the one transcript, each entry tagged with its page. The client requests a short checkpoint at session end, before a clear, and when a thread grows long. It records the checkpoint as Sophia's account, not an objective measure of the person. The checkpoint's notes are the only compaction: no summary is stored, and the person sees nothing of it.

Replace individual page files atomically. If a crash leaves an accepted page missing from the ordering, discover it on reopening. Defer cross-notebook IDs, a separate source catalog, multi-file transaction machinery, and format migrations until a real workflow needs them.

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

## 5. Native application after the experiment

The native prototype already exists. Before expanding it, run a useful first inquiry and return after approximately a week. Check the briefing, continue the inquiry, and correct a mistaken account through dialogue. The launch sequence above supersedes the original experiment-before-native ordering.

| Part | Direction and reason |
|---|---|
| Windows, outline, commands, composer | SwiftUI with AppKit where useful; native Mac interaction is the user's preference |
| Mathematical transcript and page reader | Markdown with LaTeX math (`$...$` inline, `$$...$$` display); the Mac app bundles markdown-it, its texmath extension, KaTeX, and DOMPurify in WebKit, with local fonts and no rendering network requests |
| Agent connection | The prototype launches the installed, unmodified Claude CLI with stdio MCP. Keep one connection; revisit ACP or SDK alternatives only for a demonstrated failure and a permitted access route |
| Artifacts | Separate restricted WebKit surface, introduced only when an actual inquiry benefits from one |
| Storage | The minimal local format from section 4, independent of provider sessions |

The book and the conversation are separate surfaces. Before a notebook has a page, the Contents conversation fills the window. Once it has one, selecting a page shows the page and that page's own conversation together. Selecting the Contents shows the notebook-level conversation. Chapters, Goals and Sophia's notes have no conversation of their own. A reply finishes in its own thread if the person moves to another page. The book can be hidden; a new page preserves that choice and the current selection. Its conversation card offers Open, which selects the page and opens the book. Serif type marks what is in the book; the conversation is set in the system face. Sophia saves pages and revisions directly (the person decided drafts added friction); the conversation points to each page written, and the person can undo it or ask for changes. The conversation also guides reading: it can walk through a page, stop to ask, and answer questions about a selected passage. [mock/index.html](mock/index.html) shows these flows.

**Unrecorded disk changes.** Hashes and orphan files cannot distinguish a crash-before-entry from outside edits. Index them with unknown provenance, preserve current and previous bytes, and offer inspection/manual restoration rather than destructive Undo. Normal recorded page writes and personal edits keep durable one-way Undo; automatic Undo of an unrecorded interrupted write is outside the current promise.

**Selection and focus.** Selecting a page selects its conversation, and the title above the composer names it ("1.3 The convolution theorem"; on Contents, "Fourier analysis · notebook conversation"). A write by Sophia never changes the selection or takes focus from the composer: her card in the conversation names the page and offers Open. Goals and Sophia's notes have no conversation of their own; opening them keeps the current conversation beside them, still named. A reply that finishes after the person has moved on marks its row until that conversation is next shown; nothing about it is stored.

**Return.** After six hours away, the notebook opens on Contents with the briefing and one link, "Continue on 1.3", to the unresolved exchange, whoever asked it, revealed even if it has been folded. If the person opens a page before reading the briefing, it shows once above the book until dismissed. An empty briefing shows nothing, and the notebook opens where it was.

**Fresh start.** "Start fresh on this page" (⇧⌘N; on Contents, "Start fresh in this notebook conversation") is offered between turns. While it runs, text in the composer is kept and the action is shown as under way. If it fails, the conversation is unchanged and the composer says "Couldn't start fresh. Your message hasn't been sent." The cleared conversation folds under "Earlier on this page" (Contents: "Earlier in this notebook conversation"); opening it reads it in place and changes nothing about where the next message goes.

**Reading history.** Date separators and loading older messages are reading affordances only; they never fold anything or start a new conversation. Only a fresh start folds history. A link to an older exchange reveals it and offers a way back. An empty conversation shows a plain composer for its page; nothing describes what Sophia has.

Preserve focus, selection/copy, scroll position, and return to writing. Test long streamed mathematics, accessibility, page writes and undo, failures, and restoration on the actual Mac interface.

Generated HTML/JavaScript can be proposed without executing it. Before running it, prove the viewer has no credentials, general desktop bridge, host file access, or unrestricted network access. Supply only explicit data and retain experiment parameters when accepted. Check a small graph experiment against a known example before relying on its output.

For the alpha, capability restriction replaces an operating-system sandbox project: no built-in shell/file tools and only scoped notebook handlers. This is not a claim of general host isolation. Use non-sensitive study material until the launch configuration passes its tests. Reconsider stronger isolation before enabling broader execution or sensitive material.

After repeated personal use, try the same product model for linear algebra, LLMs, historical sources, and parenting. Distinguish source findings, Sophia's interpretation, and personal observations. An assessment remains tentative; a citation should reveal what was actually inspected.

## 6. Access and commercial decisions start now

A subscription-backed paid custom client is not an assumed launch route. Resolve provider access in parallel with the personal experiment, before committing to that business model. The documented general third-party route is API billing; accepting that alternative remains Justin's decision.

Anthropic's legal page restricts third-party Claude.ai login and requests routed through subscription credentials on users' behalf. Its SDK overview allows previously approved arrangements. The same legal page describes hosting an unmodified binary with end-user authentication, but that does not establish approval for Sophia's custom ACP/SDK interface. Sophia has no such approval established. Personal experimentation is not explicitly classified in these sources; do not convert technical success into blanket permission. [S4]

OpenAI says App Server's existing authentication is not permitted for commercial or hosted services. Its Sign in with ChatGPT guidance directs paid applications to an interest process. The newer credentials can drive App Server, but compatibility with the selected adapter and commercial eligibility remain to be established; the ordinary adapter login does not prove support for that route. [S5, S6]

Zed demonstrates subscription-backed external agents. Its June 16, 2026 update also reports postponement of a proposed third-party billing change. These are useful dated precedents, not authorization for Sophia or a guarantee of future costs. [S7]

Founder-owned inquiry for each provider:

> Sophia is a locally running Mac research and learning notebook with a custom conversation interface over your unmodified agent through an ACP adapter. Users authenticate through your own flow and pay you directly; Sophia does not extract credentials or resell inference. What permission and registration are required for personal experimentation, an open-source release, and a paid local app? Is subscription-backed use available for this arrangement, or must product usage be API-billed?

No provider inquiry has been sent from this session. The supplied review does not authorize external messaging. Contacting sales or joining a waitlist is not itself approval.

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
