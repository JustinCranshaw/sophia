# SOP39 — partial local packaged-release verification

**Partial, not a release/completion claim.** These nonprovider checks ran on source `b2dfa1d6cb5a718917a8c9372273cc2157752c6b` in `/tmp/sophia-release-verification`. Later evidence/copy changes (PR15/16) and SOP48 are not in this binary. The final provider sequence is explicitly reserved until SOP48 lands; no native UI send, model/tool delivery through the app, billing route or SOP4/SOP7 completion is inferred here.

## Exact local environment and commands

macOS **26.2 (25C56)**, arm64; Apple Swift **6.2.3** (`swiftlang-6.2.3.3.21`, clang1700.6.3.2), swift-driver1.127.14.1; Node **26.0.0**. Installed official Claude Code reports **2.1.304**; no actual model engine was launched for this verification. No provider adapter/SDK/dependency was changed.

From repository root:

```sh
sh app/scripts/make-app.sh release
swift run --package-path app sophia-checks
node app/reader/check.mjs
codesign --verify --deep --strict app/build/Sophia.app
```

From `app/` in the reserved desktop slot:

```sh
SOPHIA_READER_SNAPSHOT=/tmp/sophia-release-reader-math.png swift run -c release sophia-reader-checks
swift run -c release sophia-reader-checks --scroll-spike
```

Targeted app/MCP builds are intentional: generic release-all attempts to compile the existing `@testable` core checker target without testing enabled. No successful full release-all build is claimed.

## Layered results

| Layer | Observed result | Boundary |
|---|---|---|
| Packaging | Release Sophia + sophia-mcp built and packaged; local strict/deep signature verification passed. Thin arm64 bundle, identifier com.sophia.notebook, deployment minimum14.0; signature ad-hoc, no TeamIdentifier. | Not Developer ID signing, notarization, Gatekeeper, Intel or clean macOS14 proof. |
| Assets | All39 packaged reader files match source hashes; SOPHIA.md is byte-exact. Local fonts/licenses/scripts included. Debug UX bridge and missing-CLI marker absent from release executable. | Resource hashes and binary markers are packaging checks, not runtime tool capability proof. |
| Core | All74 existing checks passed, including protected edits/quotes, verified evidence, confirmed goals, corrections/deletion/IDs, two writers, interrupted writes/recovery/orphans and scoped tool rules. | Reuses focused store proof; these are debug-built core checks, not native release UI or provider proof. |
| Parser | Node parser checks passed for Markdown/math/code/invalid and streamed delimiters/restricted commands/ABC placeholders. | Parser-only, not native rendering, accessibility or sanitization by itself. |
| Release WebKit reader | Actual release reader executable passed math/MathML/TeX, local fonts, malformed/streamed math, DOM isolation/sanitization, resize, source editor exact CRLF/tab/list/math roundtrips, invalid input/revert, and music/tab/warnings/copy/editor preview. Resource requests were file-only in the checked documents. | Separate existing reader executable sharing SophiaReader; no model. This is not all app interaction or system-network-off testing. |
| Release editor scroll | Existing release scroll spike passed: caret never offscreen; growth/shrink/below-editor changes moved editor/caret0pt and retained text. | Reader/editor executable, not the packaged app’s personal-edit/Undo workflow. |
| Direct packaged MCP | Actual `Sophia.app/Contents/MacOS/sophia-mcp` initialized/listed9tools, created and revised the labeled fixture, retaining exact previous bytes. Unknown delete_page/delete_learning requests returned Unknown tool, page bytes unchanged. Injected status:met/by:person on set_goal still produced provisional by:sophia/status:working. | Direct newline JSON-RPC, no model or app UI delivery. |
| Actual release process | Binary launched against disposable library; PID-scoped native Cmd-Q exited it. No provider request ran. | Page controls/edit/Undo/selection could not be safely verified externally, as described below. |
| Static release views | Existing Snapshot aid exported light1440×900 and dark900×600 app views. Original PNG inspection shows readable math, staff and guitar tab, the source-link label and the expected layout. | Snapshot sets navigation internally, so these are actual release rendering but **not native action/reflow/copy evidence**. |

## Disposable data and static rendering

The direct-MCP fixture in `/tmp/sophia-release-ui/library/Release reading` is visibly labeled synthetic, with Markdown, integral/inline math, ABC guitar tab, a synthetic example.invalid link, raw script text and code kept inert. A second notebook is a whole copy of the earlier disposable long-conversation fixture (labeled synthetic material plus an actual prior answer), not a new model result. No personal files, authentication/cache data or provider settings were copied.

Snapshot used only documented `SOPHIA_SNAPSHOT`, library/size/appearance/section variables. The displayed post-disclosure music section used the process-local Foundation argument `-connectionInformationAcknowledged YES`; first-use rendering used NO. This changes no persistent preference and proves no acknowledgement or connection behavior. No auth check ran. App appearance was process-local, not a system light/dark change. Each Snapshot process exited0 and exported5PNGs; selected original-resolution page captures are committed here. Source HTML/scripts remain text in the actual isolated reader tests; no generated code was executed as an artifact.

## Precise native accessibility boundary

Read-only permission checks showed external Accessibility and event posting already permitted, Screen Recording not permitted, and VoiceOver not running. No permission was requested or changed, and VoiceOver was not enabled for coverage.

A temporary external PID-scoped standard AX driver queried the actual release process. AXWindows and AXFocusedWindow returned application-self objects; recursive enumeration exposed app/menu roles, no usable notebook controls. AXEnhancedUserInterface already read1; its standard setter returned -25208(unsupported). Investigation stopped after that bounded check. This is an observed **driver/API boundary**, not an independent diagnosis of app accessibility or VoiceOver. No blind UI typing or private release hook was added. Native Cmd-Q was verified, but page edit/Undo, focus, selection/copy and real browser-link activation remain unverified in the packaged app.

## Still required

- Integrate landed SOP48 and rerun the changed final packaged route slice; do not relabel these earlier binaries as final-route proof.
- A bounded actual model write/revision sequence on that resulting package, with model/tool delivery separated from direct-MCP evidence. If only a live checker is available, label it as such, not native UI use.
- Actual packaged-app direct personal edit/Undo and the interaction boundaries above; basic VoiceOver and human accessibility/readability remain open.
- Clean Mac, distribution signing/notarization/publishing, commercial authorization and billing attribution remain separate. Naturally useful return and full SOP7 cancellation are not established.

Local logs: `/tmp/sophia-release-{package,core,parser,reader,scroll}.log`; direct MCP requests/results and fixture bytes under `/tmp/sophia-release-ui/`. No credentials or raw auth output are in the report/artifacts.
