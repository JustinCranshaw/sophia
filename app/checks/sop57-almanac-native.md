# SOP57 — native Almanac integration

Scope: [SOP57](https://linear.app/decomposer/issue/SOP-57), on landed SOP56 Core `cea64dc9e291525b73c677ab23e796303d0bd9fd`. This is local implementation evidence, not a retention study, independent factual certification, distribution approval or commercial/billing proof. All notebooks/material were disposable developer fixtures. The original checkout and personal Library were untouched; no macOS notification authorization was requested.

## Source epochs

- Initial UI prototype used unmerged Core `37b813a` only in an authorized disposable integration worktree. Its setup/initial layout observations are historical, not verification of the final Core.
- Final implementation integrated landed Core `cea64dc`. Reading revision `f5da9ab` and subsequent owned UI commits were built against that dependency. Representative keyboard/editor/automatic checks exercised that landed Core with precommit UI refinements. The later sidebar/status changes do not alter preparation, editor or navigation logic.
- `d8afa71c48fe584448492781c21c446488a10497` contains the final Options focus/queued debug-event handling and compact failure presentation. The first actual entry used this exact source.
- `3f7a5c0` adds explicit conditional cancellation labels and a visible settings-save warning after independent review; Core run semantics are unchanged. A wide protected-editor native follow-up below closes the earlier narrow-only coverage gap.
- `afcdc27` adds only the authorized generic model-assumptions/self-check sentence in `AlmanacPrompt.system`. The second actual entry used that source. Original generated evidence was retained unmodified.

## Build and checks

From `app/`: `./scripts/make-app.sh debug` builds both native products and an ad-hoc local bundle. The final prompt build passed (`/tmp/sophia-sop57-assumptions-build.log`). `swift run sophia-checks` at d8afa71 passed **108 checks**, including the landed Core scope/day/recording/privacy/route/Undo cases; its final process-Quit check stays last. The subsequent prompt-only delta was built and evaluated through the second actual preparation, rather than described as a new persistence test. Targeted release packaging is recorded below; a release-all checker build is not claimed.

From repository root:

```sh
swiftc app/Sources/Sophia/AlmanacNotifications.swift app/checks/almanac-notifications.swift -o /tmp/sophia-almanac-notifications
/tmp/sophia-almanac-notifications
```

Passed with an injected controlled client: no authorization request on launch; explicit enable/denial; late grant after Disable ignored; duplicate/reopen suppression; submission failure; permission revocation; disable removes only the owned pending identifier. These checks do not establish actual OS delivery, Focus handling or notification-click behavior on a signed distribution build.

## Native representative matrix

The debug harness drove actual AppKit/SwiftUI controls and the existing WebKit source editor. Controlled Claude output was a uniquely owned executable, not provider output. Fake auth/status and inference were isolated to these launches. Landed Core108 supplies the exhaustive metadata/date/privacy matrix; no claim is made that every permutation was repeated in GUI.

| Case | Observed result |
|---|---|
| Setup, empty selection | Blank titles/topics disabled Enable; attempted AX press refused and created no notebook. Native blue drawing was not functional enablement. |
| Collision/privacy | Existing ordinary “Sophia’s Almanac” was not converted. Explicit enable created marked “Sophia’s Almanac (2)”; kept-separate source was absent. Daily default was off. |
| Prepare/ready/failure | Controlled successful page recorded; original source notebook/draft stayed put. Malformed output marked no new ready page; prior pages remained. Retry saved a new page. |
| Reading | Explicit Read uses the existing page surface, puts empty discussion’s composer below the entry at 900/1280/1440, and never claims that opening means reading/learning. Ordinary notebooks keep their layout. |
| Editor/background | A visibly typed unsaved source edit remained open through completed preparation; old page bytes were unchanged before explicit Done. No exact pixel/caret claim. New page became reachable without changing selected old page. |
| First question | Controlled person/reply records expanded normal discussion with the same selected page/editor and unchanged old page bytes. This was synthetic conversation, not provider quality evidence. |
| Options/Escape | Actual failure: Options lacked a keyboard focus target and Escape reached CodeMirror Revert. A focused popover container now consumes Escape; typed source remains visible/editor open and Options closes. Prepare also closes Options explicitly. |
| Pause/cancel/disable | Daily pause still admitted explicit manual preparation; Cancel retained the prior entry and prevented a late save. Disable persisted while keeping pages. Relaunch retained config and pages without announcing a new save. |
| Hidden automatic admission | Explicit developer automatic settings targeted the next local minute. App was hidden/inactive before and after durable save at 18:38:03 UTC; selected source page and exact draft survived. One waiting entry remained. No Mac sleep/wake was induced; wake hook inspection and Core clock cases are separate. |

The harness initially selected an ambiguous underlying notebook button rather than a setup checkbox; role-specific selection corrected it. Earlier direct key dispatches and failed editor assertions are retained as diagnostics, not passes. In-process `window.sendEvent`, then `NSApp.sendEvent`, then the queued-event comparison all exposed the missing focus target; adding `.onExitCommand` alone was insufficient. The retained debug driver posts owned key events through the AppKit event queue, matching its existing click path. It selects only this app’s visible popover/sheet/main window; no global capture or permission changes. Final popup close/main-window and sheet behavior were exercised. No unrelated processes or temporary directories were cleaned.

## Implemented design loop

The standard convergent Mara/Marcus/Imani charrette read actual setup/loading/error/narrow/wide screenshots. First render placed empty conversation above the entry; all three independently identified that conflict with reading as a complete use. The implemented revision reused BookView/ConversationView, stable surface identities and a default-false compact seam. No ordinary notebook reader framework or scroll service was introduced.

Revised 900/1280/1440, Options daily-off and passive editor-completion originals were inspected by all three. They accepted the direction without blockers and requested one bounded craft change: full errors in Options, short failed-new-attempt status in sidebar. Final status now also takes precedence over paused scheduling so a failed manual attempt is not mislabeled only “paused”. Saved-page Read/Undo remain available.

Official Claude Code 2.1.310 lead selected `claude-opus-5-5`; both runs ended success with canonical model `claude-opus-5-5`, provider `firstParty`. Actual child assistant metadata independently showed that model for each voice:

| Voice | Opening agent | Revised agent |
|---|---|---|
| Mara | ac43941c70928ba75 | a82964072413cef0c |
| Marcus | acb12062da61e27f0 | a063464b9e9a71fe8 |
| Imani | a13a128d8ac9aa2e2 | aa37d768c8358b67d |

The installed Agent runtime could not resume children or return usable handles. The revised voices were explicitly disclosed replacement executions of the same personas, with prior positions and the other two digests carried forward under the skill’s unavailable-agent exception. There was no fourth voice. Initial lead digest wrongly equated opened with read; this was explicitly corrected before revised inspection. Actual native application, not the critique report, is the deliverable. Charrette logs are owned `/tmp/sophia-sop57-design*.jsonl`; no personal session/auth/cache logs were read.

## Actual provider entries: delivery and quality are separate

Both explicitly authorized manual preparations used `/Users/justincranshaw/.local/bin/claude`, **2.1.310 (Claude Code)**, existing default model/route. Captured owned launch arguments included `--restricted --setting-sources ''`, WebSearch-only tools, strict empty MCP configuration, WebFetch and notebook MCP tools disallowed. No extra ordinary chat, Fetch or source-opening approval occurred. Neither entry used WebSearch. Model identifier is not exposed by this worker and is not inferred from earlier evidence. No credential/cache material was inspected or logged.

Selected title was the actual disposable “Synthetic geometry themes”; optional topic requested a small connection between geometry and everyday visual perception. This was developer-supplied curation material, not a person’s learning history. Automatic and notifications were off. Original source notebook files were byte-exact after both preparations. UI acknowledgement, parsing, recorded save and rendered page are stronger evidence than login alone; none is billing/commercial authorization.

1. **First entry, d8afa71:** 32.65 seconds, saved run `37281C68-5402-4305-93D6-27F46A4A2F2F`, write `t-0001`. [Original entry](sop57-almanac-native/actual-first-entry.md) and [900 render](sop57-almanac-native/actual-first-read-900.png) retained unchanged. Delivery passed, **content quality failed**: “Why the Horizon Always Sits at Eye Level” conflates an ideal flat-plane perspective horizon with the real sea horizon and makes an absolute claim. [Andrew T. Young’s primary explanation](https://aty.sdsu.edu/explain/atmos_refr/dip.html) describes real horizon dip/atmospheric effects. Source-basis disclosure did not make that claim correct.
2. **Narrow revision/evaluation, afcdc27:** added a generic instruction to state material assumptions/limits and self-check mathematical/physical examples, without a verification framework or fact-check claim. One additional authorized preparation took 76.14 seconds, run `20D72EAE-3840-4D29-976B-C3F037D74790`, write `t-0002`: [second entry](sop57-almanac-native/actual-second-entry.md), [900](sop57-almanac-native/actual-second-read-900.png), [1280](sop57-almanac-native/actual-second-read-1280.png). The title names ideal pinhole perspective; assumptions and ignored lens/retina effects are stated. Numeric ratios 1.12/0.88≈1.27 and 2.35/1.65≈1.42 check. This sample did not repeat the first missing-model-assumption failure; it is not a guarantee that generated physical, mathematical or perceptual claims are correct or independently verified. Residual content limits remain: the flat-table d±r numerical example is transferred to a standing/slightly tilted bicycle wheel without specifying its tilt/depth span, and ideal geometry is extended into broad perception claims. [SOP58](https://linear.app/decomposer/issue/SOP-58) tracks human content-accuracy/return validation; no more prompt tuning or product calls were made in SOP57. The first page remained byte-exact; the old source page and exact draft stayed selected until explicit Read.

Captured owned real CLI PIDs 84167 and 88327 exited after completion; native apps were quit and verified gone. No additional product request followed these two authorized evaluations. No human practice, comprehension, retention or daily-use evidence is claimed.

## Selected originals

- [Setup/collision](sop57-almanac-native/setup.png) — historical prototype Core37b epoch.
- [Before reading revision](sop57-almanac-native/prototype-read-900.png) and [revised 900](sop57-almanac-native/revised-read-900.png) and [1440](sop57-almanac-native/revised-read-1440.png).
- [Unsaved edit after background save](sop57-almanac-native/editor-background.png), [focused Options Escape preserves edit](sop57-almanac-native/options-escape-preserves-editor.png).
- [Hidden automatic ready after unhide](sop57-almanac-native/automatic-hidden-ready.png).
- [Final failed-new-attempt sidebar](sop57-almanac-native/failed-attempt-sidebar.png) and [full Options reason](sop57-almanac-native/failed-attempt-options.png).

The identical titles in repeated controlled fixtures are deliberate test output, not a production curation-quality finding. Owned raw actions/results/scripts/logs remain under `/tmp/sophia-sop57-cbckmqb9` and `/tmp/sophia-sop57-prep`. Final built-app paths and release verification are recorded in the handoff; no personal app is replaced or installed.

## Final local package

`./scripts/make-app.sh release` passed for targeted Sophia and sophia-mcp products at afcdc27; `codesign --verify --deep --strict` passed for the ad-hoc bundle. Release executable contains no debug harness marker. An earlier packaging invocation was interrupted by my source edit during compilation and failed honestly; it is superseded by this completed final build, not counted as a pass. No release GUI, clean-Mac, distribution signature/notarization or OS notification delivery is claimed.

Retained local release app: `/tmp/sophia-sop57-cbckmqb9/Sophia.app`; debug verification app: `/tmp/sophia-sop57-cbckmqb9/Sophia-Debug.app`; actual generated notebooks: `/tmp/sophia-sop57-cbckmqb9/actual/library`. `Open Almanac Demo.command` in that same root sets SOPHIA_LIBRARY to only this disposable Library before launching the release executable. It was prepared, not launched during these checks; it neither installs/replaces an app nor opens the personal Library. Automatic preparation and notification intent remain off in this demonstration. Both original generated pages remain available.

## Independent-review follow-up

Initial frozen review e1a017c identified one unresolved protected-area check and one low FIX NOW cancellation-copy issue. Exactly three read-only adaptive Plan scopes covered notification consent/privacy, setup/scheduling and protected reading/editor integration; the separate review lead centrally inspected their candidates and passed owned scratch debug product builds plus the injected notification checks. Final exact-head disposition is in the PR comment, not inferred from this initial review.

- **Wide editor/first question:** [before](sop57-almanac-native/wide-edit-before.png), [after first question](sop57-almanac-native/wide-edit-after-question.png), [committed](sop57-almanac-native/wide-edit-committed.png). At 1600×900 (about 1332pt detail width), a unique typed unsaved marker remained visible as the reader switched from stacked to side-by-side. Editor marker remained and page bytes stayed exact before explicit commit. A native click on the page title (the documented commit-outside-editor path) then saved the marker exactly once and closed editing. Keyboard Done did not establish the editor focus in the driver; it is not counted as a successful Done assertion. This actual persistence check resolves the suspected subtree-recreation/data-loss path without adding a layout guard or new state.
- **Cancellation clarity:** the root product decision keeps configuration-invalidates-run behavior; the final UI names it rather than disabling the supported action. [Options during a controlled manual run](sop57-almanac-native/pause-cancels-active-entry.png) says “Pause daily & cancel preparation” (Resume likewise names cancellation during a run); the actual action cancelled and kept the previous entry. The [settings warning](sop57-almanac-native/settings-cancel-warning.png) stays visibly above Save rather than below a scroll fold. No Core lifecycle/semantics change or confirmation dialog.
- Accepted low residuals: cold-launch OS notification navigation may miss an early event (actual OS click/delivery unverified); a rare failure after unique folder creation can leave an empty unmarked folder; transient status/open-attach failures can need retry/reopen. Existing pages are not deleted or overwritten. Revisit on actual notification use or a reproducible affected workflow; no speculative pending-event queue, cleanup framework or persistence layer was added.

No additional product/provider request followed the two actual evaluations.

Final retained package was rebuilt after the review copy fix at code commit `3f7a5c08dee114b83c30ebf0da8d441e1419601b` (`/tmp/sophia-sop57-reviewed-release-build.log`). Both targeted release products passed, strict/deep signature verification passed after copying the retained bundle, and the debug harness marker remains absent. Later evidence-only commits do not change this runtime code. The launcher still targets only the disposable actual Library.
