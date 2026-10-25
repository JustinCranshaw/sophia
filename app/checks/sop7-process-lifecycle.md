# SOP7: bounded cleanup of owned Claude processes

## Observed failure

On main `b69dd14`, a controlled no-provider CLI parent and child ignored EOF and scheduled disposable marker writes. Native Quit exited app PID3410, but parent4048 and child4053 kept executing and both wrote markers **after Quit**. `/tmp/sophia-sop7-baseline-proof.json` records timestamps, captured IDs and EOF observation. Only those captured fixture IDs were terminated afterward. This proves the app-lifecycle failure with a controlled process, not how a real Claude process necessarily behaves.

Source inspection explains it: session shutdown closed stdin and scheduled termination three seconds later on the main queue, while AppKit could already exit. Terminating only a parent also does not retire a child that survives it. The pre-send auth-status process had the same app-exit lifetime problem despite its own five-second bound.

## Bounded change

Both existing launch sites use one small owned-process controller. The executable, arguments, cwd, environment, provider route and permissions remain unchanged. Launch and the one-way Quit gate are serialized, so a queued status task cannot launch an unregistered process after the registry drains. The controller records PID, UID and birth timestamp using the installed SDK's public `proc_pidinfo`/`proc_listchildpids` APIs. It refreshes only descendants of still-matching known processes every 50ms, revalidates identities before signals, and remains alive after the session/engine releases it. No process-name matching or global cleanup, launcher wrapper, provider/backend, auth mutation, SDK or new persistent ledger.

Stop/cancel retires the outbound generation and source bridge immediately. Explicit Stop signals the owned tree promptly; normal shutdown allows the existing three-second EOF grace, then TERM and a 200ms KILL escalation. A root that exits unexpectedly also causes its known surviving descendants to be retired. Capturing the tree **before** closing stdin preserves known children if a graceful parent exits as soon as it sees EOF. Late protocol output after Stop is ignored. The registry also owns status subprocesses, so Quit can terminate a pending check without launching inference.

AppKit's supported `applicationShouldTerminate` → `terminateLater` → `reply(toApplicationShouldTerminate:)` handoff keeps the main loop alive while this cleanup finishes, with a five-second handoff cap. Session shutdown commits the existing page editor, retires requests, and cannot dispatch queued work. An active ordinary request records `interrupted`, leaving its saved question available for explicit Retry; an explicit Stop retains intentional `stopped` semantics. Interrupted/failed internal requests are rejected through the existing checkpoint validation and cannot record a successful checkpoint.

Primary API references: [AppKit termination decision](https://developer.apple.com/documentation/appkit/nsapplicationdelegate/applicationshouldterminate(_:)), [termination reply](https://developer.apple.com/documentation/appkit/nsapplication/reply(toapplicationshouldterminate:)), and [Apple libproc implementation](https://github.com/apple-oss-distributions/xnu/blob/main/libsyscall/wrappers/libproc/libproc.c). The installed macOS SDK declares these process APIs and exposes birth/parent fields; a small Swift compile probe verified availability. `proc_listchildpids` returns a PID count, while its buffer size is in bytes.

## Core verification

Integrated base `ba58c10570d75b443e66488160b35e89acae773b` includes PR18/19. From repository root:

```
swift run --package-path app sophia-checks
app/scripts/make-app.sh debug
```

All **95 checks passed** (89 base plus six focused lifecycle checks); current debug app and MCP bundle built. Logs: `/tmp/sophia-sop7-integrated-checks.log`, `/tmp/sophia-sop7-current-bundle.log`. The six checks cover:

- Graceful EOF; EOF-ignoring/TERM-ignoring parent and child; an unexpectedly exiting root with a live observed child; no delayed marker writes. Cleanup survives releasing the caller's controller.
- A deliberately mismatched birth identity cannot signal a controlled still-running unrelated process.
- Actual fake-engine cancellation, queued late output suppression, and immediate source-bridge retirement.
- `interrupted` versus intentional `stopped`: exact saved Unicode question, partial reply and explicit Retry eligibility after reopen, without another person entry.
- Controlled malformed-line → valid result, rate-limit error, missing-network stderr/nonzero exit, and unexpected engine exit retain their actual protocol outcomes.
- Pending auth-status Quit: no inference/context delivery, bounded cleanup even when TERM is ignored, and no later launch after the Quit gate.

The existing intentional-exit check now waits for the inference process to actually launch before Stop; it no longer passes solely by cancelling preflight. Existing failed-checkpoint/rejected-note, cutoff-write/context reconstruction and retry guards remain registered. There is no provider resume attempt (`--resume` remains absent); fresh engines reconstruct context from saved local records. These fixtures are not actual service rate limits or network outages. Foundation ignores TMPDIR for `tempStore` on this Mac; shared fixture directories are left untouched.

## Native controls

Disposable `/tmp/sophia-sop7-fixed-ui`; executable override selects `/tmp/sophia-sop7-fixture/fake-claude`, with controlled local auth-status and stream-json responses. No provider request, source fetch, account change or credential inspection. Existing return threshold is explicitly huge to prevent unrelated automatic requests. All question/answer text labels itself controlled; the fake answer is not model-backed evidence.

- First fixed ordinary Quit: app exits in 3.60s, exact parent23783/child23784 stop and page hash stays unchanged. Its scheduled markers had already been written **before Quit**, so this run does **not** establish interception of delayed writes. That limitation is retained in its proof.
- Active checkpoint Quit: app25189 exits in 3.57s, captured parent26275/child26276 stop, no markers through 13s from startup, page hash unchanged. Internal launch has readOnly=true. No checkpoint completion is recorded; the original uncheckpointed question remains. This supplies the timed no-later-write proof missing from the first fixed run.
- First shutdown implementation used `stopped`, which intentionally hides Retry. Native reopen exposed that regression. The fixed shutdown uses `interrupted`; explicit Stop remains unchanged.
- Fixed interruption: native Quit starts 0.39s after process startup; app38465 exits in 3.54s. Captured parent38501/child38502 stop, source bridge disappears, and no marker appears through 13s. Question `t-0004` remains once, followed by `interrupted`.
- Reopen/explicit Retry: the exact saved question is delivered once in the active input and zero times in reconstructed history; no new person entry. A clearly labeled fake answer completes and Retry disappears. The graceful EOF idle Quit takes 0.23s and parent38764 stops. Original screenshot `1792931968378396000-b0b948.png` was inspected at original resolution.
- Pending status Quit: app39374 exits in 3.48s, captured status parent39421/child39424 stop; status args contain no context and no inference input file is created. No delayed markers through 13s; page hash unchanged.
- Pending source card Quit: no decision is made. App39642 exits in 3.39s; parent39678, marker child39679 and actual approval-only MCP39682 stop; bridge removed; callback returns **deny** after closure, without claiming a human denial. No source fetch, delayed markers or page change.
- Explicit Stop: observed 0.79s through the native driver's response/capture, including its overhead. Exact parent/child stop, bridge disappears, no delayed marker through 13s. The unsent composer marker survives Stop and notebook away/back navigation.
- Active notebook switch: old process tree stops in 3.56s, bridge disappears, no markers through 13s; original conversation records `interrupted`, other notebook receives no question and its local page remains readable. Original screenshot `1792932156625815000-24933e.png`; final app41094 quit natively and was verified gone.

Proofs live in `/tmp/sophia-sop7-fixture/<case>/proof.json`, with separate `proof-retry.json`, callback response and pending-card proof where relevant. Native snapshots are under `/private/tmp/sophia-sop7-fixed-ui/results/`. Core protocol checks, native UI observations, and source inspection are distinct evidence.

## Limits and pending audit

This is bounded best-effort ownership cleanup, not OS process isolation. A child that is born and completely detaches/reparents between ownership samples cannot be guaranteed captured. Signals are skipped if identity can no longer be established; identity lookup and signalling are not an atomic kernel handle. The five-second AppKit cap is not a guarantee against an OS-uninterruptible process. No claim that controlled processes reproduce every real Claude descendant topology or service failure. Idle real-provider Quit was separately observed in SOP48; no real provider request was repeated here.

Composer drafts remain the existing window-local state, not durable storage across app closure. Page-editor behavior is unchanged. The remaining short native audit will check the preexisting generic error/recovery-text path and malformed checkpoint feedback; readiness is withheld until that audit and required independent review/fixes finish. Billing/commercial authorization, clean-Mac sign-in and human usability are not established by these controls.
