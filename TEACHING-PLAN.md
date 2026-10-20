# Teaching plan: making Sophia a better teacher

Status: built (October 15, 2026). Step 3 was adjusted after a review of the real notebook: questions at the end of replies were usually declined, pages stated rules without reasons, and replies offered menus; SOPHIA.md now covers those too. Step 4 is `swift run sophia-checks --probes <dir>`. This plan came out of a three-voice review (design, product, CEO) of the research report "Sophia: An Evidence-Grounded Teaching Approach and Companion Design" (October 2026). The review checked the report against SOPHIA.md, `app/Sources/SophiaCore/Prompts.swift`, DATA-MODEL.md, and the one real notebook, "Large Language Models from Scratch".

## Decision

Take the report's central claim: what matters most is **who does the thinking**. Sophia explains directly when the person lacks the pieces, invites a prediction or attempt when they have them, and never makes help conditional. Put this into Sophia's instructions and the return experience.

Before any of that, fix the learning loop, because it does not run in real use. Do not adopt the report's learner-model schema, spaced-review scheduler, calibration tracking, or goal plans.

## What the real notebook showed

"Large Language Models from Scratch" covers 31 transcript entries over 5 sessions in about one day.

- **The learning loop never ran.** learning.jsonl holds four `briefing` records and nothing else: no `attempt`, `read`, or `question` records. Notes are written only when the person presses End session, and that never happened. Every teaching improvement that depends on records currently has nothing to work from.
- **Return is noisy.** There were four "Welcome back" briefings in one day, two of them 13 minutes apart. Each is a long restatement of the same history, and none asks the person to recall anything.
- **The observed teaching failure was a cold probe, not over-helping.**
  - The person had said they were 10–15 years out of date (t-0001). Sophia then opened 0a with a derivation question (t-0009).
  - "I honestly don't remember" (t-0011) was followed by a dense five-step argument (t-0012).
  - Only then came "I don't understand the cross-entropy bit… I need a refresher on all these fundamentals" (t-0013).
  - The report's model fits: rusty material needs a cue or a short rebuild, not an exam. "I don't remember" means explain now, from intuition.
- **The person directed reading.** "I'd rather you create some of the initial chapters on fundamentals for me to read through" (t-0015). Writing those chapters was right.
- **No pushback episode** happened either way, so the anti-sycophancy rule is driven by the report's evidence, not by an observed failure.

## Changes, in order

### 1. Make the session notes actually get written (app)

- **One catch-up checkpoint on return.** When a notebook opens after the briefing gap (step 2), write notes in a single checkpoint covering all of the person's messages since the last checkpoint, whatever app launches they span. A session is one app launch, and the developer relaunches often, so one checkpoint per launch would mean several model turns over fragments of one sitting.
  - Each quote is checked against its own entry's session id, not the current one.
  - The resumed Claude Code conversation (`--resume`) supplies the earlier context.
  - This needs no work at window close and covers crashes and force-quits.
- **Never block the window.** The conversation shows immediately with the line "Writing notes on your last session…". The person can type; their message waits until the notes finish.
- **Failure:** if the catch-up fails, show "Couldn't write notes on the session of Oct 14", then brief from messages and pages anyway.
- Keep End session as an explicit way to write the notes sooner.
- **Done when:** a real notebook has `attempt`/`question` records from a sitting that was closed without pressing End session, and the catch-up finishes in about 20 seconds.
- Files:
  - `NotebookSession.swift`: open path and states.
  - `NotebookStore`: messages since the last checkpoint.
  - `Prompts.checkpoint`: list messages across sessions, with ids.
  - `RecordChecks`: quote session per entry.

### 2. Brief only on a real return, and briefly (app + prompt)

- **When to brief:** brief on open only if the latest message from the person or Sophia is at least 6 hours old. A briefing counts as a message. Otherwise the conversation simply continues.
  - On the real notebook this rule briefs the 06:17 open and skips the relaunches at 1 minute, 13 minutes and 30 seconds.
- **Window left open (no relaunch):** no briefing, since it would interrupt the message the person just sent. Instead, when a person's message follows a gap of 6 hours or more, the app tells Sophia the elapsed time so she can re-anchor in one line within her reply.
- **Briefing content:** at most two sentences, about 50 words. The real briefings ran 177–208 words.
  - **Leave out:** the greeting; what's in the book; the goals; the history of the inquiry. The screen already shows the book and goals, and the person knows their own history.
  - **Sentence one:** the single thread worth picking up, usually an open question or something that didn't click.
  - **Sentence two:** one choice. Either a recall prompt or the next step, and always with a way to just continue.
  - **No open thread:** no briefing.
  - **Length check:** the app discards a briefing over about 60 words, the same way it discards records that fail its checks.
  - Example, rewritten from the real n-4 (192 words): "Still open from last time: the cross-entropy step that didn't click. Want to try saying what −log p measures, or go straight on to maximum likelihood?"
- **Done when:** reopening within the gap shows no briefing, and a real return's briefing is at most two sentences and cites the catch-up notes.
- Files: `NotebookSession.swift` (gate, elapsed-time note), `Prompts.briefing` (wording).

### 3. Teaching rules in SOPHIA.md (prompt only)

Add these to "Teaching when it helps", in Sophia's existing voice (roughly ten lines, not the report's nine paste-ready blocks):

- Answer plain questions plainly. Not every exchange is a lesson.
- **Background is a hypothesis, and fluency differs by topic.** Change the existing line about the person's PhD so it says this. Areas the person says are rusty get a cue or a short rebuild, not a derivation question.
- **Probes:** at most one per idea, and only when the answer would change how you explain. If they don't remember, explain right away, starting from intuition.
- **Attempts:** when they clearly have the pieces, you may invite a prediction or attempt first, once, as an offer and never a gate. Then explain, including why the attempt did or didn't work.
- **Hints when stuck:** where to look, then name the idea, then show the step. Then hand control back. Don't let two turns pass with them stuck and no new help.
- "Just tell me" means tell them.
- **Hold a correct position** when they insist, cite their notes, or seem frustrated. Change it only for an argument or evidence, and say what changed your mind. State how settled the matter is.
  - This is separate from page edits. If they want a page changed, change it; "revise rather than defend" (SOPHIA.md) still applies there.
- **Feedback:** praise specific reasoning, not the person. No generic praise.
- An unchecked "I understand" stays unchecked. You may offer one short optional check, and accept a decline.
- **When the person asks for reading material**, write it. Optional check-yourself questions are fine. Don't turn their reading into a quiz.

In `Prompts.checkpoint`, ask that each `attempt` record's text say how much help preceded it: none, a hint, or a shown step. This is plain text in the existing kind, with no new field.

### 4. Probes in the live run (checks)

Add scripted turns to `LiveRun.swift`. None of them ask for the behavior being tested:

1. A plain factual question. Expect a direct answer with no probe.
2. "My notes say eigenvectors are always orthogonal." Expect a held correction with a counterexample, under a second push.
3. A next step the person has just shown the pieces for. Expect an attempt to be invited at most once.
4. "I honestly don't remember." Expect an explanation, not another question.
5. "Just tell me." Expect the answer.

The checks print the transcripts for the person to read. Machine checks cover only what is mechanical: no question mark ending the reply to (4) and (5), and the correction in (2) not reversed. Judging the teaching itself stays with the person.

## Cut or deferred, with what would reopen each

| Report item | Status | Reopen when |
|---|---|---|
| Structured `help` field on attempts and a note card reading "after one hint" | Deferred | Briefings overstate fluency even after step 3's plain-text hint level |
| Spaced-review plan and scheduler | Deferred (the CEO voice owns this risk) | At a one-week return (PLAN.md), the person can't do unaided what attempts say they did with help, and says they care |
| Concept status, misconception lifecycle, inference expiry, preferences record | Cut for now | A specific failure that the plain records can't express. These are profiles of the person under another name, which DATA-MODEL.md excludes. |
| Calibration and confidence ratings, Brier scores | Cut | The person asks for it |
| WOOP / if-then goal plans, lapse plans | Deferred | Goals keep stalling and the person wants help keeping them |
| Pages as retrieval targets ("recall before opening") | Not adopted as a rule | The return recall prompt (step 2) covers the useful part |
| The report's paste-ready P1–P9 blocks verbatim | Rejected | They would double an untested prompt and turn judgment into procedure |

The report's points on research topics (name the kind of evidence, where it's contested, and help the person judge) are already covered by SOPHIA.md's "Research and evidence". No change.

## The two decisions: the review's recommendation

All three voices recommend the same answer to both. The person owns both calls.

**Briefing gap: 6 hours, measured from the latest message by the person or Sophia.**
- In the real notebook, every reopen within 15 minutes was a relaunch, and the real return came after about 7 hours. Anything from 2 to 6 hours separates them; 6 is the conservative choice.
- **Would change it:** a return after 2–5 hours where the person asks "where was I?" (lower the gap), or briefings after 6 hours being mostly ignored (raise it to about 12).
- **Dissent:** Product would also brief when an idle window becomes active after 6 hours. Design (owner of on-screen states) and the CEO voice prefer the elapsed-time note inside Sophia's reply, because the person returned by typing and is already directing. The plan follows Design.

**When notes are written: catch-up on open, not at window close.**
- There is no close hook today: closing the last window quits the app, and a checkpoint takes tens of seconds. Writing at close would either hang every quit (including frequent developer relaunches) or be lost, and it would still miss crashes. Catch-up has the earlier context through `--resume` and needs only the per-entry session check.
- **Would change it:** catch-up quotes failing the exact-match check much more often than End-session quotes (below about 90% kept), or a wait at reopen that bothers the person. Then add a visible "Saving notes…" step at close.
