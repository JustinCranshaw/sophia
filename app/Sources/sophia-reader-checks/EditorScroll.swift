import AppKit
import SophiaReader
import SwiftUI
import WebKit

/// Phase 1 step 0 of EDITING.md: the editor inside the content-sized reader, inside a
/// SwiftUI ScrollView laid out as the book's page is. Arrows through a section taller
/// than the window, then revises the sections around it, measuring on screen.
/// swift run sophia-reader-checks --scroll-spike
@MainActor enum EditorScroll {
    final class Model: ObservableObject { @Published var source = ""; @Published var editor: ReaderEditor? }

    struct Page: View {
        @ObservedObject var model: Model
        @State private var height: CGFloat = 30
        @State private var failure: String?
        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Fiedler vector").font(.system(size: 30, weight: .semibold, design: .serif))
                    MarkdownReader(source: model.source, serif: true, size: 17, lineSpacing: 7,
                                   paragraphSpacing: 14, height: $height, failure: $failure, editor: model.editor)
                        .frame(height: height)
                }
                .frame(maxWidth: 660, alignment: .leading)
                .padding(.horizontal, 36).padding(.vertical, 32)
                .frame(maxWidth: .infinity)
            }
        }
    }

    static func section(_ title: String, paragraphs: Int, tag: String) -> String {
        var lines = ["## \(title)", ""]
        for i in 0..<paragraphs {
            lines.append("Step \(i) of \(tag): the Rayleigh quotient $R(x) = \\frac{x^\\top Lx}{x^\\top x}$ is minimised over vectors orthogonal to $\\mathbf{1}$, which gives $\\lambda_2$ and a long enough sentence to wrap across lines.")
            lines.append("")
            if i % 2 == 0 {
                lines += ["$$", "\\sum_{(i,j)\\in E} (x_i - x_j)^2 = x^\\top L x \\geq \\lambda_2 \\lVert x \\rVert^2 \\quad (\(tag).\(i))", "$$", ""]
            }
        }
        return lines.joined(separator: "\n")
    }

    struct Failure: Error, CustomStringConvertible { let description: String }

    static func run() async throws {
        let model = Model()
        let above = section("Setup", paragraphs: 3, tag: "a")
        let long = section("A long derivation", paragraphs: 16, tag: "b")
        let after = section("Consequences", paragraphs: 4, tag: "c")
        model.source = ["Opening text with $x^2$.", above, long, after].joined(separator: "\n\n")

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 600),
                              styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.contentView = NSHostingView(rootView: Page(model: model))
        window.orderBack(nil)
        defer { window.orderOut(nil) }

        func find(_ view: NSView) -> WKWebView? {
            if let web = view as? WKWebView { return web }
            for sub in view.subviews { if let web = find(sub) { return web } }
            return nil
        }
        var webView: WKWebView?
        for _ in 0..<100 where webView == nil {
            webView = find(window.contentView!)
            try await Task.sleep(for: .milliseconds(50))
        }
        guard let web = webView, let scrollView = web.enclosingScrollView else { throw Failure(description: "No web view in a scroll view") }
        func js(_ body: String) async throws -> Any? {
            try await web.callAsyncJavaScript(body, arguments: [:], in: nil, contentWorld: .page)
        }
        func settle(_ ms: Int = 60) async throws { try await Task.sleep(for: .milliseconds(ms)) }
        for _ in 0..<200 {
            if try await js("return !!window.sophiaReader && content.childElementCount > 0") as? Bool == true, web.frame.height > 2000 { break }
            try await settle(50)
        }
        _ = try await js("await document.fonts.ready")
        try await settle(300)
        print("Page height \(Int(web.frame.height)), window \(Int(scrollView.contentView.bounds.height)) tall")

        // Rects in window coordinates (bottom-left origin): what's visible, and where a document rect is.
        func visible() -> NSRect { scrollView.contentView.convert(scrollView.contentView.bounds, to: nil) }
        func onScreen(_ top: Double, _ bottom: Double) -> NSRect {
            web.convert(NSRect(x: 0, y: web.isFlipped ? top : web.bounds.height - bottom, width: 1, height: bottom - top), to: nil)
        }
        func caret() async throws -> NSRect {
            let r = try await js("const v = sophiaEditor.view(); const c = v.coordsAtPos(v.state.selection.main.head); return [c.top + scrollY, c.bottom + scrollY]") as! [Double]
            return onScreen(r[0], r[1])
        }
        func editorTop() async throws -> CGFloat {
            let r = try await js("const r = document.querySelector('.editing').getBoundingClientRect(); return [r.top + scrollY, r.bottom + scrollY]") as! [Double]
            return onScreen(r[0], r[1]).maxY
        }

        // Scroll the long section's heading to the top, as a deep link would, and open it.
        let headingY = try await js("return document.querySelectorAll('h2')[1].getBoundingClientRect().top + scrollY") as! Double
        let start = web.convert(NSPoint(x: 0, y: web.isFlipped ? headingY : web.bounds.height - headingY), to: scrollView.documentView)
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: start.y - 12))
        scrollView.reflectScrolledClipView(scrollView.contentView)
        let started = Date()
        // Open it as the app does: the long section's lines, with the app's text for them.
        let sourceLines = model.source.components(separatedBy: "\n")
        let first = sourceLines.firstIndex(of: "## A long derivation")!, end = sourceLines.firstIndex(of: "## Consequences")!
        model.editor = ReaderEditor(id: "spike", label: "§2", start: first, end: end,
                                    text: sourceLines[first..<end].joined(separator: "\n"), hash: "h")
        for _ in 0..<100 {
            if try await js("return window.sophiaEditor?.isOpen === true") as? Bool == true { break }
            try await settle(30)
        }
        guard try await js("return window.sophiaEditor?.isOpen === true") as? Bool == true else { throw Failure(description: "Editor didn't open") }
        print("Editor opened in \(Int(Date().timeIntervalSince(started) * 1000)) ms (includes loading CodeMirror)")
        try await settle(300)
        let lines = try await js("const v = sophiaEditor.view(); return [v.state.doc.lines, v.contentDOM.querySelectorAll('.cm-line').length]") as! [Int]
        print("Section lines \(lines[0]), rendered \(lines[1]) (CodeMirror drew \(lines[0] == lines[1] ? "all of them" : "only part"))")

        // Real arrow-key events, sent to the web view without making the window key (no focus is taken).
        window.makeFirstResponder(web)
        _ = try await js("const v = sophiaEditor.view(); v.dispatch({selection: {anchor: 0}}); v.focus()")
        func key(_ code: UInt16, _ character: String) {
            for type in [NSEvent.EventType.keyDown, .keyUp] {
                window.sendEvent(NSEvent.keyEvent(with: type, location: .zero, modifierFlags: [.numericPad, .function], timestamp: 0,
                                                  windowNumber: window.windowNumber, context: nil, characters: character,
                                                  charactersIgnoringModifiers: character, isARepeat: false, keyCode: code)!)
            }
        }

        // Arrow down through the whole section, then back up. The caret must stay on screen.
        var hidden = 0, steps = 0, worst = 0.0
        func step(_ command: String) async throws {
            let before = try await js("return sophiaEditor.view().state.selection.main.head") as! Int
            command == "cursorLineDown" ? key(125, "\u{F701}") : key(126, "\u{F700}")
            try await settle()
            if try await js("return sophiaEditor.view().state.selection.main.head") as! Int == before {
                throw Failure(description: "An arrow key didn't move the caret")
            }
            let c = try await caret(), v = visible()
            steps += 1
            if c.minY < v.minY || c.maxY > v.maxY {
                hidden += 1
                worst = max(worst, max(v.minY - c.minY, c.maxY - v.maxY))
            }
        }
        while try await js("const v = sophiaEditor.view(); return v.state.selection.main.head < v.state.doc.length") as? Bool == true, steps < 400 {
            try await step("cursorLineDown")
        }
        print("Arrowing down: \(steps) steps, caret off screen after \(hidden) (worst by \(Int(worst)) pt)")
        let downHidden = hidden
        hidden = 0; steps = 0; worst = 0
        // Typing new lines at the end grows the page under the caret.
        for _ in 0..<12 {
            _ = try await js("const v = sophiaEditor.view(); v.dispatch(v.state.replaceSelection('\\nA new line with $y$.'))")
            try await settle(); let c = try await caret(), v = visible(); steps += 1
            if c.minY < v.minY || c.maxY > v.maxY { hidden += 1; worst = max(worst, max(v.minY - c.minY, c.maxY - v.maxY)) }
        }
        print("Typing new lines at the end: \(steps) steps, caret off screen after \(hidden) (worst by \(Int(worst)) pt)")
        let typeHidden = hidden
        hidden = 0; steps = 0; worst = 0
        while try await js("return sophiaEditor.view().state.selection.main.head > 0") as? Bool == true, steps < 400 {
            try await step("cursorLineUp")
        }
        print("Arrowing up: \(steps) steps, caret off screen after \(hidden) (worst by \(Int(worst)) pt)")
        let upHidden = hidden

        // Sophia revises the section above (taller, then shorter) and the one below.
        _ = try await js("const v = sophiaEditor.view(); v.dispatch({selection: {anchor: Math.floor(v.state.doc.length / 2)}})")
        try await settle(200)
        let text = try await js("return sophiaEditor.view().state.doc.toString()") as! String
        var jumps: [String] = []
        for (name, next) in [
            ("section above grows by 8 paragraphs", model.source.replacingOccurrences(of: above, with: section("Setup", paragraphs: 11, tag: "a"))),
            ("section above shrinks back", model.source),
            ("section below changes", model.source.replacingOccurrences(of: after, with: section("Consequences", paragraphs: 9, tag: "c")))
        ] {
            let top = try await editorTop(), c0 = try await caret()
            // As the app does, place the open range where its lines now are.
            let nextLines = next.components(separatedBy: "\n")
            model.editor?.start = nextLines.firstIndex(of: "## A long derivation")!
            model.editor?.end = nextLines.firstIndex(of: "## Consequences")!
            model.source = next
            try await settle(400)
            let moved = try await editorTop() - top, caretMoved = try await caret().minY - c0.minY
            let same = try await js("return sophiaEditor.view().state.doc.toString()") as? String == text
            print("When the \(name): editor moved \(Int(moved)) pt on screen, caret \(Int(caretMoved)) pt; editor text \(same ? "kept" : "LOST")")
            if abs(moved) > 1 || !same { jumps.append(name) }
        }

        if let output = ProcessInfo.processInfo.environment["SOPHIA_READER_SNAPSHOT"],
           let cg = CGWindowListCreateImage(.null, .optionIncludingWindow, CGWindowID(window.windowNumber), [.boundsIgnoreFraming, .bestResolution]) {
            try NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: output))
        }
        guard downHidden + typeHidden + upHidden == 0, jumps.isEmpty else {
            throw Failure(description: "Caret hidden or editor moved; see above")
        }
        print("Scroll spike passed: the caret stayed visible and the editor held still")
    }
}
