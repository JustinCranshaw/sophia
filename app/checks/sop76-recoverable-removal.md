# SOP76: person-owned recoverable removal

Implemented from main `75a8eb1` in an isolated worktree. The original dirty checkout and earlier user build were untouched. No provider/auth/backend changes or live provider requests were made for this issue.

## Implemented boundaries

Ordinary content pages, including Almanac entries, use Delete Page… in the existing page-header menu and sidebar context menu. A confirmation names the exact target/notebook, the recovery list, retained history, stopped activity and retired links. Required introductions, Goals, Notes, Working memory and About retain their page identity; their disabled menu explains clearing through Edit. No chapter cascade or permanent page purge.

Deleted Pages… restores exact current/previous bytes and filing, refusing different destination bytes. Original transcripts/evidence and archive copies remain. Whole notebooks use macOS Trash after exact owned writers drain. A removed Almanac is saved disabled. Removed identity link grants retire without discarding history, and Almanac theme selections remove deleted notebook names. Recovery requires adding/confirming links again.

## Observed checks

- `swift run --package-path app sophia-checks`: **all 128 passed**. New checks exercise current/previous bytes and chapter position, no stale filename resurrection or old Undo, required roles, archive failure, open editor, interrupted physical leftovers, restore collision, moved/replaced/Put-Back directory identity and generation, retired grants and same-name creation collisions, deleted Almanac readiness. Existing controlled process checks additionally verify `whenStopped` runs only after the exact owned parent/child drain. No real provider process was needed.
- `app/scripts/make-app.sh debug`: native app and adjacent MCP built. Local output logs are `/tmp/sophia-deletion-core-final.log` and `/tmp/sophia-deletion-bundle-final.log`.
- Native debug harness, isolated bundle identity `dev.sophia.ux.deletion.20261028`, disposable Library `/tmp/sophia-native-deletion-ux/run1/library`: actual long-title confirmation, Cancel unchanged, selected page Delete → next page, Restore from Deleted Pages to original position, last page → Contents empty state, unresolved personal edit conflict blocked deletion with both draft and external bytes preserved, explicit Revert, unselected notebook Trash kept current selection, Almanac Trash → next notebook, last notebook Trash → empty Library.
- Native Almanac Trash returned an exact OS receipt for the disposable folder; original was absent and archived settings had `enabled: false`. With the app normally quit, only that receipt-identified folder was moved back to its empty original destination. Cold reopen showed disabled preparation. Deleting its synthetic entry removed current readiness. This verifies documented folder recovery, **not the Finder Put Back gesture itself**. Other receipt-identified disposable Trash targets were also recovered while quit; no personal Trash items were enumerated or changed.

Native artifacts are under `/tmp/sophia-native-deletion-ux/run1/results/`:

| State | PNG suffix |
|---|---|
| Revised page confirmation | `1793213231399653000-8c8e1f.png` |
| Revised recovery list | `1793213248862329000-d5a0f7.png` |
| Settled next-page body | `1793213238963090000-5f8e26.png` |
| Kept draft after refused Delete | `1793213286958428000-eaaba3.png` |
| Almanac Trash confirmation | `1793213329929453000-8f996b.png` |
| After Almanac Trash | `1793213336495104000-da7344.png` |
| Last page → empty Contents | `1793213459767031000-fc5331.png` |
| Unselected notebook removed | `1793213483696133000-69f18c.png` |
| Recovered disabled Almanac; entry removed | `1793213500827887000-92e080.png` |
| Last notebook → empty Library | `1793213530062739000-6b3669.png` |

## Design and limits

Official Claude Code 2.1.310 resumed the established Mara/Marcus/Imani standard convergent charrette with canonical `claude-opus-5-5` observed in message streams and high effort configured (not independently measured). The first actual-render critique found missing link-retirement disclosure in the page confirmation. The revision adds explicit “added and confirmed again” wording and local deletion dates; the same voices inspect the revised states. No new branding or layout mode.

The missing-CLI banner is intentional synthetic fixture setup. Header-menu deletion was exercised natively; a temporary right-click harness attempt was ineffective and reverted, so sidebar context-menu interaction is source-verified, not claimed as an automated native pass. Required-page menu deletion was unavailable; disabled explanation is additionally source-verified. VoiceOver, physical mouse/trackpad behavior, permanent purge and external simultaneous Library mutation are not established. This is recoverable removal, not a privacy erasure feature. Provider billing and commercial eligibility are unrelated and remain inconclusive.
