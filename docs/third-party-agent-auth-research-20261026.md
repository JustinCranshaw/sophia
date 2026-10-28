# Sophia and third-party agent authentication

Research report on Claude Code subscriptions, Codex ChatGPT plans, and paid local distribution

**Research date:** October 26, 2026  
**Provenance:** Research-agent memo and two addenda supplied by Justin Cranshaw. Consolidated for the Sophia repository.  
**Status:** Research input, not a provider approval, legal opinion, or adopted architecture decision. The source pages, quotations, dates, pricing, and policy claims below have not been independently revalidated in this documentation pass.

## Executive assessment

The supplied research identifies user-owned API credentials as the best-documented commercial route for a paid local app. Whether Sophia may commercially rely on each user's Claude Pro/Max or ChatGPT subscription remains unresolved. A documented integration interface, a successful login, and subscription-attributed usage do not independently establish permission to distribute or market that integration.

For Claude Code, the reported legal text expressly contemplates third-party products running the unmodified binary with an end user's own credentials, including subscription credentials. It also requires Commercial Terms acceptance and prohibits restricting built-in authentication methods. Other Anthropic guidance directs commercial developers toward API keys and restricts third parties offering Claude login or subscription rate limits without approval. The memo identifies Sophia's subscription-only authentication guard as its clearest potential conflict with the former condition.

For Codex, the reported documentation supports embedding Codex and CLI-owned ChatGPT authentication. The Sign in with ChatGPT (SIWC) program separately requires paid-app applicants to request access and includes a no-charge condition. Whether those conditions apply to an app that merely launches the user's already-authenticated CLI is the central unresolved question.

The research recommends supporting user-owned API credentials and obtaining written provider confirmation before marketing subscription-plan use as a paid Sophia feature. Those recommendations are recorded here; **this report does not authorize changing authentication or billing routes, accepting terms, contacting providers, or adding a Codex integration.**

## Scope and evidence limits

The original researcher had no repository access. Its descriptions of Sophia's implementation came from the supplied architecture brief, not inspection of `PLAN.md`, `ClaudeEngine.swift`, `NotebookSession.swift`, or the running app. The draft inquiries also contain proposed pricing, audience, and runtime details that must be checked before use.

Keep four questions separate:

| Question | Evidence needed |
| --- | --- |
| Technical operation | The intended binary, interface, authentication flow, and tools actually work. |
| Billing attribution | Provider evidence establishes which account, allowance, credits, or billing route a request uses. |
| Commercial permission | Applicable terms or a provider agreement permit Sophia's specific distribution and product model. |
| Policy stability | The arrangement's change, notice, and enforcement conditions are understood. |

The memo reports source retrieval on October 26, 2026. Some quotations came from search snippets, social posts, or secondary reporting. These are weaker evidence than complete current primary documents. “Expressly permitted” and similar labels below describe the researcher's assessment, subject to its stated assumptions; they are not a fresh legal determination by Sophia.

## Part I — Claude Code

### The strongest supporting language

The researcher reports that Claude Code's [Legal and compliance](https://code.claude.com/docs/en/legal-and-compliance) page includes a section, “Can customers offer Claude Code in their products?” It says that preinstalling or running Claude Code in products or services requires agreement to the Commercial Terms and compliance with conditions, unless otherwise agreed.

Two reported conditions matter directly:

> The Claude Code binary must not be modified.

> Customers may not remove, disable, or restrict any authentication method built into it.

The section reportedly lists an end user's own Anthropic API key, Claude subscription credentials, or third-party inference-provider credentials as acceptable authentication. It also prohibits a customer paying for, reselling, or intermediating Claude usage on end users' behalf absent an agreement.

This is the strongest textual support for Sophia's local subprocess approach. It does not reportedly distinguish free from paid products. Its examples concern hosted sandboxes and agent infrastructure, however, rather than specifically addressing paid desktop applications.

### The countervailing language

The same legal page reportedly describes OAuth as supporting ordinary use of Claude Code and other native Anthropic applications, says developers building products “should use API key authentication,” and prohibits third parties offering their own Claude login or collecting, storing, or intermediating Claude credentials or session tokens.

It also reportedly preserves this exception:

> Nor does it prevent an end user from signing in to the unmodified Claude Code binary with their own Claude subscription.

The researcher's reconciliation is that CLI-owned sign-in to an unmodified binary is distinct from a third party handling subscription tokens or proxying inference. Sophia's described architecture fits the former mechanism. That does not settle the separate commercial-product and subscription-rate-limit language.

The [Agent SDK overview](https://code.claude.com/docs/en/agent-sdk/overview) reportedly says that, unless previously approved, third-party developers may not offer claude.ai login or rate limits for their products. Meanwhile, the [headless documentation](https://code.claude.com/docs/en/headless) calls `claude -p` “the Agent SDK via the CLI.” A source-code distinction between launching the CLI and importing an SDK therefore does not, on its own, resolve the policy question.

The memo also cites a February 18, 2026 statement by Claude Code staff member Thariq Shihipar encouraging local experimentation while directing people building a business on the Agent SDK toward API keys. This is historical, non-binding guidance; the supplied report did not include a direct post URL.

### Billing attribution and policy changes

The researcher reports that the [Claude-plan SDK help article](https://support.claude.com/en/articles/15036540-use-the-claude-agent-sdk-with-your-claude-plan) said on October 7, 2026 that the Agent SDK, `claude -p`, and third-party apps could still use subscription limits. A June 15 update reportedly paused a previously announced change “for now.”

This supports a claim about reported billing behavior at that date, not permission for commercial distribution or a guarantee of future attribution.

The memo contrasts that language with April 2026 announcements moving third-party harness usage toward extra usage, staff comments about subscription economics, and press reports of a spokesperson saying third-party subscription use was not permitted. It interprets the [login help article](https://support.claude.com/en/articles/13189465-log-in-to-your-claude-account) as retaining provider discretion to charge certain third-party tools against usage credits rather than subscription limits. Whether Sophia would be classified that way remains unknown.

### Authentication restrictions in the described Sophia build

The architecture supplied to the researcher described Sophia as removing API-key and alternate-provider variables from the child environment and refusing API-billed sessions. The memo views these safeguards as difficult to reconcile with the reported prohibition on restricting built-in authentication methods.

The [authentication documentation](https://code.claude.com/docs/en/authentication) reportedly identifies API keys, `apiKeyHelper`, OAuth, and cloud-provider credentials as built-in methods. In headless mode, an available API key reportedly takes precedence over subscription login.

The original recommendation was to replace unconditional restrictions with explicit user choice and a clear display of the active credential and metered-use implications. It also noted an unresolved detail: if choosing subscription mode causes Sophia to omit an existing API key, that user-directed omission might still require clarification under the restriction language.

### Addendum A — Removing the API-billing restriction

The follow-up asks whether removing API-key stripping and API-billing refusal would allow commercial distribution of a Claude Code wrapper.

Its answer is narrower than an approval: allowing the CLI to authenticate however the user configured it removes the clearest identified conflict, but does not resolve subscription use in a paid product. This assumes Sophia accepts the applicable Commercial Terms, runs the user's installed unmodified CLI, keeps login in Anthropic's own flow, and leaves built-in authentication methods available.

| User credential or mechanism | Addendum assessment |
| --- | --- |
| User's own Anthropic API key | Clearly supported commercial route under the cited terms. |
| User's own Bedrock, Vertex, or Foundry credentials | Supported by the cited third-party credential language, subject to applicable provider terms. |
| User's own Pro/Max subscription | Unresolved for a paid product; the legal carve-out and SDK guidance still need reconciliation. |
| Sophia's own Claude login or token handling | Prohibited by the cited credential-intermediation language. |

The addendum recommends warning before metered use rather than blocking it, and testing environment inheritance from both shell and Finder/Dock launches. A macOS GUI app may not inherit the user's shell variables; allowing an API key is not the same as establishing that the intended key reaches the process.

It recommends dropping the authentication-restriction question from an eventual provider inquiry if that restriction has actually been removed. Until then, the original question remains relevant. Neither addendum constitutes authorization to make that change.

### Runtime features and non-coding use

The memo treats headless mode, stream output, documented tool restrictions, custom prompts, and stdio MCP as supported capabilities that do not themselves modify the binary. It finds no coding-only restriction, while noting that learning-oriented use may raise questions about “ordinary” subscription usage.

It recommends appending to rather than replacing the system prompt as a lower-risk interpretation, not as a documented prohibition on replacement. It likewise recommends user-initiated turns and avoiding unattended subscription loops because of the reported Consumer Terms automation clause.

These are proposed changes or constraints to assess against Sophia's actual behavior. The report's assumptions about all turns being user-initiated, session resumption, and prompt configuration should not be copied into an inquiry as verified facts.

### Claude scenario assessment

| Scenario | Research assessment |
| --- | --- |
| Personal local `claude -p` experimentation | Supported by the cited billing and staff guidance. |
| Free/open-source app launching the user's unmodified CLI | Conditional textual support; not an express general commercial approval. |
| Paid Sophia with unconditional authentication restrictions | Unresolved, leaning against compliance on the authentication condition. |
| Paid Sophia with unrestricted user-owned authentication and Commercial Terms acceptance | Plausible under the legal-page text; subscription use remains unresolved. |
| Third-party login UI, token extraction, or credential proxy | Prohibited by the cited conditions. |
| Hosted use of subscription credentials | Not generally authorized; distinguish prohibited credential routing from the specific unmodified-binary hosted-platform conditions. |
| Sophia-funded or intermediated usage | Prohibited absent an agreement under the cited product conditions. |
| Commercial Agent SDK subscription login | Requires approval under the cited SDK notice. |
| User-owned API credentials in a paid app | The memo's clearest documented commercial route. |
| Bundling the Claude Code binary | Conditional and unresolved for desktop redistribution; avoid inferring redistribution rights solely from technical feasibility. |

### Integration choices and precedents

Launching the user's installed CLI is the memo's preferred subscription-compatible mechanism. Linking to the official installer and keeping sign-in in Anthropic's own flow avoids credential handling. Bundling adds redistribution and update obligations; the reported proprietary license reserves rights rather than supplying an open-source redistribution grant.

The researcher compares two products:

- **[Zed external agents](https://zed.dev/docs/ai/external-agents):** reportedly supports user choice between API-key and Claude Code authentication where available, with provider billing and terms remaining between the user and provider. Its adapter uses the Agent SDK. No public Anthropic approval was established, and its free external-agent hosting limits comparability.
- **[Conductor](https://conductor.build/docs):** reportedly bundles Claude Code, permits a system binary, and offers CLI authentication or API-key mode. Its paid tier reportedly charges for other product capabilities rather than model access. It warns about API-key precedence. This is a close architectural analogue, but its private agreements and general permission status are unknown.

Neither product's existence proves Sophia has permission. Their authentication-choice and billing-disclosure patterns are implementation references, not legal authorization.

### BYO API economics and credits

The memo reports new monthly API credits for eligible Max and Team subscribers: $100 for Max 5x, $200 for Max 20x, and up to $500 pooled for Team. It says Free, Pro, and Enterprise are excluded and new subscribers wait seven days. These are dated, unverified claims from the supplied research, not pricing promises Sophia should make.

The report flags a conflict between help-center language covering the SDK and `claude -p`, and [platform credit documentation](https://platform.claude.com/docs/en/about-claude/api-credits-for-subscribers) reportedly excluding Claude Code sessions. Whether an API-authenticated Sophia `claude -p` request receives these credits is unresolved. The memo suggests the SDK or Messages API as clearer covered interfaces, but entitlement must be verified before relying on that recommendation.

### Claude recommendations from the research

1. Support user-owned API credentials and accurately disclose the active route and metered use.
2. Resolve the authentication-restriction condition before distribution; changing it does not itself settle subscription permission.
3. Have the appropriate company representative review and accept applicable Commercial Terms if proceeding, and retain the record.
4. Keep login entirely in Anthropic's flow; do not access token stores or implement a Claude login proxy.
5. Prefer the user-installed binary for the initial release.
6. Assess prompt replacement, background behavior, and subscription marketing against written provider guidance.
7. Use “works with Claude Code” descriptively, subject to current branding rules; do not adopt provider marks as Sophia product or feature names.
8. Obtain written confirmation before making Pro/Max access a paid-product selling point.

The original memo assigns medium-low confidence to compliance as described, medium confidence to a modified architecture on the legal text, and low confidence to long-term stability without confirmation. These are qualitative researcher judgments, not measured probabilities.

## Part II — Codex and ChatGPT plans

### Central question

Addendum B distinguishes documented technical embedding from permission to offer ChatGPT-plan usage in a paid application. It identifies user-owned OpenAI API credentials as the clearest commercial path. The unresolved question is whether SIWC terms apply when Sophia only launches the user's own authenticated Codex CLI rather than implementing OAuth itself.

The reported [SIWC documentation](https://developers.openai.com/siwc) makes plan usage self-serve for open-source/local apps while directing paid or remotely hosted apps to an interest form. The supplied research quotes a no-charge condition requiring users to be able to use their ChatGPT plan without paying the application developer or upgrading to a paid application tier.

The researcher could not retrieve the full SIWC Terms page and relied on official search snippets for several clauses. Complete current terms must be reviewed before treating an interpretation as settled.

### Governing layers

| Layer | Research finding | Implication |
| --- | --- | --- |
| Codex code license | Apache-2.0; the memo cites `@openai/codex` 0.164.0. | Code reuse and distribution rights do not grant service or subscription rights. Preserve required license/NOTICE material when distributing. |
| OpenAI Terms of Use | Reportedly prohibit account sharing, circumventing restrictions, and programmatic extraction. | The memo infers documented Codex interfaces are authorized programmatic use; it does not establish a blanket exception. |
| Service Terms | Reportedly incorporate SIWC Terms when a service uses SIWC. | Whether a CLI wrapper “uses SIWC” is central. |
| SIWC Terms | Reportedly require local requests, supported sign-in, user-controlled local token storage, no pooling/resale, connected-app use, and no charge for plan access. | A paid-only plan-usage feature may require a provider agreement or a different product model. |
| Codex integration docs | Reportedly invite embedding authentication, conversation history, approvals, and events via app-server. | Strong technical support, but no general paid-app exemption is established. |
| Account terms and billing | ChatGPT authentication uses the user's ChatGPT agreement and allowances; API authentication uses API billing. | The binary's open-source license does not determine billing or service permission. |

### Interfaces and authentication

The addendum describes `codex exec --json` and stdio `codex app-server` as candidate interfaces. It reports managed ChatGPT, device-code, and API-key authentication modes, and distinguishes these from the experimental host-owned-token mode `chatgptAuthTokens`.

For Sophia, the recommended boundary is CLI-owned authentication, a distinctive client identifier such as `sophia_notebook` where supported, and no reading or copying `~/.codex/auth.json`. The memo explicitly rejects impersonating another client, sharing accounts, or running a hosted inference relay against user plans.

It reports that `codex mcp-server` was removed and distinguishes that from connecting Sophia's own notebook tools **to** Codex through MCP. It also reports conflicting maturity signals: app-server is presented as an embedding interface, while a removal page calls it experimental and unsupported for production. Verify the current interface and support status before selecting it; this report does not resolve that discrepancy.

The report names `codex login status` and app-server account/login events as possible non-token sources of authentication-mode information. Their exact fields and billing meaning require implementation verification. Authentication metadata is not independent billing evidence.

### Codex scenario assessment

| Scenario | Research assessment |
| --- | --- |
| Personal CLI scripting or experimentation | Supported with high confidence through documented programmatic interfaces. |
| Free/open-source local application | Supported under the reported SIWC path, subject to full terms and exact eligibility. |
| Paid local app using the user's ChatGPT login | Unresolved; may require SIWC approval or a provider agreement. |
| Paid app using the user's own API key | Best-documented commercial path under applicable API terms. |
| Bundling or modifying Codex | Allowed at the code-license layer with obligations; does not settle service access or permit impersonation. |
| Sophia-managed SIWC OAuth | A separate integration requiring the applicable registration/approval and token-handling obligations; not the proposed CLI-owned-login boundary. |
| Hosted relay, pooling, or resale of plan usage | Prohibited by the cited SIWC restrictions. |
| Reading or copying CLI authentication tokens | Rejected as unsupported and inconsistent with the intended security boundary. |

The addendum suggests that a free Sophia tier offering plan use might satisfy the no-charge condition. **That is a proposed interpretation to confirm, not proof that a free tier resolves all registration or approval requirements.**

### Official paths, partners, and approval

The addendum reports a [SIWC client-ID request page](https://developers.openai.com/siwc/request-client-id) and an [interest form](https://openai.com/form/sign-in-with-chatgpt-interest/) for commercial partners. It also describes an enterprise app-server known-clients list, but does not establish a registration procedure or response time.

It cites paid partner integrations, including Conductor, Warp, and Devin, as evidence that commercial arrangements can exist. They are not evidence that the same permission applies to an unapproved application. Earlier staff encouragement to embed Codex, dated February–March 2026, reportedly predates the SIWC program's September 2026 terms.

The memo cites [openai/codex discussion 8338](https://github.com/openai/codex/discussions/8338) as containing unanswered paid-app questions and a staff statement distinguishing engineering guidance from legal advice. Recheck the thread and current provider documents before relying on that historical state.

### Billing and background use

The research reports that ChatGPT-authenticated Codex draws from a shared allowance with other OpenAI work surfaces, while API credentials use per-token API billing. It also describes per-app SIWC usage caps and user-controlled credit use. These are dated account/program claims requiring current verification; Sophia should not promise a separate quota or guaranteed included usage.

The addendum recommends user-started turns and express consent for background work. It suggests API credentials for unattended activity. Custom instructions and MCP are described as documented capabilities, and no coding-only use restriction was found. That absence is not a guarantee that future model or product behavior will remain well suited to learning workflows.

Historical claims in the report include the 2025 introduction of ChatGPT login and credits for Codex, a February 2026 app-server announcement, August 2026 allowance/model changes, and the reported September 29 SIWC launch. Pro-tier changes and partner details were partly secondary reporting. None should be used as current product pricing or entitlement copy without checking primary sources.

### Proposed minimal Codex integration

The addendum proposes, rather than authorizes:

1. Detect the user's installed CLI and link to its official installation instructions if absent.
2. Use a documented local interface with a truthful Sophia client identity.
3. Let Codex own authentication; do not read token files or introduce host-owned tokens.
4. Use API credentials as the paid product's documented route unless plan usage receives the necessary confirmation.
5. Give the process scoped Sophia instructions and notebook tools; surface required approvals and verify effective tool/sandbox limits.
6. Require consent for background activity and avoid remote credential relays or pooled usage.
7. Pin or test the actual runtime and protocol used rather than assuming an installed CLI matches a separate adapter's engine.

The addendum's “roughly 50/50” statement about SIWC applicability is a subjective expression of uncertainty, not a quantified legal probability. Its practical conclusion is to seek confirmation before marketing paid ChatGPT-plan access.

## Cross-provider conclusions

| Question | Claude Code | Codex |
| --- | --- | --- |
| Strongest support for subscription use | Reported explicit unmodified-binary/end-user-subscription carve-out. | Documented embedding and managed ChatGPT login, plus a dedicated SIWC program. |
| Principal uncertainty | Product authentication conditions versus SDK/login/rate-limit restrictions. | Whether SIWC paid-app approval and no-charge terms govern CLI wrappers. |
| Code license | Reportedly proprietary. | Apache-2.0, separate from service rights. |
| Commercial API route | User-owned API or supported provider credentials. | User-owned API credentials. |
| Approval route identified | Prior approval/contact-sales language; no general application form established by the researcher. | Reported SIWC interest form/waitlist; enterprise known-client process unclear. |
| Precedents | Zed and Conductor; agreements unknown. | Published partner integrations; agreements do not establish general permission. |

The research converges on API credentials as the better-documented commercial option and provider clarification before paid subscription marketing. It does **not** prove that both providers categorically require approval for every local CLI wrapper. That broader conclusion would exceed the unresolved applicability questions the report itself identifies.

## Decisions and follow-up work

| Item | Status from this report |
| --- | --- |
| Change Sophia's existing authentication guard | Recommendation received; no implementation decision made here. |
| Add API-key/cloud-provider support | Proposed engineering work; requires explicit scope and protection against surprise billing. |
| Add Codex integration | Proposed future work, not an existing verified capability. |
| Accept commercial terms | Requires authorized human/company action. |
| Contact either provider or submit interest forms | Drafts only; not sent. |
| Promise plan limits, credit eligibility, or specific costs | Not supported without current source and account verification. |
| Market paid subscription access | Research recommends written confirmation first. |
| Claim legal compliance | Not established by this report. |

Before a decision, verify the current complete primary documents, inspect Sophia's actual process/authentication/background behavior, reconcile contradictions, and separate commercial review from technical tests. Do not remove the existing surprise-billing protection merely because the supplied report recommends a different architecture.

## Source register

Dates in this table are **reported by the researcher**, not independently checked here. A link is a source locator, not a claim that its present contents were inspected in this documentation pass.

### Anthropic and comparison products

| Source | Reported version or retrieval information |
| --- | --- |
| [Claude Code legal and compliance](https://code.claude.com/docs/en/legal-and-compliance) | No displayed version date; retrieved October 26, 2026. Date of product-hosting language unknown. |
| [Consumer Terms](https://www.anthropic.com/legal/consumer-terms) | Effective October 8, 2025. |
| [Commercial Terms](https://www.anthropic.com/legal/commercial-terms) | Effective June 17, 2025. |
| [Agent SDK overview](https://code.claude.com/docs/en/agent-sdk/overview) | Undated; retrieved October 26, 2026. |
| [Authentication](https://code.claude.com/docs/en/authentication) | Reportedly referenced CLI 2.1.290. |
| [Headless operation](https://code.claude.com/docs/en/headless) | Reportedly referenced CLI 2.1.295. |
| [Use the Agent SDK with a Claude plan](https://support.claude.com/en/articles/15036540-use-the-claude-agent-sdk-with-your-claude-plan) | Reported June 15 and October 7, 2026 updates. |
| [Log in to a Claude account](https://support.claude.com/en/articles/13189465-log-in-to-your-claude-account) | Undated; reported recently updated. |
| [API credits for subscribers](https://platform.claude.com/docs/en/about-claude/api-credits-for-subscribers) | Program reportedly launched October 7, 2026. |
| Claude Code `LICENSE.md`, anthropics/claude-code | Search snippet only in the original research; no exact file URL supplied. |
| [Zed external agents](https://zed.dev/docs/ai/external-agents) | Retrieved October 26, 2026. |
| [Conductor documentation](https://conductor.build/docs) and [pricing](https://conductor.build/pricing) | Search/retrieval October 26, 2026; private agreements unknown. |

Historical staff posts and press references include Thariq Shihipar, Boris Cherny, The Register, TechCrunch, Hacker News, and The New Stack. Exact source URLs were not supplied for these items. The brief also mentions an April 2026 Pro-pricing experiment reportedly affecting about 2% of new signups; it is historical context, not a current eligibility conclusion.

### OpenAI

| Source | Reported version or limitation |
| --- | --- |
| OpenAI Terms of Use | Effective January 1, 2026; exact source URL omitted from supplied addendum. |
| OpenAI Service Terms | Updated October 16, 2026 according to a research subagent; exact source URL omitted. |
| Sign in with ChatGPT Terms | Full fetch blocked; quotations partly from official search snippets; effective date not established. |
| [SIWC documentation](https://developers.openai.com/siwc) | Undated current pages in the research; reported September 29, 2026 program launch. |
| [Request a SIWC client ID](https://developers.openai.com/siwc/request-client-id) | Reported commercial-partner waitlist. |
| [SIWC interest form](https://openai.com/form/sign-in-with-chatgpt-interest/) | Form URL partly secondhand in the supplied research. |
| [Codex app-server documentation](https://learn.chatgpt.com/docs/app-server) | Embedding/authentication documentation as cited by the researcher. |
| Codex non-interactive, SDK, and MCP-server-removal documentation | Exact URLs not supplied; maturity claims require reconciliation. |
| Using Codex with a ChatGPT plan, help center | Exact URL omitted; some automated fetches blocked. |
| [Codex repository](https://github.com/openai/codex) and [discussion 8338](https://github.com/openai/codex/discussions/8338) | Apache-2.0 and historical integration discussion cited. |

OpenAI staff posts, partner lists, Pro-tier changes, and reports from Startup Fortune, TechCrunch, Neowin, and The Next Web were partly secondary or lacked direct URLs in the supplied text. Preserve that distinction when following up.

## Appendix A — Draft inquiry to Anthropic

**Not sent.** Confirm the actual architecture, audience, pricing, company authority, and intended authentication behavior before using this draft. The supplied original described $49/year or $6/month pricing, PhD students, `--resume`, no Agent SDK/ACP, and a commitment to accept terms; these are not established by this report.

**Subject:** Permitted authentication for a paid local Mac app that runs the unmodified Claude Code CLI

We are building Sophia, a local macOS research and learning notebook intended for paid distribution. Notebook files are local; relevant context is sent to the provider for inference. We seek clarification before committing to a commercial subscription-based integration.

Our intended integration launches the user's installed, unmodified Claude Code binary as a local subprocess, uses documented headless interfaces and notebook tools through local stdio MCP, and renders responses in Sophia. Sign-in remains in Anthropic's own flow. Sophia would not collect tokens, proxy inference, share accounts, or pay for end users' usage.

Please confirm the following for the exact configuration we provide:

1. May a paid, locally distributed app run the user's installed binary with the user's own Pro/Max login? Does the Agent SDK notice about third-party login or rate limits also govern this `claude -p` pattern? If approval is required, what process applies?
2. If Sophia offers an explicit billing-mode choice, may a user choosing subscription mode direct Sophia to omit an API key from that child process? Does that count as restricting a built-in authentication method? Must every built-in method remain selectable? **Omit this question only if the actual proposed implementation no longer restricts authentication.**
3. Is Sophia a third-party tool or harness whose requests may be drawn from usage credits rather than subscription limits? What notice, if any, is given before reclassification?
4. Do eligible subscribers' API credits apply to `claude -p` requests authenticated with a key from the linked Console organization?
5. Are there constraints on non-coding research/learning use, full system-prompt replacement versus appending, or explicitly opted-in background work?
6. Which terms and any additional approval must Sophia's company complete before distribution?

We would appreciate written confirmation of the permitted configuration. We can provide the actual process arguments, authentication-mode behavior, and activity triggers without sharing credentials.

## Appendix B — Draft inquiry to OpenAI

**Not sent.** This concerns a proposed Codex integration, not a capability established by the current Sophia implementation. Confirm the proposed paid/free structure and runtime before submission.

**Subject:** Paid local Mac app launching the user's own Codex CLI — is SIWC approval required?

Sophia is a local macOS research and learning notebook intended for paid distribution. We are considering the user's installed Codex CLI as a local subprocess, using a supported interface such as stdio app-server or `codex exec --json`, with a truthful Sophia client identifier where supported.

Authentication would remain CLI-owned. Sophia would not read or store authentication tokens, operate an inference relay, pool usage, share accounts, or pay for users' inference. Notebook operations would be exposed through local stdio MCP. We will describe any background activity explicitly rather than assuming it is covered by user-initiated use.

1. Do the SIWC Terms, including the no-charge condition, apply when Sophia launches the user's CLI and does not implement OAuth itself?
2. If they apply, can a paid app offer ChatGPT-plan usage by agreement, and is the SIWC interest form the correct process? Would offering that mode in a free tier satisfy the relevant conditions, or would separate registration/approval still be required?
3. Is non-coding research, learning, and notebook use acceptable under a ChatGPT-authenticated Codex integration?
4. How should Sophia register its client identifier or join the known-clients list, if required?
5. Which documented interface is supported for a production desktop integration, given the reported experimental app-server language?
6. What consent and billing requirements apply to explicitly opted-in background work?

We would appreciate written confirmation of the applicable terms and supported integration path before advertising ChatGPT-plan usage.

---

This report preserves the supplied research's central findings, uncertainty, and recommendations in consolidated form. It is not legal advice or evidence of provider permission, and no inquiry has been sent.
