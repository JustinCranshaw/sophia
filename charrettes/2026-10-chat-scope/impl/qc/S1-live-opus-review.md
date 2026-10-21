I found one Medium and three Low issues, no blocking defects, and no product behaviour changes. This comes from reading the source only. I didn't run the build, the core checks or the live check, so none of this is evidence the live run passes.

**Scope.** The diff touches only `app/Sources/sophia-checks/LiveRun.swift`, which matches the git status. Storage, `NotebookStore`, `sophia-mcp`, the prompts, provider access and the S1 app code are unchanged.

## The questions in the brief

- **Does the request force a real revision?** Yes. The line to add carries a marker built from a fresh UUID just before the turn (`LiveRun.swift:160-161`). The guard at `:162` confirms it isn't already on the page. So a page that already explains bridge endpoints can't pass by doing nothing.
- **Is the revision new, not an old event?** Yes. Only page-write entries created after the turn count (`:156`, `:168`). Refused writes are left out of `pageWrites`, so a turn that only gets refused fails.
- **Can a different or extra page pass?** No. Every new successful write must be a revision of the same file (`:172`), and the page set must be unchanged (`:171`). Creating a page or revising a different one fails.
- **Is the new content really saved?** Yes. The saved file must begin with the exact old bytes (`:174`) and contain the question as a whole line (`:175`). The latest revision's recorded hash must match the file on disk (`:176`). This fits how `writePage` builds files (`NotebookStore.swift:502`) and how `read_page` returns the body (`sophia-mcp/main.swift:167`).
- **Is the previous version exact?** Yes. `.previous.md` must equal the old bytes exactly (`:177-178`), the same assertion the core checks make (`main.swift:467`).
- **Are earlier checks kept?** Yes, and made stricter. The old check accepted any revision ever recorded and only printed FAIL; the new one exits with status 1. The "previous version kept" line is still printed. The later P-origin check (`:183-197`) is unchanged and can't be satisfied by the session-2 revision, because that entry's `page` is `""`, not `p`.

## Findings

**1. Medium: the check no longer tests whether Sophia chooses to revise a page in place.** `LiveRun.swift:166`
- The old request was ordinary speech ("Please add that to the page"). It tested the behaviour SOPHIA.md:64 asks for: revise the page in place instead of writing a near-duplicate.
- The new request names the file, the `write_page` tool and its `page` argument. It now tests whether the tool works and whether the model follows instructions, not Sophia's own judgment.
- The P-origin request at `:186` is scripted the same way, so no live check now covers that judgment at all.
- **Failure scenario:** a prompt change makes Sophia answer "please add this to the page" by creating a new page. Both live checks still pass.
- **Possible fix:** say the request the way a person would ("I have a new question for the page on …; please add it at the end: <line>"), without naming the tool or argument, and keep all the new assertions. Or keep the request as is and record that this judgment isn't covered live.

**2. Low: correct revisions can fail on exact-copy details.** `:174`, `:177-178`
- The tool has no append mode, so the model has to retype the whole page byte for byte: title, LaTeX, whitespace, and the trailing newline that `read_page` returns.
- Two things fail a revision that is substantively right:
  - dropping the trailing newline from the existing content before adding the line;
  - saving the page twice in one turn, which leaves `.previous.md` holding the first attempt instead of the original.
- This is strictness, not a false pass, and it's arguably what "keep all existing content exactly" asks for. If it fails, read it as a possible copying slip before concluding the revision behaviour is broken.

**3. Low: the new hard exit hides the P-origin result.** `:179`
- Other failures in `runLive` (`:103`, `:118`, `:135`) print FAIL and carry on. This one stops the run, so the P-origin check (`:183-197`) never runs.
- An exit status of 1 is correct here. But one live run then tells you nothing about P-origin.
- Before this change, the run could exit 0 even after printing FAIL for goals, the checkpoint or the briefing. That's still true and isn't caused by this diff, but treat any FAIL line in the output as a failure, not just the exit status.

**4. Low (minor): one read can crash instead of failing cleanly.** `:158`
- `try! Data(contentsOf:)` traps if the session-1 page is gone by then. The process still exits non-zero, just without a FAIL message.
- In this flow that's unlikely, since nothing can delete pages.

## Not checked

Rebuilding, rerunning the core and live checks, the native Gate B checks, how the model actually behaves, billing, and native routing and focus all remain for you to run.
