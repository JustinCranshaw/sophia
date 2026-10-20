import AppKit
import SwiftUI
import WebKit

/// A part of a page the reader offers for editing (EDITING.md), in lines of the source it shows.
public struct ReaderSection: Equatable {
    public let key: String, label: String, start: Int, end: Int
    public init(key: String, label: String, start: Int, end: Int) {
        self.key = key; self.label = label; self.start = start; self.end = end
    }
}

/// The range open in the editor, as the app has it. The editor's text is the app's, never the page's rendering.
public struct ReaderEditor: Equatable {
    public var id: String, label: String, start: Int, end: Int, text: String, hash: String
    /// The conversation's composer has focus: the strip stays, dimmed.
    public var dimmed = false
    /// The section as Sophia left it, when it changed under the editor; nil when it didn't.
    public var conflict: String?
    /// Open with the caret at the top of what's visible (⌘E), rather than at the range's first line.
    public var atVisibleTop = false
    public init(id: String, label: String, start: Int, end: Int, text: String, hash: String) {
        self.id = id; self.label = label; self.start = start; self.end = end; self.text = text; self.hash = hash
    }
}

/// A tune on a page (MUSIC.md) and abcjs's warnings about it. `line` is where its fence starts
/// in the source the reader shows, when the fence is a top-level block.
public struct ReaderMusic: Equatable {
    public let line: Int?, title: String, warnings: [String]
    public init(line: Int?, title: String, warnings: [String]) { self.line = line; self.title = title; self.warnings = warnings }
}

/// What the person does in the editor. Commits are proposals: the app checks them against its own state.
public enum ReaderEditEvent {
    case open(key: String)
    case draft(id: String, text: String)
    case commit(id: String, hash: String, text: String)
    /// A click elsewhere in the page's scroll view, outside the web view.
    case commitNow
    case revert(id: String)
    case keepMine(id: String)
}

/// A read-only Markdown + LaTeX document, and the page editor. The web view can read only its
/// bundled assets; content is sent as a structured argument, never interpolated into JS.
public final class ReaderDocument: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
    private static let directory: URL = {
        // A packaged Mac app keeps resources in Contents/Resources; swift run
        // uses SwiftPM's adjacent resource bundle instead.
        let bundled = Bundle.main.url(forResource: "Sophia_SophiaReader", withExtension: "bundle")
            .flatMap { Bundle(url: $0) }
        return (bundled ?? Bundle.module).url(forResource: "Reader", withExtension: nil)!
    }()
    public let webView: WKWebView
    public var onHeight: ((CGFloat) -> Void)?
    /// Offsets of the document's h2 and h3 headings from its top, in order.
    public var onHeadings: (([CGFloat]) -> Void)?
    public var onFailure: ((String) -> Void)?
    public var onEdit: ((ReaderEditEvent) -> Void)?
    /// The tunes of the last whole render that had music, or none after one had.
    public var onMusic: (([ReaderMusic]) -> Void)?
    public private(set) var isReady = false
    /// The editor's undo and redo depths, for the Edit menu.
    private(set) var history = (undo: 0, redo: 0)
    private(set) var editorID: String?
    private var caretY: (id: String, y: Double)?
    private var clickMonitor: Any?
    private var payload: [String: Any]?

    public override init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let web = ReaderWebView(frame: .zero, configuration: configuration)
        webView = web
        super.init()
        web.document = self
        webView.navigationDelegate = self
        webView.setValue(false, forKey: "drawsBackground")
        webView.underPageBackgroundColor = .clear
        // The controller retains its handler, so use a weak forwarding object.
        webView.configuration.userContentController.add(HeightHandler(self), name: "reader")
        webView.loadFileURL(Self.directory.appendingPathComponent("index.html"), allowingReadAccessTo: Self.directory)
    }

    deinit { if let clickMonitor { NSEvent.removeMonitor(clickMonitor) } }

    public func update(source: String, serif: Bool = true, size: CGFloat = 17,
                       lineSpacing: CGFloat = 7, paragraphSpacing: CGFloat = 14,
                       sections: [ReaderSection]? = nil, editor: ReaderEditor? = nil) {
        var next: [String: Any] = ["source": source, "serif": serif, "size": size,
                                   "lineSpacing": lineSpacing, "paragraphSpacing": paragraphSpacing]
        if let sections {
            next["sections"] = sections.map { ["key": $0.key, "label": $0.label, "start": $0.start, "end": $0.end] }
        }
        if let editor {
            var e: [String: Any] = ["id": editor.id, "label": editor.label, "start": editor.start, "end": editor.end,
                                    "text": editor.text, "hash": editor.hash, "dimmed": editor.dimmed]
            if let conflict = editor.conflict { e["conflict"] = conflict }
            // ⌘E opens where the person is reading: the top of the visible part of the page, measured once.
            if editor.atVisibleTop {
                if caretY?.id != editor.id {
                    let visible = webView.visibleRect
                    caretY = (editor.id, webView.isFlipped ? visible.minY : webView.bounds.height - visible.maxY)
                }
                e["caretY"] = caretY?.y
            }
            next["editor"] = e
        }
        watchClicks(editor != nil)
        // A newly opened editor takes the keyboard, even when ⌘E was pressed in the composer.
        if let editor, editor.id != editorID, let window = webView.window { window.makeFirstResponder(webView) }
        editorID = editor?.id
        if let payload, NSDictionary(dictionary: payload).isEqual(to: next) { return }
        payload = next
        render()
    }

    private func render() {
        guard isReady, let payload else { return }
        webView.callAsyncJavaScript("window.sophiaReader.update(payload)", arguments: ["payload": payload],
                                    in: nil, in: .page) { [weak self] result in
            if case .failure(let error) = result { self?.onFailure?(error.localizedDescription) }
        }
    }

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, let body = message.body as? [String: Any] else { return }
        if body["ready"] as? Bool == true { isReady = true; render() }
        if let height = body["height"] as? Double, height.isFinite, height > 0 { onHeight?(height) }
        if let headings = body["headings"] as? [Double] { onHeadings?(headings.map { CGFloat($0) }) }
        if let shift = body["shift"] as? Double, shift != 0 { holdEditor(shift) }
        if let caret = body["caret"] as? [Double], caret.count == 2 { revealCaret(top: caret[0], bottom: caret[1]) }
        if let h = body["history"] as? [Int], h.count == 2 { history = (h[0], h[1]) }
        if let problem = body["problem"] as? String { onFailure?(problem) }
        if let music = body["music"] as? [[String: Any]] {
            onMusic?(music.prefix(50).map { m in
                ReaderMusic(line: m["line"] as? Int, title: String((m["title"] as? String ?? "").prefix(200)),
                            warnings: (m["warnings"] as? [String] ?? []).prefix(20).map { String($0.prefix(300)) })
            })
        }
        // Editor messages are only proposals; ids are checked here and again by the app.
        if let key = body["edit"] as? String { onEdit?(.open(key: key)) }
        if let d = body["draft"] as? [String: Any], let id = d["id"] as? String, id == editorID, let text = d["text"] as? String {
            onEdit?(.draft(id: id, text: text))
        }
        if let c = body["commit"] as? [String: Any], let id = c["id"] as? String, id == editorID,
           let hash = c["hash"] as? String, let text = c["text"] as? String {
            onEdit?(.commit(id: id, hash: hash, text: text))
        }
        if let id = body["revert"] as? String, id == editorID { onEdit?(.revert(id: id)) }
        if let id = body["keepMine"] as? String, id == editorID { onEdit?(.keepMine(id: id)) }
    }

    /// While editing, a click in the page's scroll view but outside this web view (the page
    /// title, the margins) commits, as clicking outside a field does. Clicks inside the web view
    /// are handled by the editor; clicks elsewhere in the window (the conversation) leave it open.
    private func watchClicks(_ on: Bool) {
        if !on, let monitor = clickMonitor { NSEvent.removeMonitor(monitor); clickMonitor = nil }
        guard on, clickMonitor == nil else { return }
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self, let window = self.webView.window, event.window === window,
                  let scrollView = self.webView.enclosingScrollView,
                  let hit = window.contentView?.hitTest(event.locationInWindow) else { return event }
            if hit.isDescendant(of: scrollView), !hit.isDescendant(of: self.webView), !(hit is NSScroller) {
                self.onEdit?(.commitNow)
            }
            return event
        }
    }

    func undoInEditor(redo: Bool) {
        webView.callAsyncJavaScript(redo ? "sophiaEditor.redo()" : "sophiaEditor.undo()", arguments: [:], in: nil, in: .page)
    }

    // While a section is open for editing, the page still scrolls in the app's scroll
    // view, not in this web view, so CodeMirror can't scroll for itself. The page's
    // new height reaches SwiftUI first; scroll on the next turn of the run loop.

    /// Scrolls the enclosing scroll view just enough to show the caret, with a margin.
    private func revealCaret(top: Double, bottom: Double) {
        DispatchQueue.main.async { [webView] in
            let margin = 24.0
            let y = webView.isFlipped ? top - margin : webView.bounds.height - bottom - margin
            webView.scrollToVisible(NSRect(x: 0, y: y, width: 1, height: bottom - top + 2 * margin))
        }
    }

    /// Content above the editor changed height: scroll by as much, so the editor stays put.
    private func holdEditor(_ shift: Double) {
        DispatchQueue.main.async { [webView] in
            guard let scrollView = webView.enclosingScrollView else { return }
            let clip = scrollView.contentView
            var bounds = clip.bounds
            bounds.origin.y += (scrollView.documentView?.isFlipped ?? true) ? shift : -shift
            clip.scroll(to: clip.constrainBoundsRect(bounds).origin)
            scrollView.reflectScrolledClipView(clip)
        }
    }


    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Only the initial bundled document may navigate within this web view.
        if navigationAction.navigationType == .other,
           navigationAction.request.url == Self.directory.appendingPathComponent("index.html") {
            decisionHandler(.allow)
            return
        }
        if navigationAction.navigationType == .linkActivated,
           let url = navigationAction.request.url, ["https", "http", "mailto"].contains(url.scheme?.lowercased() ?? "") {
            NSWorkspace.shared.open(url)
        }
        decisionHandler(.cancel)
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        onFailure?(error.localizedDescription)
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.callAsyncJavaScript("return !!window.sophiaReader", arguments: [:], in: nil, in: .page) { [weak self] result in
            if case .success(let ready) = result, ready as? Bool == true { return }
            self?.onFailure?("The bundled Markdown reader couldn't load.")
        }
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        onFailure?(error.localizedDescription)
    }

    public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        onFailure?("The text reader stopped. Reopen the page to try again.")
    }
}

private final class HeightHandler: NSObject, WKScriptMessageHandler {
    weak var document: ReaderDocument?
    init(_ document: ReaderDocument) { self.document = document }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        document?.userContentController(userContentController, didReceive: message)
    }
}

private final class ReaderWebView: WKWebView {
    weak var document: ReaderDocument?

    // Edit ▸ Undo and Redo act on the editor's own history while it's open.
    @objc func undo(_ sender: Any?) {
        if document?.editorID != nil { document?.undoInEditor(redo: false) } else { nextResponder?.tryToPerform(#selector(undo(_:)), with: sender) }
    }
    @objc func redo(_ sender: Any?) {
        if document?.editorID != nil { document?.undoInEditor(redo: true) } else { nextResponder?.tryToPerform(#selector(redo(_:)), with: sender) }
    }
    override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        if let document, document.editorID != nil {
            if item.action == #selector(undo(_:)) { return document.history.undo > 0 }
            if item.action == #selector(redo(_:)) { return document.history.redo > 0 }
        }
        return super.validateUserInterfaceItem(item)
    }

    override func scrollWheel(with event: NSEvent) {
        // The enclosing SwiftUI ScrollView owns vertical reading. Formula and
        // code overflow can still scroll horizontally, including Shift + wheel.
        if abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) || event.modifierFlags.contains(.shift) {
            super.scrollWheel(with: event)
        } else {
            nextResponder?.scrollWheel(with: event)
        }
    }
}

public struct MarkdownReader: NSViewRepresentable {
    public let source: String
    public var serif: Bool
    public var size: CGFloat
    public var lineSpacing: CGFloat
    public var paragraphSpacing: CGFloat
    @Binding public var height: CGFloat
    @Binding public var failure: String?
    @Binding public var headings: [CGFloat]
    /// For a page: the parts that can be opened for editing, the open editor, and what the person does in it.
    public var sections: [ReaderSection]?
    public var editor: ReaderEditor?
    public var onEdit: ((ReaderEditEvent) -> Void)?
    public var onMusic: (([ReaderMusic]) -> Void)?
    @Environment(\.colorScheme) private var colorScheme

    public init(source: String, serif: Bool, size: CGFloat, lineSpacing: CGFloat,
                paragraphSpacing: CGFloat, height: Binding<CGFloat>, failure: Binding<String?>,
                headings: Binding<[CGFloat]> = .constant([]), sections: [ReaderSection]? = nil,
                editor: ReaderEditor? = nil, onEdit: ((ReaderEditEvent) -> Void)? = nil,
                onMusic: (([ReaderMusic]) -> Void)? = nil) {
        self.source = source; self.serif = serif; self.size = size
        self.lineSpacing = lineSpacing; self.paragraphSpacing = paragraphSpacing
        _height = height; _failure = failure; _headings = headings
        self.sections = sections; self.editor = editor; self.onEdit = onEdit; self.onMusic = onMusic
    }

    public func makeCoordinator() -> ReaderDocument { ReaderDocument() }
    public func makeNSView(context: Context) -> WKWebView { context.coordinator.webView }
    public func updateNSView(_ nsView: WKWebView, context: Context) {
        context.coordinator.onHeight = { value in
            DispatchQueue.main.async { if height != value { height = value } }
        }
        context.coordinator.onHeadings = { value in
            DispatchQueue.main.async { if headings != value { headings = value } }
        }
        context.coordinator.onFailure = { message in
            DispatchQueue.main.async { failure = message }
        }
        context.coordinator.onEdit = onEdit
        context.coordinator.onMusic = onMusic.map { report in { value in DispatchQueue.main.async { report(value) } } }
        nsView.appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
        context.coordinator.update(source: source, serif: serif, size: size, lineSpacing: lineSpacing,
                                   paragraphSpacing: paragraphSpacing, sections: sections, editor: editor)
    }
}
