# Final native-engine source-denial verification — SOP53 / SOP4

**Observed October 25, 2026:** the one authorized request completed on product main `5ed469f461a23eb24a99002d1e0297ef717569c8`, after SOP51/52/54 landed. This worktree’s product source matched that main exactly. The earlier three-turn no-bridge probe remains unchanged historical evidence in `../2026-10-25-packaged-release/`.

This is a one-purpose research caller, not a new app/test framework. It uses unchanged optimized release SophiaCore objects and the actual packaged MCP executable directly, with the native SourcePermissionBridge, explicit WebFetch ask settings, strict Sophia+approval MCP configuration, route guard, environment/cwd and canOpenSources context. The sole ordinary message requests https://example.com/, forbids search/notebook writes and waits for a decision. Existing `decideSource(...allow:false)` denies the first actual permission request; it never approves, retries or adds a message. Unexpected tools/URLs or another permission request cause denial/stop, not a forced successful result.

Preparation/execution are separate. `setup.py` requires an absent, private run directory, the pinned current main SHA and the actual landed SOP51/SOP52/SOP54 commits. It archives the complete setup/caller/supervisor, compile arguments, package/Core/prompt hashes and exact selected CLI version/path. It compiles the caller and prepares a clearly synthetic local page without constructing an engine. `supervise.py` is the separate one-attempt execution step. An exclusive `request-started` marker permanently prevents reuse, including after an inconclusive result. No old run directory is emptied or reset.

The caller captures actual tool input, permission nonce/generation/tool-use identity, a false decision, callback outcome, provider source result, final reply and bounded stop/registry drain. These are public Core events and copies of the bridge's own fixed-name files; no stdio rewriting or product instrumentation is needed. Private bridge paths are observed rather than assumed to follow TMPDIR. No auth/cache files are inspected or copied, no personal/global settings change, no model selection or billing route changes, and no source-fetch approval is given.

The supervisor queries descendants only from its exact captured caller PID, verifies parent edges plus UID/birth identity, records actual executable paths, and checks captured processes after exit. The 180-second request cap has an eight-second Core cleanup window and 195-second outer ceiling. Emergency signals, if needed, target only still-matching captured identities and are reported as a failed/inconclusive run. No name-wide discovery/cleanup or shared temp deletion is used. Before/after page, previous, ordering and learning hashes must match; transcript changes are distinguished.

Reproduction shape (a fresh authorized run would need its own absent directory; the completed run below must never be reused):

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

## Actual one-request result

The targeted release products Sophia and sophia-mcp were packaged and ad-hoc signed with `sh app/scripts/make-app.sh release`; no release-all checker claim. [Build log](observed/release-build.log), [setup/hash record](observed/setup.json), [actual engine arguments](observed/engine-configuration.json) and the exact archived caller/setup/supervisor are retained in `observed/`. The caller compiled with `swiftc -O` against unchanged release SophiaCore objects and used the actual packaged MCP, without a proxy or protocol rewrite. This is an instrumented CLI caller using native-engine configuration, **not a native-app Send or accessibility observation**.

Actual commands, from `/tmp/sophia-native-source-verification`:

```sh
sh app/scripts/make-app.sh release
python3 research/2026-10-25-native-source-denial/setup.py --repository /tmp/sophia-native-source-verification --run-directory /tmp/sophia-sop53-final-5ed469f --expected-main 5ed469f461a23eb24a99002d1e0297ef717569c8 --require-commit 4ef700a9c4a4eb27723c965301c50de4eaa4ddd9 --require-commit 5ed469f461a23eb24a99002d1e0297ef717569c8 --require-commit ce5f75dfc9a4055c6dced289206ccd4bbb2c53e5
python3 /tmp/sophia-sop53-final-5ed469f/archive/supervise.py /tmp/sophia-sop53-final-5ed469f
```

- Official selected CLI `/Users/justincranshaw/.local/bin/claude`, resolved/version `2.1.304`; actual runtime model `claude-fable-5-1`, `apiKeySource:none`. WebFetch/WebSearch and the nine notebook tools were advertised; only WebFetch was actually requested. No auth caches or credentials were read/copied, no auth/settings/model/route mutation.
- At 14:49:20 UTC, actual WebFetch requested `https://example.com/`. Its sole permission request had nonce `C9FC34C2-99F1-4E99-A154-07B7800A10C5`, generation `59A07EC9-6E35-4CF7-8557-61CAFA679709` and tool ID `toolu_01AJvuLvorWfPf2Dt9kELXsp`. The controlled decision used `allow:false`, matching all three identities. This is a programmatic test denial, not a human decision.
- The actual source result was `isError:true`: “No source content was returned for this request.” The completed reply explicitly said it had not inspected the URL. No source fetch was approved, no source content is claimed, no search or notebook tool was invoked, and no second message/request was sent. [Events](observed/caller.jsonl), [decision](observed/denied-decision.json), [callback outcome](observed/result-outcome.json).
- The turn completed, owned registry drained and bridge disappeared by 14:49:24. The supervisor captured caller47508, CLI47517, packaged MCP47533/47534 with UID/birth/parent edges; all four were absent after exit. No live captured process, zombie or emergency signal remained. Only `transcript.jsonl` changed; protected page/previous-version/order/learning hashes matched exactly. [Caller result](observed/caller-result.json), [supervisor](observed/supervisor-result.json), [owned identities](observed/owned-processes.json).

The first pre-call setup directory `/tmp/sophia-sop53-cc54e59c4933` stopped before compilation/engine construction on raw packaged-MCP comparison. Packaging re-signs its copy. On disposable copies, signature removal left exactly one differing byte, offset3073 within the eight-byte `LC_SEGMENT_64 __LINKEDIT` VM-size field at offset3072: packaged `0x78000`, release product `0x74000`. UUIDs matched `5200eeea89e73fa8b4847e55c4f7a828`; all other stripped bytes matched. The final setup verifies the actual packaged signature, archives raw/stripped hashes and UUIDs, and compares all bytes after zeroing only that VM allocation field on the comparison data. Neither actual executable was modified. [Identity record](observed/mcp-identity.json). The failed directory is preserved, with no request marker; the final fresh directory/archive permanently prevents another attempt.

This closes the narrowly specified current release-Core/native-engine denial topology check. It does not establish successful source extraction, native UI approval/reading, arbitrary service reliability, universal descendant capture, billing attribution, commercial authorization, clean-Mac operation or learning/retention. Prior debug native source-card evidence remains separately attributed to its own source epochs; the earlier no-bridge three-turn probe is unchanged. No additional provider request was made to improve this result.
