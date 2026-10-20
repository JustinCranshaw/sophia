# Product and design review: conversations beside the notebook

Review only · October 19, 2026

**Recommendation.** Keep page-owned conversations. They give the learner a useful place to return to a difficult derivation, and scenario 6's brief aside does not justify a second thread. Before implementation, resolve three contracts: when clearing has actually preserved the inquiry, what the single undo rule permits, and whether creating a page changes the selected conversation. These are problems within the chosen direction, not reasons to replace it. This is my judgment from scenarios 4–6 and 9–11, DATA-MODEL.md:128–167, PLAN.md:222, and gate2.md:7–13.

**Authority and evidence.** Citations to `gate2.md`, `C3/…`, and `briefs/scenarios.md` are relative to `charrettes/2026-10-chat-scope/`; citations to the four product documents and AGENTS.md are relative to the project root. Line numbers refer to the files read for this review.

- **Observed — document inspection:** I read gate 2 first, then the applied documents, AGENTS.md, all eleven scenarios, and the older C3/C4 specifications as context. Gate 2 removes the transition pointer, context marker/subtitle, amber rebuild treatment, reopen explanation, and special new-page undo window. None is part of my proposed experience. “Started from,” the private Elsewhere information, and “interrupted · Ask again” remain. (gate2.md:7–13, 46–49.)
- **Observed — historical visual evidence:** I inspected the existing C3 screenshots `chosen-2.png`, `chosen-4-open-r.png`, `chosen-5-cleared.png`, `chosen-7b.png`, `chosen-8-protected.png`, and `chosen-10.png`, plus the prototype source. These depict scenarios 2, 4, 5, 7, 8, and 10 before the simplifications. In particular, the clear screenshot exposes notes and a “your line” tag, and the page-switch screenshot relies heavily on the removed pointer. These are observations of archived images, not a fresh browser render or evidence about the eventual Mac app. The corresponding source is mock/chat-scope/chosen.html:630, 633–634, 639, 642–643; the cuts are gate2.md:8–13.
- **Inferred:** every statement about likely learner confusion, cognitive effort, or the post-cut visual result below is a review judgment, not an observed usability result. The applied design has not been rendered or exercised here; no app, provider, persistence, keyboard, or accessibility check was run. The charrette itself also distinguishes rendered states from assumed continuity and untested model behavior. (C3/decision-brief.md:10–13; AGENTS.md:51–53.)

“Blocks implementation” below means the docs permit incompatible implementations of a core interaction. “Should fix first” means the smallest correction belongs in the implementation brief. “Observe in use” means retain the simpler design until a concrete failure warrants more.

**Product lens — the learning experience**

The best part of this direction is that a page can hold both the settled explanation and the learner's unfinished thinking beside it. On P, the corrected filter explanation belongs in the book; the person's question, attempt, and disagreement remain in P's conversation. That supports returning to the reasoning rather than treating saved prose as evidence of mastery. The distinction is explicit in scenario 1, DATA-MODEL.md:107, 133, 196–202, and SOPHIA.md:44–46.

The difficult moment is crossing a conceptual boundary. In scenario 2 the person is still investigating the convolution theorem when they open Sampling. The app changes conversations immediately, while Sophia receives activity information rather than P's words. That can work if Sophia retrieves what she needs herself. It becomes clerical work for the learner if she asks them to reconstruct the exchange that is already stored. The absence of a pointer card is not the defect; inadequate retrieval would be. (PLAN.md:222; DATA-MODEL.md:273–287; SOPHIA.md:84, 98.)

The silence about internal processing is a good simplification, provided the product distinguishes silence from a false promise of continuity. The learner need not know when notes were made, but “Why is that step valid?” must still resolve to the right step, and a failed fresh start must leave their typed question safe. Those are observable outcomes, not requests for context controls. (Scenarios 5, 7, 11; gate2.md:7–8; DATA-MODEL.md:128, 138, 240–245.)

**Product findings**

**P1 — A successful clear can currently preserve no new notes. Severity: blocks implementation.**

**Observed:** a clear waits for a successful checkpoint “so everything before a clear is in Sophia's notes.” However, a parseable checkpoint whose records are all rejected still counts as successful; `through` then advances, and pre-clear messages cease to be supplied automatically. The checkpoint's advertised kinds also include `follow_up` and `background`, while the later acceptance list excludes both. (DATA-MODEL.md:128, 138, 230, 240–254; gate2.md:7.)

**Inferred consequence:** in scenario 5, the learner's unresolved caveat about the convolution theorem can disappear from the next automatic context even though the clear appears to succeed. The transcript is preserved and `recall` remains available, so this is not deletion; it is a break in the stated continuity guarantee. The same rejection path affects the return in scenario 7 and automatic compaction in scenario 11.

**Smallest doc change:** distinguish an intentionally empty valid checkpoint from one whose proposed records were all rejected. Treat the latter as the existing failure path: do not advance `through` or clear; keep the words available. Align the checkpoint kinds with the actual allowlist. Replace “everything … is in Sophia's notes” with a narrower promise about preserving relevant inquiry, backed by a scenario 5/7 check that the pending derivation step survives. No extra summary, file, or record type. Keep validation diagnostics internal in the Mac UI; DATA-MODEL.md:242, 254 currently says to show reasons, while :238 and gate2.md:8 require silence. The existing “couldn't start fresh” outcome is sufficient.

**P2 — Sophia may ask the learner to carry an exchange across pages. Severity: should fix first.**

**Observed:** each turn gets information about other active conversations, but not their words; Sophia is told “If it matters, ask, or use `recall`.” On R, the creating exchange is automatically supplied only until the next checkpoint. Notes supplied on R must cite R or a message in R's own thread; the docs do not require the creating exchange's notes to do either. (DATA-MODEL.md:273–287; SOPHIA.md:84–85; scenario 4.)

**Inferred consequence:** the explicit question in scenario 2 may be answerable from Q and a read of P, so fragmentation is not inevitable. But a follow-up such as “Is that the same assumption we just used?” can make the person restate their reasoning. On R after a checkpoint, they can see “Started from” while Sophia lacks that exchange in her initial context. These are concrete cases where the chosen page boundary should not become the learner's responsibility. (Scenarios 2, 4; DATA-MODEL.md:140, 278.)

**Smallest doc change:** in SOPHIA.md:84–85, prefer `recall` of the relevant exchange and `read_page` before asking the person to repeat available information; ask only if retrieval leaves genuine ambiguity. Include the existing creating-entry reference when describing R's provenance, so Sophia can retrieve it after the checkpoint. Qualify “will begin from this exchange” to match that behavior. Do not copy whole neighboring conversations into every prompt or restore a switching card.

**P3 — “One undo rule” still has several meanings. Severity: blocks implementation.**

**Observed:** gate 2 includes writes, edits, releases, and undos, all expiring at the next change to the page. The applied write predicate checks only later writes, edits, or undos; a release is absent. The release paragraph likewise omits later releases. Undo restores the previous file, but no rule explains undoing that undo. For a new page, Undo deletes its file and leaves only the conversation accessible by `recall`. (gate2.md:13; DATA-MODEL.md:155–167; EDITING.md:42, 56, 70.)

**Inferred consequence:** after scenario 8's edit and release, the conversation can offer an old “Undo your edit” while the latest action was permission to change it. In scenario 9, banner Undo and a historical conversation Undo might target different actions. Taking gate 2 literally also promises reversal of an undone new page without saying where its deleted body would come from. This is not a request for a history stack; it is an unresolved promise.

**Smallest doc change:** define one latest eligible page action, including release, and make every banner/card compute eligibility against it. Label the action explicitly, including “Undo permission to change your edit.” State what follows Undo. My recommendation is one reversal of the latest action, with Undo itself ending that opportunity; that requires your clarification of gate2.md:13, rather than silently weakening it. If reversible Undo is essential, specify what can be reconstructed within the existing files before promising it. Do not introduce a special new-page time window or a revision archive.

For the retained ability to undo a new page after talking on it, add one sentence to the existing undo result: the conversation is kept and Sophia can find it. That makes scenario 4's disappearing page less surprising without blocking the action or introducing a new history manager. (DATA-MODEL.md:155; gate2.md:12–13.)

**P4 — Long history has a trigger, not a demonstrated capacity guarantee. Severity: observe in use.**

**Observed:** after a turn reaches 30 messages, a notebook-wide checkpoint runs; six preceding messages are carried. Failures preserve messages and retry. Page bodies and page-related notes are also supplied, without a size bound here. Older messages remain in the transcript. (DATA-MODEL.md:138–139, 232–243, 273–281.)

**Inferred consequence:** scenario 11's months-long Contents conversation is not intrinsically broken by this design, but “30 messages” does not establish a prompt-size or latency ceiling for dense mathematics. A single long derivation or repeated checkpoint failure can exceed the ordinary case. A notebook-wide checkpoint can also replace P's active context after unrelated work on Q. This needs evidence, not a meter for the learner.

**Smallest doc change:** add a focused scenario 11 check to DATA-MODEL.md's verification: continue a long mathematical exchange after an automatic checkpoint and retrieve one exact older attempt. Record delay and whether the next step stays correct; document failure behavior without asserting a hard 36-message capacity. Retain the existing storage and trigger until that check demonstrates a problem. (DATA-MODEL.md:325–345; AGENTS.md:40, 51.)

**Check against every locked product principle**

These are assessments of the specified design, not claims that enforcement has been tested.

| AGENTS.md principle | Assessment and evidence |
|---|---|
| Personal usefulness and a Mac home (:18) | Page selection and local edit commands fit the task; command scope and focus still need the clarifications D1/D3 below. Native behavior remains untested. (PLAN.md:222–224; EDITING.md:34, 81, 113.) |
| Library → Notebooks → optional Chapters → Pages; emergent structure (:19) | Preserved. Threads attach to stable page filenames, so moving Zero-padding does not create a new conversation. Contents owns notebook discussion; chapters need no extra thread. (DATA-MODEL.md:78–88, 114–119; PLAN.md:222; scenario 3.) |
| Explanation, challenge, research; no compulsory mode, lesson, or page (:20) | Supported by one composer and direct-response instructions. Contents must remain a place for substantive inquiry as well as organization, not an administrative lobby. (SOPHIA.md:11, 17, 62; PLAN.md:96, 222; scenarios 3, 11c.) |
| Questions both ways; no quota or mastery inferred from assent (:21) | The thread model adds no quota; the prompt distinguishes assent from understanding. Its “at most one” question is a ceiling, not a required question. Return navigation must also accept a person's unresolved question, not only Sophia's exercise. (SOPHIA.md:40–46, 102; D2; scenario 7.) |
| Separate evidence, actual statements, and interpretation (:22) | Quotations, checked references, and labeled interpretations remain; removing page authorship badges does not remove those distinctions. P1's rejection behavior undermines continuity, not authorship checking. (DATA-MODEL.md:107, 183–202, 247–254; SOPHIA.md:54–56, 64.) |
| Concrete return: open question, prior idea/attempt, uncertainty, useful next step (:23) | Required in PLAN, but the applied return display and destination are incomplete. D2 supplies the missing interaction without exposing checkpoint state. (PLAN.md:108–110; DATA-MODEL.md:244–245, 289; scenario 7.) |
| Emergent textbook, directed by the person; no writing ahead (:24) | Supported by SOPHIA.md:62. The fixture's unprompted Orthogonality page is historical setup, not authorization to repeat that behavior; its empty conversation must not trigger an unsolicited lesson. (briefs/scenarios.md:40, 68; scenario 11a.) |
| Conversation beside book, direct undoable writes, provisional goals (:25) | The intended behavior supports this, but P3/D1 must settle undo and selection. Goals remain provisional until the person confirms. (PLAN.md:222; DATA-MODEL.md:217, 222; scenarios 3, 4, 9.) |
| Direct section editing; no overwriting; no social platform (:26) | Store protections and byte-exact editing survive page scoping. The release card is an explicit permission action, not a passive authorship tag. No social feature is introduced. (EDITING.md:34, 42–56; DATA-MODEL.md:143–145; PLAN.md:82; scenario 8.) |

The review proposes no tools with broader permissions, cross-notebook reads, new persistence files, or execution of page content. Provider access, billing, and the real experiment remain outside what this review establishes. Those boundaries stay locked; none can be inferred from a successful prototype render. (AGENTS.md:32–45, 49–53.)

**Design lens — all eleven scenarios under the applied rules**

In each walkthrough, **documented** means the applied docs or gate 2 specify it. **Projection** is my reconstruction where interaction details survive only in older material or need a decision. No projection below includes the removed marker, switching pointer, rebuild explanation, or authorship badge.

**1. Ask about a sentence, then revise.** **Documented:** P and P's conversation are selected together; asking about selected prose is supported. Sophia answers, revises P directly, describes the change, and both the page banner and the write's conversation control can offer Undo while eligible. Her reply and the revised book are distinct objects. (PLAN.md:222; SOPHIA.md:66; EDITING.md:70; scenario 1.)

**Projection:** the chosen sentence should appear as the quotation attached to the person's question, with their selection and draft preserved until Send; the older spec explicitly routes the quotation to P. After the revision, keep the reader at “What it buys you,” rather than jumping to the page top. This follows the focus/scroll requirement but needs an explicit acceptance observation. Plain selection-based questioning is already part of this scenario; it should not be confused with the deferred anchored suggestion workflow in EDITING.md:92. (C3/interaction-spec.md:49; PLAN.md:224.) No extra thread or page-edit mode is needed.

**2. Open Q mid-exchange and connect them.** **Documented:** the page and conversation both switch to Q. P's late reply remains on P. Q's answer appears only in Q; its Sophia has Q, relevant notes, memory, its own exchanges, and information about activity elsewhere. P's actual words require retrieval. There is no “Continuing from” card. (PLAN.md:222; DATA-MODEL.md:115, 273–287; gate2.md:10.)

**Projection:** retain the older design's ordinary navigation controls and offscreen reply indication, and preserve Q's own scroll/draft state. The archived scenario 2 image shows a blue dot on P, but the applied docs do not fully specify its lifecycle. A simple in-session indication is enough; do not add unread-state persistence. The conceptual connection should be answered through Sophia's retrieval, as P2 describes. (C3/interaction-spec.md:9, 13; scenario 2.) Without the removed card, the scope title above the composer matters more, not a replacement continuity panel.

**3. Notebook-level discussion.** **Documented:** choosing Contents selects the notebook conversation; before there are pages, it fills the window. The three questions stay there. Moving Zero-padding changes ordering metadata while retaining its page identity and conversation. Sophia's goal change is shown where it arose and is provisional until confirmed. Goals and Chapters do not acquire conversations. (PLAN.md:222; DATA-MODEL.md:88, 114–127, 217, 222; scenario 3.)

**Projection:** label the conversation “Fourier analysis — notebook conversation” while leaving the navigation item “Contents.” Its empty composer should invite an inquiry, not require a planning task. Specify what composer remains when the person opens Goals or Notes; the applied docs only say those views have no conversations. D1 recommends retaining and naming the existing conversation so “Make that the goal” has a visible destination. (PLAN.md:222; SOPHIA.md:11, 100.) These are scope labels, not a new mode picker.

**4. P's conversation creates R.** **Documented:** Sophia keeps answering on P. The creating write is recorded in P, R is a distinct page with its own conversation, and R's “Started from” card derives from the creating entry and exchange. R gets the creating exchange initially if it was written since the latest checkpoint. (SOPHIA.md:85; DATA-MODEL.md:120, 140, 278.)

**Projection:** remain on P/P-chat, show the recorded write with an Open R action and eligible Undo, and select R/R-chat only when the person opens it. On R, show “Started from a conversation on 1.3,” the original question and available answer excerpt, and a link to that exchange. The conversation itself is not duplicated. This matches the older interaction intent, but PLAN.md's “a new page opens it” and SOPHIA.md's “sees it beside the conversation” need D1's clarification. (C3/interaction-spec.md:53–55; PLAN.md:222; SOPHIA.md:66.) Unlike the removed switching pointer, this is lasting provenance explicitly retained by gate2.md:49.

**5. Fresh start on P.** **Documented:** ⇧⌘N runs notes first, then clears only on success. The old entries remain folded under “Earlier on this page”; automatic context no longer includes pre-clear messages, while notes and memory remain. A failure leaves the conversation unchanged and says it couldn't start fresh. There is no context divider or notes explanation. (gate2.md:7–11; DATA-MODEL.md:128, 138–139.)

**Projection:** show a blank current exchange under the folded history, preserve the page position at “Where it fails,” and keep the composer available. Expansion reads the old discussion in place; it does not resume a separate provider session or silently put those words back in Sophia's prompt. The command needs a visible name and deterministic behavior for text entered while it is pending; D3 addresses both. “Fresh” cannot mean forgetting learned information, because scenario 5 explicitly retains notes and memory. P1 must be fixed before this promise is credible.

**6. Two unrelated lines on P.** **Documented/context:** the page owns one thread; the older charrette explicitly cuts a second thread, and scenario 6 asks whether one is justified. The person asks the length question in the same composer. Sophia can answer directly, then return to the swapped-sums step without forcing another exercise. (DATA-MODEL.md:114; C3/interaction-spec.md:71; SOPHIA.md:17, 23, 40; scenario 6.)

**Judgment:** retain one stream. A one-exchange aside is less work than choosing a thread, clearing, or editing the page just to ask a question. Do not use ⇧⌘N here: that intentionally puts the derivation into earlier history. The deciding observation is whether Sophia resumes the pending step when asked; the fixture supplies no evidence that concurrent subthreads earn their complexity. (Scenario 6; AGENTS.md:20, 40.)

**7. Back after a week.** **Documented:** the eight-day gap qualifies for catch-up notes and then an at-most-two-sentence briefing in Contents; it may be empty. The account must be grounded in records, and the person can follow and correct its claims. There is no rebuild announcement. (DATA-MODEL.md:236, 244–245, 289; SOPHIA.md:102; gate2.md:8.)

**Projection:** land on Contents with a short account of the unfinished swapped-sums step and one invitation to continue. A link opens P's conversation at that exchange. If the person opens Q before reading it, show the same briefing once above the book with a dismiss control, leaving Q selected. These behaviors appear in the older spec and archived scenario 7b image, but are not fully carried into the applied docs. They are reasonable surviving intent, not confirmed applied requirements. D2 should promote a precise version. (C3/interaction-spec.md:45; mock/chat-scope/chosen.html:639.) No ring, extra shortcut, or task-like “answer Sophia” obligation is necessary.

**8. Editing P while its conversation is open.** **Documented:** the section editor remains open when focus moves to the composer. A conflicting Sophia write is refused; she answers instead of retrying. Done commits the person's text; a conversation entry and banner offer its Undo. The next message carries the hunk. A later protected-line refusal shows the person's edit, Sophia's reason, and “Let Sophia change this.” There is no permanent “your line” badge. (EDITING.md:34, 42–56, 64, 70; SOPHIA.md:70; gate2.md:13.)

**Judgment:** this is an appropriate disclosure at the point of action. The person needs to understand whose text is being released even without authorship decoration on the page. However, clicking “Let Sophia change this” grants permission and launches no turn; it does not apply a displayed revision. Say “She can revise it on your next message” on the existing card, or use equally explicit permission wording. Do not add pending suggestions now. Reconcile the broad “a refused write … release marker” wording with the distinction between an open editor, which requires finishing/reverting the edit, and a protected edit, which can be released. (EDITING.md:46, 50–58, 64; DATA-MODEL.md:134–135.) This is finding D6.

**9. Undo across scopes.** **Documented:** a message in Q does not expire P's revision Undo; returning to P still offers it if no qualifying change occurred there and its file checks pass. Undo in P's banner and Undo beside that write target the same change. Q shows no pointer to it. (DATA-MODEL.md:155–163, 337; EDITING.md:70; gate2.md:10, 13.)

**Judgment:** this is simpler and more useful than an undo window governed by conversation timing. The label should identify the change, especially if it remains available days later; the existing author-specific labels supply a starting point. A disabled/absent Undo on an older card must not fall through to a different latest action. P3 must settle releases and Undo itself. Keyboard ⌘Z should stay with the focused text editor/composer; a page action should not unexpectedly undo a paragraph because the user corrected their draft. EDITING.md specifies editor routing but the broader focus contract needs stating. (EDITING.md:70, 81, 113; scenario 11b.)

**10. Crash and relaunch with several scopes.** **Documented:** persisted histories remain assigned to their threads. P's eligible Undo survives. A stored person message without a following completion/stop and with nothing pending shows “interrupted · Ask again”; Ask again resends without adding another person message. All contexts rebuild silently. Scenario 10's request to announce resume failure is superseded, not an unmet requirement. (DATA-MODEL.md:115–126, 141, 151–165; PLAN.md:161, 199; gate2.md:8, 48.)

**Projection:** show the interruption beside the affected exchange, not as a whole-pane warning; Q and Contents retain their ordinary appearance unless they independently contain interrupted work. A quick relaunch does not get a week-away briefing. The archived crash image's amber marker is obsolete and says nothing about the usability of this simpler result. Retrying after a page write may repeat work unless Sophia reconciles existing effects; D5 addresses that specific risk. (DATA-MODEL.md:141, 244; scenario 10.)

**11. Empty and overflow states.**

- **Never discussed:** Orthogonality opens with its page and an empty conversation. The first question is answered using the page and normal notebook context; no automatic lesson is required. If its creating entry is available, the general “Started from” rule can still supply provenance—“never discussed” does not necessarily mean “no creating exchange.” The docs need to distinguish that case from legacy/unknown provenance. (DATA-MODEL.md:140, 273–281; SOPHIA.md:62; scenario 11a.)
- **Four sittings on Zero-padding:** the conversation is still one readable sequence. Only entries before an actual clear are defined as “Earlier on this page”; checkpoints do not create visible boundaries, dim old text, or create new conversations. Reading old words is independent of Sophia receiving them automatically. The archived prototype's session folds and dimming are not authority for those behaviors. (DATA-MODEL.md:138–139; gate2.md:11; mock/chat-scope/chosen.html:647; scenario 11b.)
- **Months of Contents:** the same automatic checkpoint mechanism applies, with normal notebook context rather than a page body and page-specific notes. The person sees the conversation, not internal boundaries. The applied docs do not settle ordinary date grouping, loading more history, or how an older source link reveals an exchange. D7 recommends the smallest reading behavior, not a search subsystem. P4 keeps capacity claims provisional. (DATA-MODEL.md:138–139, 237–243, 273–281; scenario 11c.)

**Design findings and minimal corrections**

**D1 — Selection, conversation destination, and new-page opening need one rule. Severity: blocks implementation.**

**Observed:** page selection selects its conversation, Sophia is told to keep answering in the origin when writing elsewhere, yet a new page “opens” the book and is seen “beside the conversation.” Goals and Notes have no thread but their active composer behavior is unstated. The older specification stays put and offers Open. (PLAN.md:222; SOPHIA.md:66, 85; C3/interaction-spec.md:53; scenarios 3–4.)

**Inferred consequence:** an implementation could show R beside P's composer, switch the composer to R mid-answer, or leave P selected. The learner cannot reliably predict where the next question goes. Without the removed pointer, a persistent and accurate scope title is the main orientation cue. (Scenarios 2–4; gate2.md:10.)

**Smallest doc change:** add a short paragraph to PLAN §5: selecting a page selects its conversation; a write never changes selection or steals composer focus; a new-page result offers Open; if the book is hidden, revealing it preserves the selected page/Contents. Goals/Notes retain the explicitly named active conversation. Update SOPHIA.md:66 to describe this result. Keep any background-reply indication transient. No navigation mode, saved cursor, or thread selector.

**D2 — The return's content is specified better than its route. Severity: should fix first.**

**Observed:** the applied docs place the briefing in Contents and require grounded claims, but do not say where the person lands, what opening Q first does, or where a briefing link scrolls. Those details exist in C3, whose route is specifically to Sophia's unanswered question. (DATA-MODEL.md:244–245, 289; C3/interaction-spec.md:45; scenario 7.)

**Inferred consequence:** restoring Q can hide the very account intended to save rereading; always jumping to Sophia's last question can turn a useful return into an exercise obligation when the unfinished inquiry was the person's objection or source investigation. (AGENTS.md:20–23; PLAN.md:108; scenario 7.)

**Smallest doc change:** put the scenario 7 projection above into PLAN §5, using a link derived from the briefing's existing references. Prefer “Continue on 1.3” to a compulsory exercise label. The target is the relevant unresolved exchange, whoever asked it; reveal it even if folded. For a shorter gap or an empty briefing, preserve the prior view when available. Show one briefing record in multiple places if needed, not multiple messages or a persisted dismissal system.

**D3 — Fresh start lacks a complete pending/failure interaction. Severity: should fix first.**

**Observed:** the new ordering and delayed send are specified; what happens to that send if the checkpoint fails, when queued text is persisted relative to `clear`, and the visible command name are not fully specified in the applied docs. The earlier C4 contract disables Clear while turns are pending, but is not a substitute for the changed gate-2 ordering. (DATA-MODEL.md:128, 240, 343; gate2.md:7, 47; C4/decision-brief.md:63–74; scenario 5.)

**Inferred consequence:** the person may submit “Start fresh on Where it fails,” then see it sent into the old exchange after failure, or folded into earlier history if it was stored before the clear. That would make an internal operation the person's problem.

**Smallest doc change:** name the existing menu/header action “Start fresh on this page” (Contents: “Start fresh in this notebook conversation”), with ⇧⌘N. Permit it only when it can run between turns. While pending, preserve entered text and indicate only that the requested action is underway. On success, store/dispatch the waiting message after `clear`; on failure, keep it unsent in the composer with “Couldn't start fresh. Your message hasn't been sent.” Opening history never changes send destination. No confirmation flow or notes-status UI.

**D4 — “Started from” needs a bounded source link, not a navigation-history shortcut. Severity: should fix first.**

**Observed:** the card's derivation names the creating write, preceding person message, and first Sophia message “after that,” without precisely bounding the originating turn. The older card labels its source link “Back to 1.3 ⌘[.” (DATA-MODEL.md:140; C3/interaction-spec.md:55; scenario 4.)

**Inferred consequence:** a tool-only creation followed by a later unrelated reply can yield a misleading excerpt unless the lookup stops at the next person message. Opening R tomorrow from Contents also makes its source P different from the previous navigation location. Calling both operations “Back” gives a Mac keyboard command two meanings.

**Smallest doc change:** define the excerpt as the first available Sophia text in the creating turn, bounded by the neighboring person messages; omit the excerpt if none exists. Label the card action “View original conversation on 1.3,” targeting the creating exchange, expanding folded history as needed. Keep ⌘[ solely as navigation history. Use existing transcript IDs; add no stored provenance card. The explicit source link also helps P2's retrieval contract. (DATA-MODEL.md:111, 120, 140; scenario 4.)

**D5 — Ask again must continue the interrupted work without blindly repeating its effects. Severity: should fix first.**

**Observed:** interruption includes a crash after Sophia's text and during a tool call; the app can recover a successful write. Ask again resends the person's text, with no stated companion instruction to reconcile what already succeeded. Page-write information is available in the thread context. (DATA-MODEL.md:121–125, 138, 141, 341; scenario 10.)

**Inferred consequence:** “Write a windowing page” can be asked again after the page was already written, inviting a duplicate or unnecessary second revision. A second write also replaces the learner's useful previous-version Undo. This risk is inferred; no repeated tool execution was observed.

**Smallest doc change:** specify that Ask again supplies the existing exchange and recorded outcomes, and instruct Sophia to inspect affected pages before repeating a write. Preserve the original visible question, retain any persisted partial answer, and continue beneath it. Do not present an already saved page as unsaved. Add one scenario 10 verification case: write succeeds, reply completion is interrupted, retry produces no duplicate page. This uses existing context and read tools, not a transaction ledger or new retry record.

**D6 — Release reads like an immediate edit but only grants permission. Severity: should fix first.**

**Observed:** the release button lifts protection, is undoable, and reaches Sophia on her next turn; no automatic turn starts. The refusal description does not consistently separate open-editor and protected-line cases. (EDITING.md:46, 50–56, 64; DATA-MODEL.md:134; scenario 8.)

**Inferred consequence:** the learner can click the apparently actionable button and wait for a revision that will never start. An open-editor refusal must not suggest that releasing an old edit closes the editor or bypasses its protection.

**Smallest doc change:** amend EDITING.md's existing card copy and state descriptions: permission applies on the next message; open-editor refusals have no release button; protected-line refusals show the existing scoped permission action. Keep the quoted edit and reason, without a permanent page badge or an Accept/Reject workflow.

**D7 — History navigation should be defined independently of compaction. Severity: should fix first.**

**Observed:** the applied rule folds only pre-clear entries and otherwise reads as one conversation. The old long-history prototype folds sessions/months and dims messages relative to its now-cut marker. The exact applied empty-state copy and reveal behavior are unspecified. (DATA-MODEL.md:138–140; mock/chat-scope/chosen.html:646–647; gate2.md:11; scenario 11.)

**Inferred consequence:** copying the prototype's remaining folds can accidentally turn checkpoint dates into visible conversation boundaries, or make an evidence link appear to open nothing. A months-long Contents thread also needs a readable way to expose older words without asking Sophia to retrieve them for the person.

**Smallest doc change:** add to PLAN §5 that date separators and loading older entries are reading affordances only; they do not clear or reset a conversation. “Earlier on this page” means explicitly cleared history (Contents: “Earlier in this notebook conversation”). Clicking a source link expands/loads its target and preserves a way back. Use a plain scope-specific empty composer; do not explain Sophia's context inventory. Keep existing text/date ordering, with no index, history file, or history-management screen.

**The three findings that matter most**

1. **P1: clearing must not report success after rejecting all the proposed notes.** Otherwise the simple surface conceals a failure of the promised learning continuity. Fix the rejection contract and demonstrate the unresolved step surviving; do not bring back a context marker. (Scenario 5; DATA-MODEL.md:128, 240–254.)
2. **P3: make the single undo rule literally single.** Releases must participate in eligibility, and the docs must say whether Undo itself is reversible. Both visible Undo locations must agree. (Scenarios 8–9; gate2.md:13; DATA-MODEL.md:155–167; EDITING.md:70.)
3. **D1: settle what stays selected when Sophia writes elsewhere.** Staying on P with an Open R action preserves the conversation the learner is having and makes R's later provenance useful. The current wording permits incompatible experiences. (Scenario 4; PLAN.md:222; SOPHIA.md:66, 85.)

**Questions only you can answer**

- Did “any … undo … can be undone” at gate 2 mean a real reversible Undo, including restoring an undone new page, or one opportunity to reverse the latest action? I recommend the latter within the one-previous-version constraint, but that is a clarification of your decision. (gate2.md:13; DATA-MODEL.md:155–167; AGENTS.md:40.)
- When a week-away briefing is nonempty, do you prefer landing on Contents, or preserving the previous page with the same briefing above it? I recommend Contents for this deliberate return, while preserving a page the person explicitly opens before the briefing finishes. The applied docs leave that preference open. (Scenario 7; DATA-MODEL.md:244–245; C3/interaction-spec.md:45.)
- Is “a new page opens [the book]” intended to change the selected page immediately? I recommend an Open action and no automatic selection change, because P's answer is still in progress. This is the only remaining authoring preference needed to settle D1. (Scenario 4; PLAN.md:222; SOPHIA.md:66, 85.)

**Doc edits I would make before implementation — diff summary, not applied**

- **DATA-MODEL.md:** `~` distinguish all-rejected checkpoint failure from a valid empty result and align allowed kinds; `~` remove the absolute “everything is in notes” promise; `~` specify queued-message order and failure preservation around clear; `~` define one latest-action eligibility rule including releases, with Undo semantics resolved by you; `~` bound “Started from” to the creating turn; `+` targeted clear, provenance-after-checkpoint, interrupted-write retry, and long-history checks. Keep existing files and records. (P1–P4, D3–D5; DATA-MODEL.md:128–167, 230–254, 273–287, 325–345.)
- **PLAN.md §4–5:** `+` a concise interaction contract for scope titles, selection/focus on writes, Goals/Notes, fresh-start/history behavior, and return landing/link behavior; `~` clarify “a new page opens it.” State the post-cut visual rules directly so implementers need not reconstruct them from C3. (D1–D3, D7; PLAN.md:185–199, 222–224.)
- **SOPHIA.md:** `~` prefer retrieving relevant stored exchanges before asking the learner to repeat them; `~` qualify R's inherited exchange after a checkpoint; `+` reconcile completed page effects when continuing an interrupted request; `~` match write-result wording to the selected navigation rule. Keep internal rebuilding silent and substantive uncertainty candid. (P2, D1, D5; SOPHIA.md:66, 83–85, 102.)
- **EDITING.md:** `~` align banner/card/release Undo eligibility; `~` distinguish open-editor refusal from releasable protection and clarify next-message permission; `+` make focused text Undo routing explicit for both editor and composer. Do not add authorship decoration or the deferred suggestion workflow. The current Phase 3 list already lacks the hairline/Authorship toggle mentioned historically by gate 2, so no deletion of that nonexistent item is needed. (P3, D6, scenario 9; EDITING.md:46–70, 81, 89–93; gate2.md:40.)
- **AGENTS.md, app/, the charrette record, and prototype:** no edits. No new storage, record type, setting, mode, context control, or revision-history subsystem is proposed. The sole deliverable is this review. (User scope; AGENTS.md:38–40, 51–55.)
