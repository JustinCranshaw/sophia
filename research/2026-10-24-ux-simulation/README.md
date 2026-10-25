# Sophia native UX simulation — October 24, 2026

Four independent learner agents used the actual native Mac interface and its real Claude connection. They found useful teaching, editable durable pages, and persistent corrections, alongside failures in setup recovery, navigation, learning evidence, and source inspection. **Fifteen detailed Linear tickets were filed in the existing Sophia projects.** No product UX or companion-prompt fixes were applied during this study.

The four original agents were subsequently interviewed about what was easy to learn, what remained hard, and what would improve their next visit. Their [learner retrospectives](learner-feedback.md) preserve their specific learning takeaways, priorities and return intentions separately from the observed UI findings.

## Learners and observed paths

| Persona | Inquiry | Submissions | Observed path |
|---|---|---:|---|
| Elena Ruiz, 36, structural engineer returning to vibration analysis | Eigenvectors and vibration modes | 6 + 1 after return | Numerical explanation; challenge to phase terminology; actual restatement and amplitude prediction; personal page edit; correction of an inaccurate learner note; End session; return and building-motion application |
| Jamal Brooks, 52, library discussion coordinator | Emancipation, Reconstruction, citizenship, voting and enforcement | 6 + 1 after return | Source challenge; corrected memory preference; personal page edit; comparison table; concise follow-up; End session; return requesting two inspected passages |
| Theo Park, 24, self-taught guitarist | Counting staff/tab notation, held notes versus rests | 6 + 1 after return | Rendered staff/tab contrast; actual counting attempt; practice page; personal edit; fluency-note correction; temporary edit and Undo; End session; return to the still-unplayed practice task |
| Priya Shah, 47, museum educator and gardener, unfamiliar with Terminal | First-time setup, with soil fungi as her first question | 1 failed dependency submission + 2 live submissions | Empty Library; account/setup/menu search; notebook creation; missing-install error; relaunch with supplied existing connection; failed context recovery; retyped question receives actual answer |

There were 24 learner submissions: 23 went to a real model and one stopped at the missing-install branch. Session-end notes and briefings made additional real model requests. These counts describe submissions, not independent people or statistically independent observations.

## What worked

- Small examples supported visible reasoning: Elena distinguished a mode from a non-mode and tested amplitude scaling; Theo corrected his reading of a held note using the contrasting notation pictures. These are simulated attempts, not independently established human mastery or guitar performance.
- All three learning personas saved their own text through the native page editor. Their words survived later Sophia revisions and relaunch. Theo also saved and undid a temporary edit through the visible Undo action.
- Notes clearly distinguished the person's correction from Sophia's original interpretation. Corrected background/preferences persisted on return.
- Sophia accepted Jamal's challenge to “legally nobody,” revised the saved explanation, and separated source text from shorthand. After explicit challenge, Sophia also corrected Elena's phase terminology and its inaccurate account of her objection.
- Planned return briefings recovered the concrete unresolved thread. Theo's correctly retained “understood on screen, not yet played” boundary is particularly useful.
- After the existing signed-in dependency was supplied and Priya retyped her question, the app delivered an actual useful fungi explanation.

## Product iteration tickets

The 15 finding tickets are now nested under four implementation outcomes in the existing Sophia projects. Their detailed reproductions remain in the child issues. A fifth ticket covers scenario replay and a real delayed-return trial.

| Ticket | Outcome | Sequence |
|---|---|---|
| [SOP-33](https://linear.app/decomposer/issue/SOP-33/deliver-a-dependable-first-inquiry-and-connection-recovery) | Deliver a dependable first inquiry and connection recovery | Start first · Todo |
| [SOP-34](https://linear.app/decomposer/issue/SOP-34/keep-the-learning-conversation-focused-and-uninterrupted) | Keep the learning conversation focused and uninterrupted | Start first · Todo |
| [SOP-35](https://linear.app/decomposer/issue/SOP-35/make-goals-corrections-and-learning-evidence-trustworthy) | Make goals, corrections and learning evidence trustworthy | Next · Backlog |
| [SOP-36](https://linear.app/decomposer/issue/SOP-36/make-returning-lead-directly-to-a-grounded-next-action) | Make returning lead directly to a grounded next action | Next · Backlog |
| [SOP-37](https://linear.app/decomposer/issue/SOP-37/replay-the-four-learner-journeys-and-validate-a-meaningful-week-later) | Replay the four learner journeys and validate a meaningful week-later return | Blocked on all four outcomes |

Each outcome has a concrete completion observation and scoped child work. Original broader work links were retained as related issues when the finding tickets were reparented. No implementation or external participant outreach was performed by creating this plan.

## Linear findings

The issues contain reproduction steps, observed evidence, learning impact, proposed scope, acceptance criteria, and limits. Selected screenshots are attached directly in Linear. Existing projects were sufficient; no new project was needed.

### Sophia · Reliable local Mac beta

| Issue | Finding | Parent |
|---|---|---|
| [SOP-18](https://linear.app/decomposer/issue/SOP-18) | Empty book and fixed pane proportions crowd the first inquiry; hiding the book is overridden by a first write | SOP-34 |
| [SOP-19](https://linear.app/decomposer/issue/SOP-19) | Newly created notebooks omit Goals, notes and page navigation until relaunch | SOP-33 |
| [SOP-20](https://linear.app/decomposer/issue/SOP-20) | Inline goal confirmation hides the criteria being confirmed | SOP-35 |
| [SOP-22](https://linear.app/decomposer/issue/SOP-22) | A saved note/memory correction has no visible way to edit it again | SOP-35 |
| [SOP-23](https://linear.app/decomposer/issue/SOP-23) | A new page inherits another page's scroll, hiding its example and reminder | SOP-34 |
| [SOP-24](https://linear.app/decomposer/issue/SOP-24) | Evidence appears as raw record IDs instead of readable, navigable supporting material | SOP-35 |
| [SOP-26](https://linear.app/decomposer/issue/SOP-26) | Goals say “No attempts yet” during a session despite saved attempts; reads appear only after End session | SOP-35 |
| [SOP-29](https://linear.app/decomposer/issue/SOP-29) | Provider prerequisite is revealed only after the first question is submitted | SOP-33 |
| [SOP-30](https://linear.app/decomposer/issue/SOP-30) | No first-request explanation of accountless Sophia, provider sign-in, billing or data flow | SOP-33 |
| [SOP-31](https://linear.app/decomposer/issue/SOP-31) | Setup failure leaves an ordinary sent bubble without Retry; a fresh model session cannot recover the visible original question | SOP-33 |

### Sophia · Access and companion validation

| Issue | Finding | Parent |
|---|---|---|
| [SOP-21](https://linear.app/decomposer/issue/SOP-21) | Sophia's ambiguous phase explanation becomes an inaccurate “rusty point” in the learner's notes | SOP-35 |
| [SOP-25](https://linear.app/decomposer/issue/SOP-25) | Notebook housekeeping and filler replies interrupt short learning exchanges; arriving updates jump past material being reread | SOP-34 |
| [SOP-27](https://linear.app/decomposer/issue/SOP-27) | A page-revision turn leaves the actual kick question unanswered, requiring another learner turn | SOP-34 |
| [SOP-28](https://linear.app/decomposer/issue/SOP-28) | Return briefing identifies the next practice but cannot open its page/section as promised | SOP-36 |
| [SOP-32](https://linear.app/decomposer/issue/SOP-32) | Source-comparison offer ends in search summaries and recollection because Sophia cannot inspect the passages | SOP-36 |

Fix the broken first-question recovery and notebook navigation first. Then make learner evidence/corrections trustworthy and keep the inquiry central while records are updated. Source-reading and actionable return need real end-to-end follow-up before claiming those experiences work.

## First-time account and setup gaps

Sophia's plan intentionally requires no Sophia account. Missing sign-up is therefore not a recommendation to build an identity service. Priya could not learn that distinction from the interface, nor which provider account she needed, who would charge her, which context would leave her Mac, or whether the connection was ready.

The missing-install error was plain text in a small red composer banner: install Claude Code from a plain-text URL and run `claude` in Terminal. The only action was Close. The original question persisted locally but was neither marked failed nor retryable. After the observer supplied the development machine's existing signed-in connection, Sophia said it did not have that question even though it remained visible above the reply. Retyping the question produced a real answer.

No new account, installation, provider sign-in, expired-login recovery, commercial eligibility or billing attribution was tested. The missing-install condition was explicit debug fault injection, and supplying a working dependency is not evidence that a first-time person can set it up.

## Evidence and method

The reusable harness consists of [UXHarness.swift](../../app/Sources/Sophia/UXHarness.swift), [ux.py](../../app/scripts/ux.py), a debug startup hook, and a debug-only missing-provider condition. It operates AppKit/SwiftUI accessibility actions, native text editing, real menu/keyboard actions, and native scroll views. It captures Sophia's actual window or attached sheet. It does not call notebook/session/model functions to stand in for learner actions, provide fake Sophia replies, or seed notebooks with invented content.

Each agent used only its own visible UI trees, screenshots and controls, and adapted questions to actual replies. Agents did not inspect source, notebook files, system prompts, provider logs or topic research. The observer inspected product source and, for the missing kick answer, the disposable persisted transcript; those diagnostics are identified separately in tickets. A source-level Foundation comparison also supported the notebook URL identity hypothesis behind SOP-19. Raw provider events were not captured, so the cause of SOP-27 is unresolved.

The first three runs used separate disposable libraries and overlapping real model sessions. Windows were exercised at approximately 1716×950, 1440×850 and 1280×800. The fourth agent started after the music agent finished. Captured learner interactions span approximately 23:07:43–23:27:01 UTC on October 24 (16:07–16:27 Pacific).

Full UI evidence stays locally in the ignored `app/build/ux-sim/{math,history,music,onboarding}/results/` directories. Each result contains a timestamp, submitted UI action, native accessible tree, and a matching PNG. [observations.json](observations.json) indexes key evidence and environment details; representative PNGs are also preserved under [evidence/](evidence/). Only synthetic learner material was used; no credential files or authentication caches were copied.

The original harness required repairs for text-field proxies, sheet capture, mouse-event tracking, and special-key characters. One Help shortcut hit unsupported native menu tracking. Harness restarts interrupted the learning sessions; an initial 60-second threshold caused an artificial early return in math/history. These were excluded from product findings. Planned return exercises also used an explicit 60-second threshold; **none establishes delayed retention**. Normal harness launches now retain the six-hour threshold unless explicitly overridden.

Edit discovery and the appeal of an in-app beat reference remain hypotheses for human follow-up: learners were told about the available editor shortcut, and no guitar was played. A narrow-width comparison table was hard to scan; it is additional evidence for the layout follow-up rather than a claim that every table needs redesign. Approximate waits are observation bounds with concurrent provider use, not production latency benchmarks.

## Verification and handoff

- Debug app and tool bundle built with the documented `make-app.sh debug` command.
- Production `swift build -c release --product Sophia` passed after the harness changes. Release code excludes the harness and missing-provider injection; a binary string check found neither debug environment marker.
- `swift run sophia-checks`: **all 37 checks passed**. This verifies existing core behavior, separately from the observed UX failures.
- Python harness parsed successfully; `git diff --check` passed.
- Native operations were exercised live: create notebook, type/send, show/hide book, scroll, menu/keyboard access, page edit/save/revert, note/memory correction, goal confirmation, Undo, End session, Quit/relaunch and planned return.
- Real model replies and page/learning writes were observed. Fresh provider setup and billing attribution remain unproven; unavailable billing evidence is inconclusive.

The only application changes are opt-in debug instrumentation. Companion instructions and release UX were left unchanged so findings can be reproduced. Test app instances were closed; the pre-existing personal Sophia process was left alone. Follow-up should fix the scoped tickets and repeat the same UI scenarios, then test actual first-time people and a genuine delayed return.
