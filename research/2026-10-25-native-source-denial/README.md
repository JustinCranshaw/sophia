# Final native-engine source-denial verification — SOP53 / SOP4

**Prepared only. No request has run.** Execution is authorized once SOP51, SOP52 and SOP54 are merged and this worktree contains the resulting current product tree. The earlier three-turn no-bridge probe remains unchanged historical evidence in `../2026-10-25-packaged-release/`.

This is a one-purpose research caller, not a new app/test framework. It uses unchanged optimized release SophiaCore objects and the actual packaged MCP executable directly, with the native SourcePermissionBridge, explicit WebFetch ask settings, strict Sophia+approval MCP configuration, route guard, environment/cwd and canOpenSources context. The sole ordinary message requests https://example.com/, forbids search/notebook writes and waits for a decision. Existing `decideSource(...allow:false)` denies the first actual permission request; it never approves, retries or adds a message. Unexpected tools/URLs or another permission request cause denial/stop, not a forced successful result.

Preparation/execution are separate. `setup.py` requires an absent, private run directory, the pinned current main SHA and the actual landed SOP51/SOP52/SOP54 commits. It archives the complete setup/caller/supervisor, compile arguments, package/Core/prompt hashes and exact selected CLI version/path. It compiles the caller and prepares a clearly synthetic local page without constructing an engine. `supervise.py` is the separate one-attempt execution step. An exclusive `request-started` marker permanently prevents reuse, including after an inconclusive result. No old run directory is emptied or reset.

The caller captures actual tool input, permission nonce/generation/tool-use identity, a false decision, callback outcome, provider source result, final reply and bounded stop/registry drain. These are public Core events and copies of the bridge's own fixed-name files; no stdio rewriting or product instrumentation is needed. Private bridge paths are observed rather than assumed to follow TMPDIR. No auth/cache files are inspected or copied, no personal/global settings change, no model selection or billing route changes, and no source-fetch approval is given.

The supervisor queries descendants only from its exact captured caller PID, verifies parent edges plus UID/birth identity, records actual executable paths, and checks captured processes after exit. The 180-second request cap has an eight-second Core cleanup window and 195-second outer ceiling. Emergency signals, if needed, target only still-matching captured identities and are reported as a failed/inconclusive run. No name-wide discovery/cleanup or shared temp deletion is used. Before/after page, previous, ordering and learning hashes must match; transcript changes are distinguished.

Proposed commands after the product dependencies land (replace the SHA/path placeholders with the actual recorded values, do not run against an existing directory):

```sh
sh app/scripts/make-app.sh release
python3 research/2026-10-25-native-source-denial/setup.py \
  --repository "$PWD" --run-directory /tmp/<new-private-run-name> \
  --expected-main <current-main-sha> \
  --require-commit <landed-SOP51-sha> --require-commit <landed-SOP52-sha> \
  --require-commit <landed-SOP54-sha>
python3 /tmp/<new-private-run-name>/archive/supervise.py /tmp/<new-private-run-name>
```

Observed results, exact source/version/hashes and any limitations must be added after the single run. Unattempted/unavailable means inconclusive. This can verify release-Core/native-engine permission topology and controlled denial, **not native UI, inspected source passages, physical learning/retention, billing attribution or commercial permission**. No additional call is authorized to make a result pass.

Preparation correction: the first pre-call setup stopped on a raw packaged-MCP equality assertion because packaging re-signs its copy. The actual executables were not changed. Setup now verifies the packaged signature, records both raw hashes and Mach-O UUIDs, removes signatures on owned comparison copies, and compares every remaining byte after normalizing only the retained `__LINKEDIT` VM allocation field. The failed setup directory remains preserved; it contains no request marker or model call.
