# Sophia local Mac pricing investigation

Decision memo · 26 October 2026 · USD unless stated otherwise

## Recommendation

**Test $49 per year or $6 per month for Sophia**, with the customer's Claude subscription billed separately. Treat this as a launch hypothesis, not demonstrated willingness to pay. It is enough above a basic editor to support ongoing work, below established knowledge workspaces, and a manageable incremental purchase for someone already paying for Claude. Do not price against future sync, collaboration, hosted inference, document ingestion, or a proven improvement in learning: none is established by this investigation.

The paid job is: **“Help me build understanding across visits, keep the useful explanations, and return to the question I was working on.”** Markdown ownership and local files support trust; they are weak standalone reasons to subscribe against free alternatives. The strongest reason to pay is less time rebuilding context and more productive return visits. Actual retention or learning improvement remains to be demonstrated.

If an annual/monthly subscription is mandatory, use the pair above. If packaging is still open, test it against **$59 once for the current major version**, with twelve months of updates and optional paid upgrades. The repository's current launch plan favors a one-time purchase. This memo proposes an experiment alongside that direction; it does not amend it.

## What is being priced

Source inspection used Sophia commit `1e3b67d` in an isolated worktree, reading [AGENTS.md](../AGENTS.md), [PLAN.md](../PLAN.md), [SOPHIA.md](../SOPHIA.md), [DATA-MODEL.md](../DATA-MODEL.md), [app/README.md](../app/README.md), and the Claude process implementation. Existing uncommitted product work was excluded. No app run, learner interview, purchase, or longitudinal learning study was performed for this memo.

The native Mac prototype already describes conversation beside a durable book; direct page writing and revision with undo; protected edits by the person; Markdown, mathematics, and music notation; provisional goals; correctable notes and working memory; confirmed links between notebooks; and a short return briefing. These are credible ingredients for a recurring learning workflow, not evidence that people will use it daily. The prompt's wise-teacher and research-companion behavior is intended behavior, not a measured outcome.

The tracked README still lists guided reading, permissioned web fetch, and distribution signing as unfinished. The launch plan defers Sophia-operated sync and inference, and requires backup/recovery, signed distribution, support, and clear provider setup. Storage and orchestration are local; AI requests send relevant context to Anthropic and research can contact the web. Avoid “fully private” or “offline AI” marketing. Price a personal Mac learning companion, not a complete replacement for a reference manager or research workspace.

## The separate Claude bill and launch dependency

[Anthropic's pricing page](https://claude.com/pricing) lists Pro at **$200 billed annually**, displayed as a rounded $17/month, or **$20 billed monthly**; Pro includes Claude Code and Projects. Max starts at $100/month. Taxes are additional and usage limits apply. Use the actual $200 charge in calculations, not $17 × 12. With Sophia, the entry annual stack would be **$249/year**; twelve months of both monthly plans would cost **$312**. An existing subscriber's incremental Sophia cost is $49 or $6/month, but a new subscriber sees the whole bill. Sophia cannot promise unlimited AI or additional Claude quota. (Accessed 26 October 2026.)

Commercial integration eligibility is unresolved. Anthropic's [legal and compliance page](https://code.claude.com/docs/en/legal-and-compliance) describes conditions for products running the unmodified Claude Code binary and end users signing in themselves. It also prohibits third-party developers routing subscription requests on users' behalf, restricts credential handling, and says embedded products must not restrict built-in authentication methods. The [Agent SDK overview](https://code.claude.com/docs/en/agent-sdk/overview) separately requires prior approval for third-party products offering Claude account login or subscription rate limits. Sophia launches the official CLI and intentionally rejects API billing; those facts alone do not establish permitted commercial use. Resolve the exact arrangement before taking money for the subscription-based integration. This is a product dependency, not a legal conclusion. No provider was contacted. (Both accessed 26 October 2026.)

If the supported route becomes BYO API instead, repeat the pricing test with an honestly estimated variable AI bill. That changes setup, perceived cost, and the eligible audience; it is not interchangeable with the stated subscription launch.

## Focused comparison

Prices below were checked against the linked official pages on **26 October 2026**. Annual equivalents are arithmetic, not monthly payment offers. Region, taxes, eligibility, and checkout can change the payable amount. A dash means not verified here, not unavailable. Eleven named products appear in ten rows; Notion's two tiers share one row.

| Comparator | Annual charge / annual-rate equivalent | Pay monthly | What the comparison means |
| --- | --- | --- | --- |
| [Obsidian](https://obsidian.md/pricing) | Local app free; Sync starts $48/year ($4/month) | Sync starts $5 | Local Markdown already costs $0; sync is a separate service Sophia does not supply. |
| [Bear Pro, developer announcement](https://blog.bear.app/2023/04/bear-2-will-have-a-new-price-only-for-new-customers/) and [current US listing](https://apps.apple.com/us/app/bear-markdown-notes/id1016366447?platform=watch) | $29.99/year ($2.50/month) | $2.99 | Mature native notes, iCloud sync, exports; 14-day trial. |
| [Ulysses](https://ulysses.app/pricing/) | $39.99/year ($3.33/month) | $5.99 | Established writing subscription across Apple devices with sync; useful lower anchor. |
| [Typora](https://typora.io/#purchase) | $14.99 once, excluding tax | — | Basic Markdown editing is inexpensive; 15-day trial and up to three devices. |
| [Craft Plus](https://www.craft.do/pricing) | Page shows $6.40/month alongside $8; $76.80 annualized advertised rate | Toggle-specific monthly charge not independently verified | Includes cross-device workspace features and 50 AI credits/month. Discount duration and renewal were not established; do not label $76.80 a verified ongoing renewal price. |
| [Capacities](https://capacities.io/about/facts), [plan details](https://capacities.io/pricing) | Pro $119.88/year ($9.99/month); Basic free | $11.99 | Basic already offers substantial notes and sync. Pro includes a light AI budget; regular AI use has an extra paid power-up. |
| [Workflowy](https://workflowy.com/pricing/) | $83.88/year ($6.99/month) | $8.99 | Pro removes node/upload limits; free tier and education access weaken a student price anchor. |
| [Notion](https://www.notion.com/pricing) | Plus $120/year ($10/month); Business $240/year ($20/month), USD official indexed view | User's $12/$24 claims not independently reproduced in official rendered view | Free has unlimited individual pages/blocks; eligible education users get one-member Plus free. Free/Plus AI is a trial; Business offers broader AI, with separately metered capabilities. |
| [Claude / Projects](https://claude.com/pricing) | Pro $200/year ($16.67/month), already required for the assumed route | $20 | Projects and general conversation are already in the customer's bill; Sophia must earn an additional purchase. |
| [NotebookLM / Gemini Notebook](https://support.google.com/gemininotebook/answer/16213268) and [Zotero](https://www.zotero.org/storage/) | Google Standard free; Zotero storage 300 MB free, 2 GB $20/year | — | Free source-oriented AI and a research library are strong complements/substitutes. Zotero storage fees purchase storage, not tutoring. |

The final row groups two research substitutes; neither is a direct feature-for-feature clone. Google's current help page calls NotebookLM “Gemini Notebook”; eligibility and quotas depend on plan. Compare what participants actually have, including institutional access.

Notion's opened page localized to EUR; its official search-indexed USD view supplied the annual rates. The monthly figures supplied by the user remain unconfirmed in this investigation, rather than being laundered through third-party aggregators. Craft's visible discount also needs checkout-level verification before using renewal economics. The narrower conclusion is robust: Sophia sits above commodity editors and below broad paid workspaces, while its most dangerous competition costs the target student **nothing extra**.

For the PhD audience, education prices are more relevant than some list prices. [Obsidian’s pricing FAQ](https://obsidian.md/pricing) offers eligible students and faculty 40% off Sync and Publish: basic annual Sync therefore computes to **$28.80/year** ($48 × 0.60). [Ulysses for Students](https://ulysses.app/en/students/) is **$10.99 per six months**, or $21.98 for two terms; this is an annual equivalent, not annual billing. It ends automatically and can be renewed while enrolled, subject to approval. These student anchors strengthen the need for Sophia to earn $49 through recurring learning value, rather than note editing or ownership alone. (Accessed 26 October 2026.)

## Packaging and alternatives

| Sophia hypothesis | Annual effective monthly | Twelve monthly payments | Annual saving vs twelve monthly payments | When to choose it |
| --- | ---: | ---: | ---: | --- |
| $39/year or $5/month | $3.25 | $60 | $21 / 35.0% | If $49 causes material student affordability loss while repeat usefulness is strong. |
| **$49/year or $6/month** | **$4.08** | **$72** | **$23 / 31.9%** | Starting offer; an accessible recurring companion without workspace pricing. |
| $59/year or $7/month | $4.92 | $84 | $25 / 29.8% | If retained users show paid demand and support costs exceed the $49 model. |
| $79/year or $9/month | $6.58 | $108 | $29 / 26.9% | Only after strong recurring value evidence or a broader paying audience. |

The recommended discount is relatively deep but keeps a monthly route for students who cannot commit $49 upfront or need Sophia for one research period. Six monthly payments cost $36; nine cost $54. Do not pressure intermittent users into annual billing with a fictional list price.

Offer a **30-day, no-card trial starting after the first successful model connection**, with the separate Claude bill disclosed before setup. A week rarely tests returning to an inquiry. Keep reading and exporting existing notebooks available after trial expiry or cancellation; retain local files. These are proposed entitlements, not implemented licensing behavior. Start with one paid tier; no permanent cloud-like free service or elaborate feature limits are needed to learn whether people pay.

For the first eligible student cohort, test **$39 for the first year, clearly renewing at $49**, alongside the standard offer. Allow a simple self-attested hardship extension; avoid collecting financial documents. Do not make a permanent student discount the default before learning whether price or weak value explains nonpurchase. Honor existing purchased periods, give advance renewal notices, and hold the pilot's stated renewal price for its first renewal. Avoid an indefinite lifetime price promise; any later changes should apply only prospectively with clear notice and easy cancellation.

A **$59 perpetual current-version license** better matches local-only ownership and the repository plan. Specify twelve months of updates, continued use of the last eligible version, and an optional major upgrade hypothesis of $29 after a meaningful release—not an annual upgrade obligation. Provider/OS changes mean continued AI compatibility cannot be promised indefinitely. Over three years $49 subscriptions total $147; a $59 license plus one $29 upgrade totals $88. Subscription revenue requires a credible continuing benefit; perpetual revenue requires new buyers and genuinely worthwhile upgrades. Test format preference and purchase behavior rather than assuming local-only customers accept recurring rent.

## Audience and transparent sensitivity model

The **500,000 US PhD students** estimate is not verified as an all-field enrollment count. The strongest directly checked official stock is **312,148 doctoral students in science, engineering, and health in fall 2024**, from the [NCSES GSS results](https://ncses.nsf.gov/pubs/nsf26308), covering research-based programs within its survey universe. It includes full- and part-time students and temporary visa holders at US institutions; it is not a US-citizens-only count. It omits fields outside that universe and is not an exact PhD-only national total. Do not infer the missing fields as a fixed percentage. (Accessed 26 October 2026.)

[NCES's postbaccalaureate enrollment indicator](https://nces.ed.gov/programs/coe/indicator/chb) reports 3.2 million in fall 2021, explicitly including master's and professional doctorates such as medicine, law, and dentistry. That is not the target. Annual research doctorate awards are a flow of graduates, not the stock of active learners. This investigation did not establish a current official all-field research-doctoral enrollment total; retain 500,000 only as an explicitly unverified expansion scenario. (Accessed 26 October 2026.)

At $49, 312,148 × $49 = **$15.30 million** of theoretical annual gross revenue at impossible 100% adoption of the checked field universe. The 500,000 scenario would be $24.5 million. Neither is a forecast or serviceable market estimate.

For planning, use the checked 312,148 base and show every unknown filter:

`eligible audience = base × compatible Mac share × suitable Claude access among Mac users × recurring inquiry / purchase fit`

| Illustrative scenario; all filters are assumptions | Mac share | Suitable Claude access | Recurring paid-job fit | Eligible audience, rounded | 5% penetration; annual gross at $49 |
| --- | ---: | ---: | ---: | ---: | ---: |
| Narrow | 25% | 5% | 20% | 780 | 39 buyers / $1,911 |
| Middle | 40% | 15% | 35% | 6,555 | 328 buyers / $16,072 |
| Broad | 60% | 30% | 50% | 28,093 | 1,405 buyers / $68,845 |

Revenue uses the standard $49 paid annual price, assumes no churn or refunds within that paid year, and excludes tax. A $39 first-year student cohort would produce 39/49 (79.6%) of these amounts: 328 buyers would pay $12,792, not $16,072. Monthly purchases must be modeled from actual paid months rather than treated as annual subscribers. Conditional shares are multiplied for illustration, not asserted independent population facts. “Suitable access” includes compatible plan, permitted integration, setup willingness, and institutional restrictions. Fit is a hypothesized pool, not observed conversion. Within the middle scenario, 1%/5%/10% penetration gives about 66/328/656 buyers and **$3,234/$16,072/$32,144** annual gross. This small initial niche may support a modest independent app; it does not establish a venture-scale business. The broader daily-learner audience is a later hypothesis.

BYO AI removes Sophia's direct inference bill, not maintenance, setup support, refunds, payment fees, signing/distribution, OS/CLI compatibility, or the founder's time. Illustratively—not a processor quote—5% plus $0.50 per transaction leaves $46.05 from a $49 annual purchase and $5.20 from a $6 monthly purchase. At an assumed $40/hour opportunity cost, twenty minutes of support costs $13.33, leaving $32.72 of annual contribution before fixed costs and other expenses. A $10,000 annual fixed budget would then need about 306 such annual customers. Replace these assumptions with actual checkout and support data; no CAC, LTV, churn, or profitability claim is available yet.

## Cheap tests and decision rules

1. **Find the right problem before optimizing price.** Recruit 15–20 US research doctoral students across fields, funding situations, existing tool stacks, and technical comfort. Record Mac compatibility, current Claude access, who pays, university reimbursement restrictions, and setup time. Ask them to show a recent abandoned/open inquiry. Do not assume stipends or lab budgets make the purchase easy. Interview participants receive the same compensation regardless of enthusiasm.
2. **Show disclosed hypothetical offers.** Randomly show comparable participants $39/$5, $49/$6, or $59/$7 with identical current capabilities and the full Claude cost; say no purchase is available yet. Ask what they would stop paying for and whether monthly cash flow or annual total blocks them. Include the $59 perpetual option in a separate format comparison so price and ownership effects are not confused. A small interview sample gives direction, not statistically reliable conversion estimates.
3. **Run a four-week real-use pilot before a price conclusion.** Pre-register a working threshold: at least 12 of 20 participants complete a real inquiry session, at least 8 return to the same inquiry on three distinct days spanning two weeks, and at least 6 can show a concrete benefit over their existing workflow. Preserve refusals and failures; count without product prompts coercing daily activity. These are product decision thresholds, not learning-effect evidence.
4. **Only after distribution and provider eligibility are settled, offer a real, clearly described purchase.** Among at least 20 activated pilot users, seek at least 5 purchases at the standard $49/$6 offer, with clear refund terms and no hidden auto-renewal. Disclose any cohort price experiment and honor the lower tested price for participants. Measure refunds, first-month return behavior, support minutes, and stated reasons for declining. No fake checkout, invented scarcity, or undisclosed card collection.

Stop expanding paid acquisition if fewer than 8 of 20 return, even if interviews praise Sophia. Repair the repeated-use experience first. If people return and show value but fewer than 5 buy, examine affordability, subscription resistance, setup, and the free alternatives before testing $39 or perpetual ownership. If setup/support overwhelms the contribution model, narrow the supported cohort or fix onboarding before increasing price. These deliberately small thresholds authorize another pilot, not a claim of market validation.

Raise the price only when paid cohorts show durable repeat use, limited refunds, affordable support, and value beyond Claude Projects. Lower it if real affordability blocks otherwise retained students. Change the business model if ownership preference dominates. Still missing: all-field enrollment, segment-specific Mac and Claude adoption, commercial integration eligibility, observed willingness to pay, repeat-use retention, learning outcomes, refunds, and real operating costs. The next useful evidence is a returned inquiry and an informed purchase—not a larger competitor catalog.
