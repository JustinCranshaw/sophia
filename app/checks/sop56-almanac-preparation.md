# Sophia’s Almanac preparation (SOP56)

Core plus an app-owned preparation worker, before the dependent setup/timer/notification UI. No real provider or OS notification permission is used by these checks. The ordinary companion/model/auth defaults are unchanged.

Run `swift run sophia-checks` and build `swift build --product Sophia` / `swift build --product sophia-mcp`. New checks are before the final one-way pending-status Quit gate. The Almanac checks cover:

- Exact scope canaries and quoted malicious topic data; selected notebook names only, no page/body/history/profile context. Engine argv has WebSearch only, no notebook MCP server/tools or WebFetch, and preserves restriction/route flags.
- Local-day admission across repeated/skipped DST hours, before-time, same-day/reopen contention, skipped week, waiting opening, manual retry/more, and pause-daily semantics. No automatic failure retry.
- Source/target separation and configuration cancellation, stale-save refusal, no conversion of a nonempty ordinary notebook, no learning records.
- Exact recorded-run recovery after a person edit, normal new-page Undo, missing/unknown disk provenance, and no duplicate retry of an already-recorded run.
- Actual stream-event search evidence parsing, idempotent evidence recording, candidate-only HTTP(S) provenance and no model-supplied source URLs. Missing/failed source results cannot justify a search-summary draft; unavailable required passages fail.
- A controlled executable implementing auth-status and stream-json: allowed preparation saves once with actual fake-tool evidence; denied route and cancellation withhold bytes. This is protocol evidence, not a provider call or entry-quality validation.

The worker publishes settings/state/errors and a stable entry run ID. Its `onReady` is only a newly verified durable save, not reopen/reconciliation. Notifications, creation/name collisions, app-open/wake timer wiring and native reading are dependent SOP57 work. Actual generation quality (arithmetic, attribution, freshness, quotations and interpretation) still needs the separately authorized integrated native check; a JSON/schema pass does not establish correctness or learning value.

No shared test directories are removed. Fixtures are disposable non-sensitive material and retained. No source or build evidence claims activation, delayed return or learning outcomes.
