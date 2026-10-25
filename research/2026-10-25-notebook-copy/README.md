# SOP9 — plain-folder copy and restore

The feature exposes the actual notebook folder through a small visible Notebook actions ellipsis menu (also available by right-clicking its title), and gives quit/copy/restore guidance. Finder performs ordinary folder copies; there is no archive/import format, automatic backup or concurrent sync claim.

## Sources and disposable data

Native copy/continue used uncommitted app source subsequently committed as `c60aba1` (identical app files), based on `9a764bc` (SOP46). Final brief integration inspection used `b58f31f`, which merges Connection & Data main `b2dfa1d`; only README append and check-registration conflicts required combining both sides. No connection, engine, source permission, goal, evidence, or inner-scroll code was changed by this feature.

A quit, disposable SOP23 library was copied to `/tmp/sophia-copy-source/library`, then copied as a whole to `/tmp/sophia-copy-restored-ui/library` before opening. It contains the actual earlier guitar and Fourier/windowing pages, labeled synthetic Position A/B links and earlier labeled fixtures. Original study directories and the personal app/library were untouched. Only notebook data was copied: no authentication/configuration/cache files.

## Observed results

- All **23 files** matched SHA-256 before opening the restored library, including its hidden `.sophia` data. Folder names and relative identities were kept.
- Native launch enumerated the restored notebooks, chapters, pages, provisional goal, notes and conversation. The existing windowing page opened and rendered.
- The ellipsis menu opened Copy & Restore at 900×600. The sheet’s text and all actions fit. An initial icon-only Menu label was not visible in the original screenshot; using an explicit textual ellipsis made the actions discoverable. The final label is accessible as Notebook actions, with per-notebook help.
- Show Notebook in Finder was invoked through its actual native button, targeting the restored notebook URL. A separate Finder AppleScript selection query did not return; only that captured query PID was terminated. Its external selection confirmation is **inconclusive**. No claim is made that this query verified Finder’s selection. The action’s exact URL and NSWorkspace call were separately source-inspected.
- An ordinary explicit question in the restored windowing page asked why a finite window broadens a spectral line. The actual response explained product-in-time/convolution-in-frequency and the window’s spectrum (269 characters), followed by a client `replied` record. There were no tool records in this turn. This is a completed ordinary inquiry continuation, not a readiness/model preflight.
- After the completed turn, **only** `Fourier analysis/transcript.jsonl` differed from the pre-open manifest. All original page/previous-version, learning/correction/goal, ordering/identity metadata and shared files stayed byte-exact. The source backup stayed unchanged.
- On the final integrated main, the first-use connection card and notebook ellipses remained reachable at 900×600, and the help sheet still fit. Opening Position A’s inactive-notebook actions/help retained Fourier as the active notebook (its Transforms rows remained expanded): the menu is a sibling of the navigation button, not a nested hit target.
- Every app exited via native Cmd-Q and was verified gone; no model request remained active on GUI release. Native menus pause the debug harness’s default-mode timer, so normal menu selection used mouse plus keys targeted solely at the captured app PID. No private app/store test action was added.

## Focused storage checks

`swift run sophia-checks`: **all 76 passed** after integrating main (74 existing + two copy checks). The new checks exercise production stores and ordinary FileManager folder copy:

- Whole-notebook bytes before open; chapters/page ordering; transcript and learning records; confirmed goal/criteria and evidence references; a person correction’s original target; durable recorded page Undo using the copied previous version; deleted-record high watermark surviving a subsequent write; source backup unchanged by continuing or Undo on the restore.
- Whole-Library bytes including hidden `.sophia`; shared About you records; confirmed cross-notebook link and read permission; notebook enumeration under preserved names.

Early fixture assertions incorrectly compared a body without its stored trailing newline and sliced URL paths whose resolved prefixes differed; those test assumptions were corrected to normalized body text and enumerator-relative paths. No production storage change was needed.

## Limits

Actual native continued inquiry is not a human comprehension study or clean-Mac installation test. The copy was made by ordinary filesystem folder-copy operations, not a scripted Finder clipboard interaction. Finder reveal’s external automation check is inconclusive as above. CLI/provider access and defaults were unchanged; no billing or commercial conclusion follows.

A notebook alone excludes shared About you/links; moving everything requires the enclosing Library and hidden `.sophia`, with linked notebook names preserved. Copy only while Sophia is quit. Unsent composer drafts and pending in-memory Undo for deleted learning records are not backed up. A single previous page slot is not unlimited version history. Import/merge, cloud conflicts and concurrent sync remain unsupported.

## Review correction

The adaptive review verified all76 checks and the debug build, with no blocker. Its one Low FIX NOW was the missing ordinary return-request caveat: a restored backup older than six hours can start the existing return path after acknowledgement and add records. README now states this and keeps the original backup outside the Library. Native continuation deliberately used a huge return threshold to isolate explicit inquiry; it was not proof that a normal restore never sends automatically. The guidance also says to let any reply finish before quitting, because whether a child can finish writing after a mid-reply quit remains an unverified SOP7 lifecycle risk; no engine change is part of this PR. The earlier help screenshot predates that short first-step clause.
