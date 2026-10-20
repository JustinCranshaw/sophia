import AppKit
import SophiaReader
import WebKit

/// Exercises the actual bundled parser, sanitizer, fonts, and WebKit bridge.
/// No Claude process, personal notebook, npm install, or test framework is used.
@main
struct ReaderChecks {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        Task { @MainActor in
            do {
                if CommandLine.arguments.contains("--scroll-spike") {
                    try await EditorScroll.run()
                    exit(0)
                }
                try await run()
                print("Reader checks passed")
                exit(0)
            } catch {
                fputs("Reader check failed: \(error)\n", stderr)
                exit(1)
            }
        }
        app.run()
    }

    struct Failure: Error, CustomStringConvertible { let description: String }

    @MainActor static func run() async throws {
        let document = ReaderDocument()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 660, height: 700),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = document.webView
        // An attached window gives WebKit real layout and font metrics, without
        // activating the app or starting a conversation.
        window.orderBack(nil)
        defer { window.orderOut(nil) }
        var height: CGFloat = 0
        var failure: String?
        document.onHeight = { height = $0 }
        document.onFailure = { failure = $0 }
        for _ in 0..<200 {
            if document.isReady || failure != nil { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        guard document.isReady else { throw Failure(description: failure ?? "Reader didn't become ready") }

        func js(_ body: String, _ arguments: [String: Any] = [:]) async throws -> Any? {
            try await withCheckedThrowingContinuation { continuation in
                document.webView.callAsyncJavaScript(body, arguments: arguments, in: nil, in: .page) {
                    continuation.resume(with: $0)
                }
            }
        }
        func expect(_ expression: String, _ message: String) async throws {
            guard try await js("return !!(\(expression));") as? Bool == true else { throw Failure(description: message) }
        }
        func render(_ source: String) async throws {
            document.update(source: source)
            _ = try await js("await document.fonts.ready; await new Promise(r => setTimeout(r, 50));")
            if let failure { throw Failure(description: failure) }
        }

        let sample = try String(contentsOf: Bundle.module.url(forResource: "math", withExtension: "md", subdirectory: "Fixtures")!, encoding: .utf8)
        try await render(sample)
        try await expect("document.querySelectorAll('.katex').length === 10", "Inline and display math, lists, quotes, and tables")
        try await expect("document.querySelectorAll('.katex-display').length === 3", "Display delimiters and multiline equations")
        try await expect("document.querySelectorAll('math mfrac').length >= 3 && document.querySelectorAll('math mtable').length >= 2", "Structured fractions, matrices, aligned equations")
        try await expect("document.querySelectorAll('math annotation').length === 10", "MathML with original TeX for accessibility and copying")
        try await expect("[...document.querySelectorAll('math semantics > annotation[encoding=\"application/x-tex\"]')].some(a => a.textContent === 'L = D - A') && !document.querySelector('annotation-xml')", "The TeX annotation survives sanitizing; annotation-xml does not")
        try await expect("document.querySelector('pre code').textContent.includes('$$') && document.querySelectorAll('code .katex').length === 0", "Code must stay literal")
        try await expect("document.querySelector('h2') && document.querySelector('strong') && document.querySelector('table') && document.querySelector('blockquote')", "Markdown structure")
        try await expect("document.querySelectorAll('.katex-error').length === 0", "Valid math should not show errors")
        try await expect("[...document.fonts].some(f => f.family.startsWith('KaTeX') && f.status === 'loaded')", "Bundled math fonts loaded offline")
        guard height > 500 else { throw Failure(description: "Height bridge didn't measure the document: \(height)") }

        // Capture the actual WebKit result for visual inspection.
        if let output = ProcessInfo.processInfo.environment["SOPHIA_READER_SNAPSHOT"] {
            let configuration = WKSnapshotConfiguration()
            configuration.rect = NSRect(x: 0, y: 0, width: 660, height: 700)
            let image = try await document.webView.takeSnapshot(configuration: configuration)
            if let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
               let data = bitmap.representation(using: .png, properties: [:]) {
                try data.write(to: URL(fileURLWithPath: output))
            }
        }

        try await render(#"Prices are $5 and $10; escaped \$20. Unfinished math: $\frac{a}{"#)
        try await expect("document.querySelectorAll('.katex').length === 0 && content.textContent.includes('$5 and $10')", "Currency, escaped dollars, and streamed delimiters")
        try await render(#"An invalid formula $\frac{a}{$ then a valid $x^2$."#)
        try await expect("document.querySelector('.katex-error') && document.querySelector('.katex')", "Bad math must not hide the rest of the reply")
        try await render(#"Prefix $x_1"#)
        try await render(#"Prefix $x_1 + x_2$."#)
        try await expect("document.querySelectorAll('.katex').length === 1", "Completing streamed math")

        // Raw HTML is text, links cannot run JS, and TeX cannot load resources.
        try await render(#"""
        <script>window.injected = true</script>
        <img src="https://example.com/tracker" onerror="window.injected=true">
        [bad](javascript:alert(1)) ![Image description](https://example.com/image.png)
        $\includegraphics{https://example.com/tex.png}$
        $\href{javascript:alert(1)}{bad}$
        $\htmlStyle{background:url(https://example.com/track)}{x}$
        """#)
        try await expect("!window.injected && !content.querySelector('script, img, iframe, a[href^=\"javascript:\"]')", "Untrusted HTML, image URLs, and TeX commands")
        try await expect("content.textContent.includes('Image description')", "Image descriptions are retained")
        try await render(#"$\gdef\custom{z}\custom$"#)
        try await render(#"$\custom$"#)
        try await expect("content.textContent.includes('\\\\custom')", "Macros must not leak between documents")

        try await render(String(repeating: "A long reply with $x^2$ and a conclusion about the graph.\n\n", count: 100))
        let wideHeight = height
        document.webView.setFrameSize(NSSize(width: 240, height: 700))
        _ = try await js("await new Promise(r => setTimeout(r, 100));")
        guard height > wideHeight else { throw Failure(description: "Resize didn't remeasure wrapped text") }
        try await render("A short reply.")
        guard height < 100 else { throw Failure(description: "Short replies retained the previous height") }
        print("Verified Markdown, LaTeX, offline fonts, malformed/streamed math, isolation, and resizing")
        try await editorChecks(document, sample: sample, js: js, expect: expect)
        try await MusicChecks.run(document, js: js, expect: expect)
    }

    /// The page editor (EDITING.md): exact round trips, no network, and invalid TeX.
    @MainActor static func editorChecks(_ document: ReaderDocument, sample: String,
                                        js: (String, [String: Any]) async throws -> Any?,
                                        expect: (String, String) async throws -> Void) async throws {
        var events: [ReaderEditEvent] = []
        document.onEdit = { events.append($0) }
        func settle() async throws { _ = try await js("await new Promise(r => setTimeout(r, 120));", [:]) }
        var serial = 0
        func open(_ text: String) async throws -> ReaderEditor {
            serial += 1
            let editor = ReaderEditor(id: "e-\(serial)", label: "§1", start: 0, end: text.components(separatedBy: "\n").count,
                                      text: text, hash: "h")
            document.update(source: text, sections: nil, editor: editor)
            for _ in 0..<60 {
                if try await js("return window.sophiaEditor?.id === id", ["id": editor.id]) as? Bool == true { break }
                try await settle()
            }
            return editor
        }
        func close(_ text: String) async throws {
            document.update(source: text + " ", sections: nil, editor: nil)
            try await settle()
        }

        // Opened and committed with no keystrokes, the text comes back byte for byte.
        let crlf = "## Signs\r\n\r\nThe sign is $-1$.\r\n\r\n$$\r\nx^2\r\n$$\r\n"
        let markers = "## Lists\n\n* star\n+ plus\n1) paren\n\t- tab indented\n  trailing spaces   \n\u{00A0}nbsp and e\u{0301} decomposed"
        for text in [sample, crlf, markers] {
            let editor = try await open(text)
            events = []
            _ = try await js("document.querySelector('.strip button').click()", [:])
            try await settle()
            guard case .commit(let id, let hash, let back)? = events.last, id == editor.id, hash == editor.hash else {
                throw Failure(description: "Done didn't commit")
            }
            guard Array(back.utf8) == Array(text.utf8) else { throw Failure(description: "Editor changed untouched text: \(back.debugDescription)") }
            try await close(text)
        }

        // The editor loads from the bundle under the same policy: nothing from the network.
        _ = try await open(sample)
        try await expect("!!window.CM && document.querySelector('meta[http-equiv=\"Content-Security-Policy\"]').content.includes(\"script-src 'self'\")", "Editor under the reader's CSP")
        try await expect("performance.getEntriesByType('resource').every(e => e.name.startsWith('file:'))", "The editor made a network request")
        try await expect("document.querySelectorAll('.cm-math').length >= 10 && !document.querySelector('.cm-math-error')", "Math source is marked, valid formulas aren't flagged")
        try await close(sample)

        // Invalid TeX: the source stays, it's flagged, the preview shows the error, and typing goes on.
        let bad = "## Bad\n\nA broken $\\frac{a}{$ formula."
        let editor = try await open(bad)
        _ = try await js("const v = sophiaEditor.view(); v.dispatch({selection: {anchor: v.state.doc.toString().indexOf('frac')}}); v.focus();", [:])
        try await settle()
        try await expect("document.querySelector('.cm-math-error') && document.querySelector('.cm-math-preview .katex-error')", "Invalid TeX is flagged and its error previewed")
        events = []
        if let window = document.webView.window {
            window.makeFirstResponder(document.webView)
            for type in [NSEvent.EventType.keyDown, .keyUp] {
                window.sendEvent(NSEvent.keyEvent(with: type, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber,
                                                  context: nil, characters: "b", charactersIgnoringModifiers: "b", isARepeat: false, keyCode: 11)!)
            }
        }
        try await settle()
        guard case .draft(editor.id, let typed)? = events.last(where: { if case .draft = $0 { return true }; return false }),
              typed == bad.replacingOccurrences(of: "frac", with: "bfrac") else {
            throw Failure(description: "Typing stopped after invalid TeX: \(events)")
        }
        _ = try await js("document.dispatchEvent(new KeyboardEvent('keydown', {key: 'Escape'})); sophiaEditor.view().contentDOM.dispatchEvent(new KeyboardEvent('keydown', {key: 'Escape', bubbles: true}))", [:])
        try await settle()
        guard events.contains(where: { if case .revert(editor.id) = $0 { return true }; return false }) else { throw Failure(description: "Esc didn't revert") }
        try await close(bad)

        // Pages offer an Edit button per section and on the opening; clicking one asks the app to open it.
        let page = "Opening words.\n\n## One\n\nText.\n\n### Two\n\nMore."
        document.update(source: page, sections: [ReaderSection(key: "(opening)", label: "the opening", start: 0, end: 2),
                                                 ReaderSection(key: "§0", label: "§1", start: 2, end: 9),
                                                 ReaderSection(key: "§1", label: "§2", start: 6, end: 9)])
        try await settle()
        try await expect("document.querySelectorAll('.edit-affordance').length === 3 && document.querySelector('h3 .edit-affordance').getAttribute('aria-label') === 'Edit §2'", "Edit buttons on the opening and each heading")
        events = []
        _ = try await js("document.querySelector('h3 .edit-affordance').click()", [:])
        try await settle()
        guard case .open(key: "§1")? = events.last else { throw Failure(description: "The Edit button didn't ask to open §2") }
        try await expect("document.querySelector('h3').textContent === 'Two'", "The button adds no text to the heading")
        print("Verified the editor: exact round trips (math, CRLF, tabs, list markers), no network, invalid TeX, Esc, Edit buttons")
    }
}
