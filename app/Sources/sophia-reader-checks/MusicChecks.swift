import AppKit
import SophiaReader
import WebKit

/// Music on pages (MUSIC.md): ABC fences typeset by the bundled abcjs, after sanitizing,
/// with no network; warnings shown and reported; titles as text; copying and the editor.
@MainActor enum MusicChecks {
    typealias Failure = ReaderChecks.Failure

    static func run(_ document: ReaderDocument, js: (String, [String: Any]) async throws -> Any?,
                    expect: (String, String) async throws -> Void) async throws {
        var reports: [[ReaderMusic]] = []
        document.onMusic = { reports.append($0) }
        func settle(_ ms: Int = 120) async throws { _ = try await js("await new Promise(r => setTimeout(r, \(ms)));", [:]) }
        /// Renders a page and waits until its tunes are drawn.
        func render(_ source: String, tunes: Int) async throws {
            document.update(source: source)
            for _ in 0..<100 {
                if try await js("return content.querySelectorAll('figure.abc[data-drawn]').length === n && !!content.textContent", ["n": tunes]) as? Bool == true { break }
                try await settle(50)
            }
            try await expect("content.querySelectorAll('figure.abc[data-drawn]').length === \(tunes)", "Expected \(tunes) typeset tunes")
        }

        // The resizing check above left the reader narrow; read music at the book's width.
        document.webView.setFrameSize(NSSize(width: 660, height: 700))
        _ = try await js("window.blocked = []; document.addEventListener('securitypolicyviolation', e => window.blocked.push(e.blockedURI));", [:])
        // abcjs isn't loaded for pages without music.
        try await expect("!window.ABCJS && !window.sophiaMusic", "abcjs loaded for a page without music")
        let sample = try String(contentsOf: Bundle.module.url(forResource: "music", withExtension: "md", subdirectory: "Fixtures")!, encoding: .utf8)
        try await render(sample, tunes: 2)
        try await expect("content.querySelectorAll('figure.abc .abc-music svg').length === 2", "Each tune draws an SVG")
        // WebKit keeps no resource timing for file: loads, so an empty list proves little. Also
        // count requests the policy blocked, and check where the scripts came from.
        try await expect("[...document.scripts].some(s => s.src.startsWith('file:') && s.src.endsWith('/vendor/abcjs.min.js')) && [...document.scripts].every(s => s.src.startsWith('file:'))", "abcjs came from the bundle")
        try await expect("performance.getEntriesByType('resource').every(e => e.name.startsWith('file:')) && window.blocked.length === 0", "Rendering music made a network request")
        try await expect("!content.querySelector('style, foreignObject, script') && !document.querySelector('.abc-scratch')", "Sanitized SVG only; no scratch left behind")
        try await expect("content.querySelector('.katex') && content.textContent.includes('Between the tunes.') && content.textContent.includes('After the tunes.')", "The rest of the page renders")
        try await expect("[...content.querySelectorAll('svg text')].some(t => t.textContent.includes('Fixture melody')) && [...content.querySelectorAll('svg text')].some(t => t.textContent === 'sev-')", "Title and lyrics are text in the SVG")
        try await expect("content.querySelector('figure.abc svg').getAttribute('fill') === 'currentColor'", "Music follows the text color")
        try await expect("(() => { const f = content.querySelector('figure.abc'); const svg = f.querySelector('svg'); return f.getAttribute('aria-label') === 'Music: Fixture melody' && svg.getAttribute('aria-hidden') === 'true' && f.querySelector('.abc-source').textContent.startsWith('X:1') && svg.getBoundingClientRect().height > 60 && svg.getBoundingClientRect().width <= content.getBoundingClientRect().width + 1; })()", "Labelled, sized to the column, source kept for VoiceOver")
        try await expect("(() => { const [a, b] = content.querySelectorAll('figure.abc'); return !a.querySelector('.abcjs-tab-number') && b.querySelectorAll('.abcjs-tab-number').length >= 8; })()", "Tablature draws a tab line only where asked")
        try await expect("!content.querySelector('.abc-warnings')", "A valid tune shows no warnings (unknown options are ignored)")
        guard reports.allSatisfy({ $0.allSatisfy(\.warnings.isEmpty) }) else { throw Failure(description: "A page without warnings reported some: \(reports)") }

        // Copying a rendered tune gives its ABC fence, alone or with the prose around it.
        func copy(_ select: String) async throws -> String {
            try await js("""
                const range = document.createRange();
                \(select)
                getSelection().removeAllRanges(); getSelection().addRange(range);
                const data = new DataTransfer();
                document.dispatchEvent(new ClipboardEvent('copy', { clipboardData: data, cancelable: true, bubbles: true }));
                return data.getData('text/plain');
                """, [:]) as? String ?? ""
        }
        let lines = sample.components(separatedBy: "\n")
        let fence = lines[4...12].joined(separator: "\n")
        let copied = try await copy("const t = content.querySelector('svg text'); range.setStart(t.firstChild ?? t, 0); range.setEnd(t.firstChild ?? t, 1);")
        guard copied == fence else { throw Failure(description: "Copying a tune gave \(copied.debugDescription)") }
        let mixed = try await copy("range.setStart(content.querySelector('figure.abc svg text'), 0); const p = [...content.querySelectorAll('p')].find(p => p.textContent.startsWith('Between')); range.setEnd(p.firstChild, 7);")
        guard mixed.hasPrefix(fence), mixed.hasSuffix("Between"), !mixed.contains("Fixture melody\n") || mixed.contains("T:Fixture melody") else {
            throw Failure(description: "Copying a tune with prose gave \(mixed.debugDescription)")
        }

        // Markup in titles and lyrics stays text; nothing in it runs or loads.
        try await render("""
        ```abc
        X:1
        T:<script>window.injected = 1</script><b>Bold</b> & <img src=x onerror="window.injected = 2">
        K:C
        CDEF|
        w: <i>lyric</i>
        ```
        """, tunes: 1)
        try await expect("!window.injected && !content.querySelector('script, img, b, i, foreignObject')", "Markup in a tune ran or rendered")
        try await expect("[...content.querySelectorAll('svg text')].some(t => t.textContent.includes('<script>window.injected = 1</script><b>Bold</b>'))", "The title should appear as text")
        try await expect("[...content.querySelectorAll('svg text')].some(t => t.textContent.includes('<i>lyric</i>'))", "Lyrics should appear as text")
        try await expect("content.querySelector('figure.abc').getAttribute('aria-label').startsWith('Music: <script>')", "Label from the title, as text")

        // A malformed tune: drawn with its warnings listed; the rest of the page still renders.
        reports = []
        let broken = "Before.\n\n## Tunes\n\n```abc\nX:1\nT:Broken\nK:C\nCD@E F| G2 &&& A\n```\n\nBetween $y$.\n\n```abc\nX:2\nK:C\nCDEF|\n```\n\nAfter."
        try await render(broken, tunes: 2)
        try await expect("content.querySelectorAll('figure.abc')[0].querySelectorAll('.abc-warnings li').length >= 1 && !content.querySelectorAll('figure.abc')[1].querySelector('.abc-warnings')", "Warnings are listed under the malformed tune only")
        try await expect("!content.querySelector('.abc-warnings').open && content.querySelectorAll('figure.abc svg').length === 2", "Warnings start collapsed, and both tunes draw")
        try await expect("content.querySelector('.katex') && content.textContent.includes('After.') && content.querySelector('h2')", "The rest of the page renders around a malformed tune")
        guard let report = reports.last, report.count == 2, report[0].line == 4, report[0].title == "Broken", !report[0].warnings.isEmpty,
              report[1].warnings.isEmpty, !report[0].warnings.contains(where: { $0.contains("<") }),
              report[0].warnings.first?.hasPrefix("Line 4 of the tune, column 3: Unknown character ignored") == true else {
            throw Failure(description: "Warnings didn't reach the app as text with their line: \(reports)")
        }
        print("Malformed tune warnings: \(report[0].warnings)")
        try await render("No music now.", tunes: 0)
        guard reports.last == [] else { throw Failure(description: "A page without music didn't clear the warnings") }

        // A hard failure (synthetic: abcjs throwing) shows the source, bordered.
        _ = try await js("const f = document.createElement('figure'); f.className = 'abc'; content.append(f); sophiaMusic.draw(f, 'K:C\\nC', { failed: 'abcjs failed.', warnings: [], svgs: [] });", [:])
        try await expect("(() => { const f = content.querySelector('figure.abc-failed'); const pre = f.querySelector('.abc-source'); return pre.getBoundingClientRect().height > 10 && getComputedStyle(pre).borderTopStyle === 'solid' && pre.textContent === 'K:C\\nC' && f.querySelector('.abc-warnings li').textContent === 'abcjs failed.'; })()", "A failed tune shows its source, bordered")

        try await editorChecks(document, sample: sample, js: js, expect: expect)
        try await expect("window.blocked.length === 0", "Something was blocked by the content policy")
        print("Verified music: abcjs offline and lazily, sanitized SVG, tablature, titles and lyrics as text, warnings shown and reported, copying, failure, editor preview")
    }

    /// The editor on a page with tunes: an untouched round trip is byte-exact, and the tune at the caret is previewed.
    static func editorChecks(_ document: ReaderDocument, sample: String, js: (String, [String: Any]) async throws -> Any?,
                             expect: (String, String) async throws -> Void) async throws {
        var events: [ReaderEditEvent] = []
        document.onEdit = { events.append($0) }
        func settle(_ ms: Int = 120) async throws { _ = try await js("await new Promise(r => setTimeout(r, \(ms)));", [:]) }
        let page = "Opening.\n\n" + sample
        let editor = ReaderEditor(id: "music-1", label: "the page", start: 0, end: page.components(separatedBy: "\n").count, text: page, hash: "h")
        document.update(source: page, editor: editor)
        for _ in 0..<60 {
            if try await js("return window.sophiaEditor?.id === 'music-1'", [:]) as? Bool == true { break }
            try await settle()
        }
        try await expect("!document.querySelector('.cm-music-preview')", "No music preview until the caret is in a tune")
        let started = Date()
        _ = try await js("const v = sophiaEditor.view(); v.dispatch({selection: {anchor: v.state.doc.toString().indexOf('dedB')}}); v.focus();", [:])
        for _ in 0..<40 {
            if try await js("return !!document.querySelector('.cm-music-preview svg')", [:]) as? Bool == true { break }
            try await settle(25)
        }
        try await expect("document.querySelectorAll('.cm-music-preview svg').length === 1", "The tune at the caret is previewed")
        print("Music preview appeared in \(Int(Date().timeIntervalSince(started) * 1000)) ms (typeset before, so cached)")
        // Breaking the tune shows its warnings in the preview once typing pauses, and keeps the old drawing meanwhile.
        _ = try await js("const v = sophiaEditor.view(); v.dispatch(v.state.replaceSelection('@ '));", [:])
        try await settle(60)
        try await expect("document.querySelector('.cm-music-preview svg') && !document.querySelector('.cm-music-preview .abc-warnings')", "The preview waits for typing to pause")
        try await settle(400)
        try await expect("document.querySelector('.cm-music-preview svg') && document.querySelector('.cm-music-preview .abc-warnings li')", "The preview shows the new tune's warnings")
        _ = try await js("const v = sophiaEditor.view(); v.dispatch({selection: {anchor: 0}});", [:])
        try await settle()
        try await expect("!document.querySelector('.cm-music-preview')", "The preview goes when the caret leaves the tune")
        // Undo the typing; Done with nothing changed returns the exact bytes.
        _ = try await js("sophiaEditor.undo(); sophiaEditor.undo();", [:])
        try await settle()
        events = []
        _ = try await js("const v = sophiaEditor.view(); if (v.state.doc.toString() !== v.initialDoc.toString()) throw new Error('undo'); document.querySelector('.strip button').click()", [:])
        try await settle()
        guard case .commit("music-1", _, let back)? = events.last, Array(back.utf8) == Array(page.utf8) else {
            throw Failure(description: "The editor changed a page with music: \(events)")
        }
        document.update(source: page + " ", editor: nil)
        try await settle()
    }
}
