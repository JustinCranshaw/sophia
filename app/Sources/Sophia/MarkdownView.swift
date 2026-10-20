import SwiftUI
import SophiaReader

/// The shared Markdown + LaTeX reader for pages and Sophia's replies.
struct MarkdownView: View {
    /// Serif means the book; the conversation is set in the system face.
    struct Style {
        var serif: Bool
        var size: CGFloat
        var lineSpacing: CGFloat
        var paragraphSpacing: CGFloat
        static let page = Style(serif: true, size: 17, lineSpacing: 7, paragraphSpacing: 14)
        static let chat = Style(serif: false, size: 14, lineSpacing: 5, paragraphSpacing: 10)
    }

    let text: String
    var style: Style = .page
    var onResize: (() -> Void)?
    /// Places invisible anchors at the section headings, with ids "section-0", "section-1", …,
    /// so a ScrollViewReader can scroll to a section.
    var anchors = false
    /// For a page: the parts that can be edited, the open editor, and what the person does in it.
    var sections: [ReaderSection]?
    var editor: ReaderEditor?
    var onEdit: ((ReaderEditEvent) -> Void)?
    var onHeadings: (([CGFloat]) -> Void)?
    /// For a page: its tunes' notation warnings (MUSIC.md), whenever they change.
    var onMusic: (([ReaderMusic]) -> Void)?
    /// The margin left of the text where a page's Edit buttons sit.
    static let editGutter: CGFloat = 28

    @State private var height: CGFloat = 30
    @State private var headings: [CGFloat] = []
    @State private var failure: String?

    var body: some View {
        if let failure {
            VStack(alignment: .leading, spacing: 8) {
                Text("Couldn't typeset this text: " + failure).font(.caption).foregroundStyle(.secondary)
                Text(text).font(.system(size: style.size, design: style.serif ? .serif : .default))
                    .textSelection(.enabled)
            }
        } else {
            MarkdownReader(source: text, serif: style.serif, size: style.size,
                           lineSpacing: style.lineSpacing, paragraphSpacing: style.paragraphSpacing,
                           height: $height, failure: $failure, headings: $headings,
                           sections: sections, editor: editor, onEdit: onEdit, onMusic: onMusic)
                .frame(height: height)
                .padding(.leading, sections == nil ? 0 : -Self.editGutter)
                .background(alignment: .top) {
                    // A column of blank blocks, each starting at a heading, so the heading has a frame to scroll to.
                    if anchors, let first = headings.first {
                        VStack(spacing: 0) {
                            Color.clear.frame(height: max(0, first - 12))
                            ForEach(Array(headings.enumerated()), id: \.offset) { i, y in
                                Color.clear.frame(height: max(1, (i + 1 < headings.count ? headings[i + 1] : height + 12) - y)).id("section-\(i)")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .top)
                    }
                }
                .onChange(of: headings) { _, h in onHeadings?(h) }
                .frame(maxWidth: .infinity, alignment: .leading)
                .onChange(of: height) { _, _ in onResize?() }
        }
    }

    /// Unicode sub- and superscript characters are missing from New York (and partly from SF),
    /// so the system substitutes fonts with different spacing, leaving gaps after "λ₂".
    /// Set them instead as small, offset base characters in the surrounding face.
    static let subscripts: [Character: Character] = [
        "₀": "0", "₁": "1", "₂": "2", "₃": "3", "₄": "4", "₅": "5", "₆": "6", "₇": "7", "₈": "8", "₉": "9",
        "₊": "+", "₋": "−", "₌": "=", "₍": "(", "₎": ")", "ₐ": "a", "ₑ": "e", "ₒ": "o", "ₓ": "x", "ₕ": "h",
        "ᵢ": "i", "ⱼ": "j", "ₖ": "k", "ₗ": "l", "ₘ": "m", "ₙ": "n", "ₚ": "p", "ₛ": "s", "ₜ": "t", "ᵤ": "u", "ᵥ": "v"]
    static let superscripts: [Character: Character] = [
        "⁰": "0", "¹": "1", "²": "2", "³": "3", "⁴": "4", "⁵": "5", "⁶": "6", "⁷": "7", "⁸": "8", "⁹": "9",
        "⁺": "+", "⁻": "−", "⁼": "=", "⁽": "(", "⁾": ")", "ⁱ": "i", "ⁿ": "n", "ᵀ": "T", "ᵗ": "t", "ᵏ": "k"]

    static func scripts(_ attr: AttributedString, size: CGFloat, design: Font.Design) -> AttributedString {
        guard attr.characters.contains(where: { subscripts[$0] != nil || superscripts[$0] != nil }) else { return attr }
        var out = AttributedString()
        for run in attr.runs {
            var plain = ""
            var script = "", scriptIsSub = true
            func flushPlain() {
                guard !plain.isEmpty else { return }
                out.append(AttributedString(plain, attributes: run.attributes)); plain = ""
            }
            func flushScript() {
                guard !script.isEmpty else { return }
                var a = AttributedString(script, attributes: run.attributes)
                a.font = .system(size: (size * 0.72).rounded(), design: design)
                a.baselineOffset = scriptIsSub ? -size * 0.18 : size * 0.36
                out.append(a); script = ""
            }
            for c in attr[run.range].characters {
                if let base = subscripts[c] ?? superscripts[c] {
                    let isSub = subscripts[c] != nil
                    flushPlain()
                    if !script.isEmpty && isSub != scriptIsSub { flushScript() }
                    scriptIsSub = isSub
                    script.append(base)
                } else {
                    flushScript()
                    plain.append(c)
                }
            }
            flushPlain(); flushScript()
        }
        return out
    }

}
