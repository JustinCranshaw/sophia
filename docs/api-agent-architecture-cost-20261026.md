# Sophia API agent architecture and cost plan

26 October 2026 · USD · Decision proposal, not an implementation commitment

## Purpose and recommendation

Build toward a Sophia-owned, model-independent agent experience without delaying validation of the current Mac app. Investigate the API route in parallel; do not replace the working CLI route or commission a full backend before measuring the smaller alternative.

**The recommended first investment is a bounded 1–2 person-week, one-provider local API spike.** A dependable one-provider beta is provisionally 4–8 person-weeks total, including that spike. A second provider adds 1–3. A managed service that pays for inference adds 4–8 more: approximately **9–19 person-weeks for two-provider local orchestration plus managed access**, before the common launch work. These are engineering estimates, not quotes or calendar promises.

The agent loop can remain on the Mac. Owning it does not require cloud notebooks, sync, remote tool execution, or always-on jobs. Sophia needs a backend when it holds a company API key and funds users' requests, not merely because it coordinates model calls and tools. A small gateway can provide that paid access while notebook files and execution remain local.

## Scope and constraints

This plan costs three practical options and a deferred fourth. It authorizes no implementation, deployment, paid API experiment, new credential route, terms acceptance, provider contact, or billing purchase. Justin owns those commitments. The user's latest request authorizes evaluating a dedicated API experience alongside the current launch; it does not require adopting the older PLAN.md prohibition on infrastructure discovery as a design constraint.

Preserve:

- The native app, local notebook files, page-scoped conversations, explicit goals, and useful conversations that need not produce a page.
- Checked writes, protected personal edits, durable Undo, evidence distinct from interpretation, and confirmed cross-notebook access.
- Source-opening permission before retrieval, truthful search/source evidence, cancellation, interrupted-question recovery, and readable notebooks when inference is unavailable.
- Almanac's explicit opt-in, narrow title/topic inputs, app-open preparation, and durable save before notification. No new closed-app scheduling promise.
- Explicit provider and billing choices. Never silently change provider, send notebook context to another provider, or switch billing routes on failure.

Exclude accounts from the local BYO-key option. Exclude cloud notebook storage, sync, collaboration, arbitrary shell/code execution, a generic workflow engine, automatic model routing, vector search infrastructure, and remote autonomous agents from the initial API plan.

## Evidence used

Repository inspection used clean commit `c8b70367582f857111bfe2972f8f17d4ecb022ef`. No product model calls or billing measurements were run for this estimate.

| Existing component | Reuse and replacement boundary |
| --- | --- |
| `app/Sources/SophiaCore/NotebookStore.swift`, `LibraryStore.swift`, DATA-MODEL.md and EDITING.md | Reuse checks, locking, revision/Undo and evidence rules. Do not replace storage to change providers. |
| `app/Sources/sophia-mcp/main.swift` | Reuse notebook tool schemas and checked operations. Existing executable exposes list/call entry points; start by reusing local stdio, not a second implementation of each tool. |
| `app/Sources/Sophia/NotebookSession.swift` | Reuse thread routing, queued questions, checkpoints, briefings and UI behavior. It directly depends on ClaudeEngine, so integration is more than swapping an HTTP URL. |
| `app/Sources/SophiaCore/ClaudeEngine.swift` | Replace CLI stream interpretation, provider-owned tool loop, and CLI WebSearch/WebFetch behavior for the API route. Its result handling does not currently expose token/cost accounting. |
| `app/Sources/SophiaCore/SourcePermission.swift` | Preserve active-thread approval and source evidence; the new transport must not bypass them. |
| `app/Sources/Sophia/AlmanacPreparation.swift` | Reuse reserved run identity, stale-configuration checks and result reconciliation instead of introducing a job service. |

`NotebookStore.writePage` does not by itself deduplicate a retried tool call. Current write→transcript→metadata ordering is not proof of exactly-once execution after a crash. The spike must settle recovery before promising automatic resume.

The [pricing investigation](pricing-strategy-20261026.md) proposes $49/year or $6/month for the app **with separately paid AI**, not included inference. Its market and willingness-to-pay assumptions remain unvalidated. The [provider-authentication report](third-party-agent-auth-research-20261026.md) preserves supplied research, not provider approval. API services have their own terms and data obligations; this plan is not a legal determination.

Official sources were checked on October 26, 2026. Anthropic documents application-executed tools as a request→execute→return-result loop, distinct from provider-executed tools. This supports local orchestration but does not remove Sophia's validation and recovery duties. [Tool-use documentation](https://platform.claude.com/docs/en/agents-and-tools/tool-use/how-tool-use-works).

## Options and engineering cost

| Option | Where the loop and files live | Who pays inference | Incremental engineering estimate | Principal ongoing obligation |
| --- | --- | --- | --- | --- |
| Existing CLI | Mac; provider owns the internal agent loop | User's provider account | No new harness work; existing release backlog remains | CLI compatibility, setup support, provider eligibility |
| Local API, one provider | Mac; Sophia owns loop, tools and context | User's API account | 4–8 person-weeks total | Credentials UX, provider changes, reasoning/tool correctness, local cost disclosure |
| Local API, two providers | Same | User's API account | +1–3; 5–11 total | Second adapter and separate behavior/quality verification |
| Local loop plus managed API gateway | Files/tools/loop on Mac; requests pass through Sophia | Sophia pays provider, customer pays Sophia | +4–8; 9–19 total with two providers | Identity, entitlements, spend accounting, abuse, payments, incidents and support |
| Server-owned agent | Remote loop; local notebook tools need an additional connection | Usually Sophia | Rough +4–8 beyond managed option, low confidence | Remote state, reconnects, consent, local-file availability, retention and job recovery |

One person-week means 40 focused engineering hours. With one dedicated engineer, person-weeks roughly translate to working weeks before external waits. Agent-assisted implementation may reduce some coding time; no measured multiplier supports shortening this estimate. Splitting the same founder across two tracks slows both. A separate bounded spike can proceed in parallel; a full rewrite cannot be treated as free parallel capacity.

At an **assumed** loaded rate of $100–175/hour, a person-week costs $4,000–7,000. One-provider local beta is $16,000–56,000 of engineering value; the additional managed layer is another $16,000–56,000; the two-provider managed path is $36,000–133,000 total. Founder-built work may have little cash payroll cost but consumes that capacity. These ranges exclude common Mac release/notarization/support work, legal advice, human research, vendor approvals, tax advice and acquisition spending.

The 4–8 local weeks comprise four 1–2-week allowances: (1) vertical spike and measurements; (2) stream/tool loop and existing UI integration; (3) source/context/recovery safety; (4) capability, security, cost and regression verification. The managed increment similarly allows 1–2 weeks each for identity/checkout, atomic usage accounting, constrained streaming/security, and payment reconciliation/operating checks. These are rough work packages, not independent guaranteed schedules.

## Proposed local design

The native session supplies Sophia instructions, selected thread context and permitted tools to a small provider adapter. The adapter streams text and structured tool requests. A Sophia-owned loop validates each complete request, sends allowed notebook operations to the existing local tool server, and returns the result to the model until it answers, refuses, stops, or reaches the explicit budget/iteration limit.

Keep Swift and the existing local executable boundary initially. Do not add a JavaScript runtime or generic agent framework solely to obtain a while-loop. A provider SDK is worth adopting only if the spike shows it substantially reduces stream/tool correctness work without defeating scope, cancellation, or packaging requirements.

One provider works first. Prove model independence by implementing a second adapter against the same fixtures, not by exposing an unrestricted model menu. Preserve provider-specific request/result data needed for continuing a turn; normalize only the events the app consumes. A shared tool schema does not imply equal citation, reasoning, prompt, or safety behavior. Provider selection occurs at a clean turn boundary, explicitly; no automatic fallback or implicit transfer of context.

Store user-owned API credentials in the Mac's secure credential store and expose replace/remove controls. Never bundle Sophia's company secret in the app. Managed API access must keep that secret on the server; official OpenAI guidance warns against exposing API keys in distributed client code. [API authentication guidance](https://developers.openai.com/api/reference/overview). BYO-key security and platform guidance still need validation for the selected provider; do not extract existing CLI subscription credentials.

Search is real replacement work. API-native search may supply candidates, but a provider capability that retrieves full sources before Sophia can obtain permission does not meet the existing source-opening contract. The current source-permission bridge is not a hardened local HTTP fetcher. The spike must prove a suitable provider tool configuration or cost and test a Sophia-controlled fetch: permission before retrieval, reject local/private-network targets and unsafe redirects, bound response size/time, send no ambient cookies/credentials, and retain source metadata. If neither path passes, report source parity unavailable rather than silently broadening access. Do not label a search snippet as an inspected source. No remote browser or arbitrary code-execution service is needed for this scope.

## Why the retained parts are needed

| Part | Present need and least-complex adequate boundary | Cost accepted |
| --- | --- | --- |
| Local tool loop and narrow adapter | Replaces work the CLI performs while preserving native/store contracts. A raw completion request cannot execute tools safely or continue their results. | Stream parsing, provider stop semantics, tool scheduling and conformance tests. |
| Existing stdio notebook tools | Preserves one checked mutation boundary; rewriting handlers would duplicate policy. Extract into Core only if a measured packaging/performance obstacle appears. | One existing child process and explicit lifecycle. |
| Stable turn/tool identity and recovery state | A lost response must not cause a second write. Reuse the transcript where feasible; distinguish known completion from uncertainty. Filename existence alone is insufficient. | Minimal durable call/result state or explicit refusal to resume ambiguous mutations; schema chosen after crash test. |
| Context and source handling | Repeated visits, long threads, restricted notebook access and truthful citations are current product requirements. | Bounded context selection, checkpoints and provider-specific evidence handling; no vector database. |
| Usage and request limits | Prevent runaway loops and make a metered connection understandable. Existing CLI metadata is not a cost ledger. | Record actual input/cache/output/tool usage, bounded outputs/steps, and estimated versus provider-confirmed charges separately. |

On failure, keep received text labeled partial. Execute no incomplete streamed tool call. Cancel requests and pending approvals, ignore late results after cancellation, and prevent new steps. Cancellation can stop future work without guaranteeing that already-started inference is free. Persist confirmed tool results; return them for known repeated call IDs. Do not replay an uncertain write automatically. Recovery must inspect durable records or ask the person to retry with that uncertainty made explicit.

## Conditional managed design

If managed access is chosen later, route each local model request through **one authenticated streaming service with one transactional account/usage store**. A payment provider handles checkout; Sophia receives signed events to update entitlements. Files and notebook tools remain on the Mac. Prompts and replies transit the gateway, so local storage does not mean Sophia never handles content.

The gateway validates the account, allowed model/tools, request size, bounded output and maximum funded exposure before forwarding. Atomically reserve enough allowance for each request, including capped metered tools; reconcile with provider-reported usage. Two concurrent requests must not both spend the same balance. Use server-observed costs and a versioned price table, not client-supplied totals. Bound concurrency per account and globally, protect secrets, and supply an operator stop switch.

This account store is needed because Sophia pays a real bill. A client-side limit is bypassable; a stateless proxy is insufficient. Keep uncertain spend reserved after a disconnect until provider evidence or a documented reconciliation rule resolves it. Deduplicate payment events and request IDs, reconcile refunds/chargebacks, and explain charges that outlive a lost response. No queues or separate microservices are justified initially; reconciliation can use one bounded scheduled task if the spike establishes that need.

Retain operational metrics, request IDs, usage records, account state and diagnostic categories. Do not retain raw notebooks/prompts in logs by default. Set retention/deletion rules, deployment rollback, backup/restore for the billing store, incident ownership and provider-spend alerts before a paid pilot. Contractually review this exact API-funded service rather than assuming Claude Code hosting restrictions are the terms for direct API use.

## Inference cost model

These are **illustrative workloads, not measured Sophia usage or quality-equivalent model benchmarks**. Count tokens across every request in a session: repeated context, tool results, source text, checkpoint/briefing work and billable reasoning/output. Context length once is not session input volume.

Current standard rate anchors, per million tokens:

| Model | Uncached input | Output | Cache-read input |
| --- | ---: | ---: | ---: |
| Claude Sonnet 5.5 | $2 | $10 | $0.10 |
| GPT-6.1 Sol | $2 | $10 | $0.10 |
| Claude Opus 5.5, premium sensitivity | $4 | $20 | $0.20 |

Claude web search is $0.01/search plus tokens; cache writes have separate charges. Rates are dated anchors, not locked procurement prices. [Anthropic pricing](https://platform.claude.com/docs/en/about-claude/pricing), [OpenAI model pricing](https://developers.openai.com/api/docs/models/gpt-6.1-sol). The scenarios below use the $2/$10 rate and Claude's search fee; do not assume another provider's search is identical. No caching, batch discount, free credits or negotiated rates are assumed.

`session tokens cost = (aggregate input × input rate + aggregate output × output rate) / 1,000,000`

| Monthly use assumption | Sessions | Input/output per session | Search calls per session | Tokens/month | Search/month | Total without Almanac |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Light | 8 | 40k / 8k | 2 | $1.28 | $0.16 | $1.44 |
| Regular | 20 | 200k / 20k | 4 | $12.00 | $0.80 | $12.80 |
| Heavy | 60 | 500k / 50k | 8 | $90.00 | $4.80 | $94.80 |

Separately, 30 optional Almanac entries at 25k input, 3k output and two searches each add **$3/month**. This assumes preparation on 30 days, not a new promise to run while the app is closed. With that increment and a **15% planning contingency**, the scenarios become **$5.11 / $18.17 / $112.47 per user-month**. The contingency is neither a hard cost cap nor measured retry overhead. Known retries/reasoning belong in actual usage totals; do not count them twice once measured.

At the premium $4/$20 token rate with unchanged search fees, the same totals are **$9.34 / $34.73 / $218.73**. Cheaper models may reduce these amounts, but only if the same companion/source/tool checks pass. Prompt caching may reduce repeated-input costs; write charges, eligibility and cache lifetimes prevent treating every repeated token as a free hit. Measure effective cost rather than budgeting an assumed cache percentage.

For an illustrative mix of 60% light, 35% regular and 5% heavy users, including daily Almanac and contingency, the average is **$15.05/month**. That is about **$1,505/month for 100 active users** or **$15,047 for 1,000**. This mix is not a forecast: a small heavy-user tail changes the answer dramatically. For local BYO keys these are users' bills; for managed access Sophia funds them.

## Backend bills, labor and pricing implications

The server bill is likely smaller than inference and engineering at pilot scale, but that is an assumption to test. Cloudflare's published Workers example has a $5 base charge; it is not a quote for an entire production service. [Workers pricing](https://developers.cloudflare.com/workers/platform/pricing/).

Use these **budget allowances**, not vendor quotes: $25–150/month at 100 managed active users and $100–500/month at 1,000 for a small gateway, account database, basic monitoring/backups and transactional communication. Load-test streaming duration/concurrency and price the selected services before commitment. These allowances exclude inference, payment/tax fees, support, legal work, security review and engineering labor.

Plan provisionally for 2–6 hours/week maintaining a local API route; managed access adds 4–12 hours/week for payment/usage issues, incidents and account support. These are capacity reserves, not measured utilization or a service-level guarantee; incident weeks can exceed them. At $100–175/hour and 4.33 weeks/month, the managed increment alone represents **$1,732–9,093/month** of time. This is why a cheap server is not a cheap service. CLI compatibility/support also consumes time; its current cost has not been measured.

For a US domestic-card illustration, Stripe lists 2.9% + $0.30 per transaction and Billing pay-as-you-go at 0.7% of billing volume. [Stripe pricing](https://stripe.com/pricing). Under that illustrative combination, $49/year leaves about **$3.91/month** and $6/month leaves **$5.48/month** before inference and other expenses. Different processors, taxes, international cards, refunds and merchant-of-record arrangements change this. These fees are not incremental only to AI; an app-only paid launch also has checkout costs.

An illustrative $20/month managed plan leaves $18.98 after those fees. The regular-use scenario with Almanac and contingency consumes $18.17 before hosting/support, leaving **$0.81**. For a 70% contribution target measured after payment fees and before fixed labor, all variable service costs would need to fit within **$5.69**. Neither $20 pricing nor that target is a recommendation; the calculation shows why the previous app-only price cannot simply include unlimited inference.

Test an app fee plus a plainly stated included usage allowance, with explicit purchase/consent for additional use, or keep BYO keys. Avoid promising unlimited premium-model work. Annual app licenses must not imply an uncapped future inference liability. Actual cost percentiles, support time and willingness to pay must determine packaging.

## Delivery sequence and decision gates

1. **Keep the current launch track intact.** Justin resolves its commercial route separately. This plan changes no authentication defaults or launch commitments.
2. **Approve a 1–2 person-week spike before implementation.** Use one provider, one named model and disposable material, with an explicitly approved API account and spend ceiling. Before the first paid request, validate the applicable service terms and data handling. Prove one complete inquiry with actual streaming, local tools, source denial/approval, checked writes, protected-edit refusal and Undo. Measure real usage and latency. No managed service is needed.
3. **Continue to the 4–8-week local beta only if the spike passes.** Exercise checkpoint/return and one opt-in Almanac path; capture repeated input, billed reasoning, searches, failed/aborted requests and context growth. Use at least 20 representative scripted sessions for engineering characterization, not human learning claims. Report each workload and observed range; a 20-session p95 is unstable and cannot justify an unlimited offer. Validate setup on a clean Mac before calling it user-ready.
4. **Prove the second provider in a separately budgeted 1–3 weeks.** Same tool contracts and source/quality cases, including provider-specific continuation behavior. If parity fails, retain one provider and record the missing capability; do not claim model independence from an interface declaration.
5. **Invest further when the product is working.** The decision is qualitative: are people finding Sophia useful, returning voluntarily, choosing to pay, and giving us reason to keep building? Consider revenue alongside their actual use, feedback, support burden and whether provider setup is holding back an otherwise useful product. There is no numerical revenue target, prescribed observation period or automatic investment trigger. Justin judges the evidence as a whole. Keep API discovery small while that becomes clearer; expand when the product shows promise and the next investment addresses a demonstrated need. Choose a practical scope and budget for that work at the time. Before managed access, still establish viable usage economics, an operating owner and provider/payment eligibility; these are implementation requirements, not a traction scorecard.
6. **Run a capped paid pilot before broad rollout.** Verify account isolation, parallel allowance reservation, duplicate webhooks, uncertain provider completion, refund/reconciliation, key rotation, restoration and cost alerts. Keep provider-spend exposure within an explicit funded ceiling. Human return/learning validation and clean-Mac release gates remain separate.

## Verification that changes the decision

The decisive end-to-end observation is a real API inquiry that uses a source and writes a page through existing checks, respects a person's edit, survives a controlled interruption without duplicating a mutation, and resumes with correct evidence and an explainable charge record. The test must include a valid outcome with no page write as well.

Inject cancellation before/after a tool result, malformed/incomplete arguments, a crash after a file write but before the completion record, a denied source request, a stale Almanac run, and provider rate-limit/timeout failures. Stop at known safe recovery when outcome is uncertain. Verify provider usage where available; metadata alone is not an invoice. Reading/exporting existing notebooks must remain possible with no key, exhausted allowance, or service outage.

Measure quality separately from cost: proportional help, accurate attribution, useful recovery, actual source inspection and preserved personal edits. A cheaper model that breaks these is not a successful optimization. Do not infer human mastery or delayed retention from scripted checks.

## Deferred until triggered

- **Server-owned orchestration:** revisit only after at least five retained users need useful work completed while the Mac/app is unavailable and the value warrants hosted context, consent and recovery. A daily notification alone does not justify it. Server execution cannot write an unavailable local notebook without another synchronization design.
- **Cloud notebook storage/sync:** separate requirement and conflict/recovery plan; not part of managed inference.
- **Automatic model routing:** add only when measured savings and quality evidence exceed the added failure/privacy/support cost; keep provider switches explicit until then.
- **Generic framework, queues, vector index and analytics warehouse:** defer until a measured workload cannot be served by the current local store, bounded loop and one service/database. No speculative scale allowance buys these now.

## Owners and remaining uncertainty

Justin owns the spend ceiling, staffing allocation, paid packaging, the judgment of whether the product is working, managed-access commitment and provider/legal approvals. Engineering owns the spike and measured compatibility/cost/recovery evidence. An identified service owner must accept incident response before Sophia funds customer inference. Revenue supports an investment decision; it does not establish provider permission or make an unprofitable inference package viable.

The largest unknowns are not request throughput: they are real tokens per useful session, source-tool parity, safe interruption semantics, quality across models, actual BYO setup abandonment, customer tolerance for metered use, and support time. The plan deliberately buys evidence for those questions before the larger backend commitment.
