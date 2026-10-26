# SOP68 — selected identity in the native app

Source: isolated `feat/native-brand-system`, based on `feb4d016`; exact PR/review head is recorded in the PR. The original dirty checkout and both retained demos are untouched. No product-provider request, notification permission, sign-in change, installation or deployment was performed.

## Scope and design

The user locked exact DC Trued Channel, solid Plum (`#6E2F55` light / `#E3A9C8` dark), then selected Palatino and a tighter inline gap. The convergent standard Opus 5.5 charrette chose a 20pt mark, 4.4pt gap and 13.3pt Palatino-Roman word in primary text color. The mark is exact generated geometry, not a new drawing; body/UI and reader fonts remain unchanged. Selection reuses the existing 0.18 alpha with Plum; focus, Send, errors, source decisions and recovery stay native/semantic. The application icon and 40pt empty-state mark/CTA are replaceable implementation treatments, not additional user locks.

Official CLI 2.1.310, explicit `claude-opus-5-5`, `--effort high`, process-only `CLAUDE_CODE_EFFORT_LEVEL=high`, and High agent definitions. Lead/child actual message-model metadata is audited separately. Effective effort is not returned. Child agents cannot be resumed in this runtime; replacement Mara/Marcus/Imani voices receive their previous position plus the other two digests. No personal Claude directory enumeration is authorized. The design lead reads native renders and returns directives; the implementation coordinator edits source.

## Observed native evidence

All observations use labeled synthetic disposable Library material. Debug harness launches use the real missing-Claude fault and a high return gap. Connection acknowledgement/Keep reading starts no request. Snapshot uses its existing request-free mode and controlled appearance; the added empty-root branch captures the actual EmptyLibraryView instead of exiting for lack of a session.

- Baseline and first native implementation captured at 1280×800 and minimum 900×600 content sizes, with actual page/Home/About surfaces, in light/dark appearance. Inactive Snapshot windows are identified as inactive; their controls are not evidence of disabled product actions.
- The first navigation-slot lockup collapsed trailing controls left when the plain title was hidden. Generic and explicitly placed flexible spacers compiled but did not fix it. The supported `.principal` slot restores the trailing controls: Connection & Data center 1157.5 and book control center 1252 at 1280; 777.5 and 872 at 900. The compact mark/name is centered over the detail area, without a sidebar masthead.
- A suspected missing plus was mistaken full-image inspection: the exact PNG crop shows it, and native New Notebook opened and Cancel returned normally. Hide/Show Book worked at 900. No controls were removed. A single settled narrow Hide Book retake checks the final state after its animation, rather than relying on the immediate action capture.
- Actual empty-state CTA opened and Cancel returned without a request. Active dark label is dark on pale Plum. Inactive label follows native primary text, avoiding a forced foreground against the system's inactive button fill. Light/dark empty roots were captured. The process-only `-AppleInterfaceStyle Light` attempt did not change appearance and is not counted as active-light proof.
- Native mark raster compared against the exact SVG at 256px: threshold masks differed at 110 of 65,536 pixels (0.168%; source parity is checked separately). The generated source matches all six paths and 36 circular arcs. Source symbol identity and deterministic regeneration are separately checked; raster similarity alone is not source parity.
- Packaged `CFBundleIconFile` is `Sophia`, `Contents/Resources/Sophia.icns` exists, and strict deep signature verification passes. The decoded 1024px embedded bitmap matches the generated source pixels; 18 interior samples across the six petals are exact RGBA `[110,47,85,255]`. Targeted `NSRunningApplication` and `NSWorkspace` APIs captured only the owned running app's published icon and owned bundle's icon. The API-returned icon representation looks shaded/material compared with the flat generated PNG. On-screen Dock/Finder composition was not captured, and no cause for that representation difference is asserted.

Owned renders/logs remain under the task-specific scratch directory reported in the PR; no private raw session logs are committed. macOS 26 native layout is observed. The macOS 14/15 branch is compile-checked only; its layout is unobserved. No VoiceOver, human recognition, release interaction or font-license clearance claim follows.

## Commands and results

- `app/scripts/make-app.sh debug`: Sophia + adjacent MCP build and ad-hoc signature passed.
- `python3 app/scripts/gen-brand-mark.py --check`: exact locked source regeneration passed.
- `swift run sophia-checks` from `app/`: all 108 passed, final one-way Quit gate left last and unchanged.
- `swift run sophia-reader-checks`: reader/editor/math/music/offline checks passed; no reader source changed.
- `codesign --verify --deep --strict app/build/Sophia.app`: passed.
- `git diff --check`: passed.

To deliberately regenerate the committed icon, from `app/`, use a fresh owned scratch directory:

```sh
BRAND_ICON_CHECK=$(mktemp -d /tmp/sophia-brand-icon.XXXXXX)
swiftc Sources/Sophia/BrandMarkPath.swift scripts/make-icon.swift -o "$BRAND_ICON_CHECK/make-icon"
"$BRAND_ICON_CHECK/make-icon" "$BRAND_ICON_CHECK/Sophia.iconset" Resources/Sophia.icns
```

This is a development operation, not a runtime dependency. Do not delete shared temporary fixtures or unrelated build caches.
