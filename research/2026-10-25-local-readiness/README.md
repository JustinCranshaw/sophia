# SOP47 — local installation/login readiness

Implementation source `957f082377da1e2368237473543e2406c3a3c21e`, based on landed SOP46 main `9a764bc`. Native app/driver: debug bundle in `/tmp/sophia-connection`, isolated harnesses `/tmp/sophia-connection-*-ui`, copied disposable non-sensitive notebook from the prior reading-position exercise. No personal library/app, credentials or authentication configuration were copied. The status check itself is not a model preflight.

## Observed native results

- Existing notebook, accelerated return threshold **0**: the first-use information appeared before any automatic request. The existing conversation/pages and composer remained reachable at 900×600. No CLI child existed; all preexisting notebook file hashes stayed identical through first opening, an unsent draft and Keep reading. Dismissal retained the draft and started no process/request.
- Recheck in Details explicitly ran the real installed CLI's local auth status, in an empty temporary directory with provider environment exclusions. UI showed ready to attempt a request; notebook file hashes stayed identical. Only constant allowlisted labels were retained. `local-status.png` is this actual installation/login status, using the initial longer card copy. It proves neither a model call nor the effective route of another working directory.
- Unknown and signed-out screenshots are **synthetic status fixtures**, visibly labeled. The missing-engine test used the existing debug `--without-claude` launch fault as well as a labeled missing status. It saved the actual ordinary question and displayed Retry. These are not a clean-Mac or real signed-out installation test.
- On relaunch without the missing-engine fault, explicit Retry answered the saved question through the existing provider path (242-character answer and client `replied` record), with **no extra person record**. This was an ordinary question recovery test, not a readiness probe.
- After acknowledgement and that completed answer, a later relaunch with accelerated return threshold **0** produced the existing checkpoint and briefing records. `informed-return.png` shows this actual provider result. This establishes the informed return path, not a naturally elapsed six-hour return.
- All test apps exited by native Cmd-Q, verified gone. No model request remained active on GUI release.

## Rendered critique and revision

The first 900×600 render was readable but the card used internal verification wording about billing/commercial proof and did not directly explain separate usage. The primary card was shortened to local files/no Sophia account, installed Claude Code/account, explicit and automatic context, web permission, and separate Claude plan limits/charges. Detailed route/evidence limitations moved to Details. `first-use-900.png` and `details.png` show the revised source at `957f082`; `dismissed-draft.png` shows the exact unsent draft after Details → Keep reading. Earlier synthetic/status/recovery captures predate this copy revision; their state/process code is identical.

## Checks and limits

- `swift run sophia-checks`: all **74** checks passed, including strict JSON types, missing/unsupported/alternate route fields, nonzero/malformed process output, timeout, oversized output, launch failure, exact arguments and provider environment exclusions.
- Debug app/MCP bundle passed. `swift build -c release --product Sophia` passed (33.54s); this targets the app product, not the inherited release checker target's `@testable` limitation.
- No auth mutation, credential/cache reads, installation, API fallback or readiness model probe occurred. No raw auth output or account identifiers are in these artifacts.
- The helper accepts an exact executable, caller cwd and scrubbed environment for SOP48. This UI checks installation/login in an empty cwd; it does **not** enforce or guarantee every notebook's effective request route. Existing pre-send enforcement is a separate task.
- SOP29 clean-Mac and human comprehension, SOP30 commercial route/billing, and natural return usefulness remain open. A local login result, an ordinary successful reply and a tool invocation are distinct evidence.
