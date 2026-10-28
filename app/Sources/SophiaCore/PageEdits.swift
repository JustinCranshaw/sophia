import Foundation
import CryptoKit

/// The person's own edits to pages (EDITING.md). They edit one range of a page's Markdown
/// at a time: a section, the opening before the first section, or the whole page. A commit
/// is spliced in byte for byte; nothing else in the file changes. The lines they write are
/// protected: Sophia's `write_page` is refused if it would drop or change them, until the
/// person releases that edit.
extension NotebookStore {

    // MARK: Lines and ranges

    /// A page body as lines. The final newline ends the last line rather than starting an
    /// empty one, so a range never includes it and a splice always puts it back.
    struct Lines {
        var lines: [String]
        var trailingNewline: Bool
        init(_ body: String) {
            lines = body.components(separatedBy: "\n")
            trailingNewline = lines.count > 1 && lines.last == ""
            if trailingNewline { lines.removeLast() }
        }
        var text: String { lines.joined(separator: "\n") + (trailingNewline ? "\n" : "") }
    }

    /// A heading line outside code fences: `#` to `###`, indented less than four spaces.
    struct Heading { let line: Int; let level: Int; let title: String }

    static func headings(_ lines: [String]) -> [Heading] {
        var out: [Heading] = []
        var fence: Substring?
        for (i, line) in lines.enumerated() {
            let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.hasPrefix("```") || t.hasPrefix("~~~") {
                let marker = t.prefix(3)
                if fence == nil { fence = marker } else if fence == marker { fence = nil }
                continue
            }
            guard fence == nil, line.prefix(while: { $0 == " " }).count < 4 else { continue }
            for (level, prefix) in [(1, "# "), (2, "## "), (3, "### ")] where t.hasPrefix(prefix) || t == prefix.dropLast() {
                let title = t.dropFirst(prefix.count - 1).trimmingCharacters(in: CharacterSet(charactersIn: "# ").union(.whitespacesAndNewlines))
                out.append(Heading(line: i, level: level, title: title))
            }
        }
        return out
    }

    /// Part of a page the person can open for editing.
    public struct EditRange: Equatable {
        /// "§<index>" for a section, "(opening)" for the text before the first section, "(page)" for the whole body.
        public let key: String
        /// As recorded in the transcript: the section's title, "(opening)", or "(page)".
        public let section: String
        /// The section's position among the page's sections, as the reader counts them.
        public let index: Int?
        /// Lines of the page body, the last line's newline excluded.
        public let lines: Range<Int>
        public let text: String
        public var hash: String { NotebookStore.hash(text) }
        /// For the person: "§2", "the opening", "the page".
        public var label: String { index.map { "§\($0 + 1)" } ?? (key == "(opening)" ? "the opening" : "the page") }
    }

    public static func hash(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// The editable ranges of a body whose first `hidden` lines the reader doesn't show
    /// (a repeated title): the opening, if it has any text, each section, and the whole page.
    public static func editRanges(in body: String, hidden: Int = 0) -> [EditRange] {
        let lines = Lines(body).lines
        let hidden = min(hidden, lines.count)
        func range(_ key: String, _ section: String, _ index: Int?, _ r: Range<Int>) -> EditRange {
            EditRange(key: key, section: section, index: index, lines: r, text: lines[r].joined(separator: "\n"))
        }
        let all = headings(lines).filter { $0.line >= hidden }
        var out: [EditRange] = []
        let firstHeading = all.first?.line ?? lines.count
        if lines[hidden..<firstHeading].contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            out.append(range("(opening)", "(opening)", nil, hidden..<firstHeading))
        }
        for (i, h) in all.filter({ $0.level >= 2 && !$0.title.isEmpty }).enumerated() {
            let end = all.first { $0.line > h.line && $0.level <= h.level }?.line ?? lines.count
            out.append(range("§\(i)", h.title, i, h.line..<end))
        }
        if hidden < lines.count { out.append(range("(page)", "(page)", nil, hidden..<lines.count)) }
        return out
    }

    /// How many leading lines of a body the reader leaves out because they repeat the page's
    /// title (and chapter), which the page header already shows. Blank lines around them count.
    public static func repeatedHeadingLines(in body: String, title: String, chapter: Chapter?) -> Int {
        let lines = body.components(separatedBy: "\n")
        func clean(_ s: String) -> String { s.lowercased().filter { $0.isLetter || $0.isNumber } }
        func blanks(from i: Int) -> Int {
            var i = i
            while i < lines.count, lines[i].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { i += 1 }
            return i
        }
        var i = blanks(from: 0)
        guard i < lines.count, lines[i].hasPrefix("# "), clean(String(lines[i].dropFirst(2))) == clean(title) else { return 0 }
        i = blanks(from: i + 1)
        if let chapter, i < lines.count, clean(lines[i]) == clean(chapter.heading) || clean(lines[i]) == clean(chapter.title) {
            i = blanks(from: i + 1)
        }
        return i
    }

    /// The title of the innermost section holding a line of the body, or nil in the opening.
    public static func sectionTitle(containing line: Int, in ranges: [EditRange]) -> String? {
        ranges.last { $0.index != nil && $0.lines.contains(line) }?.section
    }

    public func editRanges(of file: String) -> [EditRange] {
        guard let page = readPage(file) else { return [] }
        return Self.editRanges(in: page.body, hidden: Self.repeatedHeadingLines(in: page.body, title: page.title, chapter: chapter(of: file)))
    }

    // MARK: The open-section marker

    var editMarkerURL: URL { url.appendingPathComponent(".editing.json") }

    /// What the person has open for editing, if anything, as the app recorded it.
    public var editMarker: JSONObject? {
        (try? Data(contentsOf: editMarkerURL)).flatMap { try? JSONDecoder().decode(JSON.self, from: $0) }?.object
    }

    /// Opens a range for editing: records it in the marker, under the lock, so a `write_page`
    /// from this moment on can't change it. Returns the range as it is now, or nil if it's gone.
    public func beginEdit(file: String, key: String, session: String) throws -> EditRange? {
        try locked {
            guard let r = editRanges(of: file).first(where: { $0.key == key }) else { return nil }
            let marker: JSONObject = ["session": .string(session), "file": .string(file), "key": .string(key),
                                      "section": .string(r.section), "text": .string(r.text), "at": .string(Self.now())]
            try Data(JSON.object(marker).line.utf8).write(to: editMarkerURL, options: .atomic)
            return r
        }
    }

    /// Closes whatever is open for editing. Called on commit, revert, and launch (after a crash).
    public func endEdit() {
        locked { try? FileManager.default.removeItem(at: editMarkerURL) }
    }

    // MARK: The person's commit

    public enum EditOutcome {
        case saved(JSONObject)
        case unchanged
        /// The range changed since the editor opened; `current` is what's there now, if it still exists.
        case conflict(current: EditRange?)
    }

    /// Saves the person's text for one range of a page. The range is found by the hash of the
    /// text it had when the editor opened (sections above may have moved it). A commit that
    /// changes nothing writes nothing. Like a page write, it keeps the previous version and
    /// records a transcript entry, with the changed lines as hunks.
    public func editPage(file: String, section key: String, baseHash: String, text: String, session: String, wholeBody: Bool = false) throws -> EditOutcome {
        try locked {
            guard let page = readPage(file), pageFiles.contains(file) else { return .conflict(current: nil) }
            guard !wholeBody || key == "(page)" else { return .conflict(current: nil) }
            let ranges = wholeBody ? Self.editRanges(in: page.body) : editRanges(of: file)
            let wanted = ranges.first { $0.key == key }
            let matches = ranges.filter { $0.hash == baseHash && ($0.key == key || $0.index != nil && key.hasPrefix("§")) }
            guard let r = matches.first(where: { $0.key == key }) ?? matches.first else { return .conflict(current: wanted) }
            if wholeBody ? text == page.body : text == r.text { return .unchanged }

            var body = Lines(page.body)
            let before = Array(body.lines[r.lines])
            let after: [String]
            if wholeBody {
                // Reviewed proposals replace every body byte, including a repeated title
                // and the final newline. Ordinary editor ranges keep their existing rules.
                body = Lines(text)
                after = body.lines
            } else {
                after = text.components(separatedBy: "\n")
                body.lines.replaceSubrange(r.lines, with: after)
            }
            // Splice bytes, not characters: the frontmatter is kept exactly as it is on disk.
            let current = pagesURL.appendingPathComponent(file)
            let raw = try Data(contentsOf: current)
            let oldBody = Data(page.body.utf8)
            guard raw.count >= oldBody.count, raw.suffix(oldBody.count) == oldBody else { throw StoreError.notFound }
            let previous = pagesURL.appendingPathComponent(Self.previousName(file))
            try? FileManager.default.removeItem(at: previous)
            try FileManager.default.copyItem(at: current, to: previous)
            try (raw.prefix(raw.count - oldBody.count) + Data(body.text.utf8)).write(to: current, options: .atomic)
            let hunks = Self.hunks(before, after).map { JSON.object(["before": .string($0.before), "after": .string($0.after)]) }
            var entry: JSONObject = ["role": .string("person"), "purpose": .string("edit_page"), "session": .string(session),
                                     "file": .string(file), "page": .string(file), "hash": .string(pageHash(file)!), "title": .string(page.title), "section": .string(r.section),
                                     "hunks": .array(hunks)]
            if let i = r.index { entry["index"] = .number(Double(i)) }
            return .saved(try appendTranscriptLocked(entry))
        }
    }

    /// Whole-line differences between two versions of a range, grouped into runs.
    static func hunks(_ a: [String], _ b: [String]) -> [(before: String, after: String)] {
        // Longest common subsequence of lines; sections are short.
        var table = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in stride(from: a.count - 1, through: 0, by: -1) {
            for j in stride(from: b.count - 1, through: 0, by: -1) {
                table[i][j] = a[i] == b[j] ? table[i + 1][j + 1] + 1 : max(table[i + 1][j], table[i][j + 1])
            }
        }
        var out: [(before: String, after: String)] = []
        var i = 0, j = 0, removed: [String] = [], added: [String] = []
        func flush() {
            if !removed.isEmpty || !added.isEmpty { out.append((removed.joined(separator: "\n"), added.joined(separator: "\n"))) }
            removed = []; added = []
        }
        while i < a.count || j < b.count {
            if i < a.count, j < b.count, a[i] == b[j] { flush(); i += 1; j += 1 }
            else if j < b.count, i == a.count || table[i][j + 1] >= table[i + 1][j] { added.append(b[j]); j += 1 }
            else { removed.append(a[i]); i += 1 }
        }
        flush()
        return out
    }

    // MARK: Protection

    /// The person's edits to a page, oldest first.
    public func pageEdits(of file: String) -> [JSONObject] {
        transcript.filter { $0.str("purpose") == "edit_page" && $0.str("file") == file }
    }

    /// A release the person can still take back: its entry, unless an undo names it.
    public func isReleased(_ editID: String) -> Bool {
        transcript.contains { r in
            r.str("purpose") == "release_edit" && r.str("entry") == editID
                && !transcript.contains { $0.str("purpose") == "undo_release" && $0.str("entry") == r.str("id") }
        }
    }

    static func plain(_ line: String) -> String { line.hasSuffix("\r") ? String(line.dropLast()) : line }

    /// The lines of a page that `write_page` must keep: for each of the person's edits, not
    /// undone or released, the lines they wrote that are still on the page.
    public func protectedLines(of file: String) -> [(edit: JSONObject, lines: [String])] {
        guard let body = readPage(file)?.body else { return [] }
        let present = Set(Lines(body).lines.map(Self.plain))
        return pageEdits(of: file).compactMap { e in
            guard let id = e.str("id"), !isUndone(id), !isReleased(id) else { return nil }
            let lines = (e["hunks"]?.array ?? []).flatMap { ($0["after"]?.string ?? "").components(separatedBy: "\n") }
                .map(Self.plain).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty && present.contains($0) }
            return lines.isEmpty ? nil : (e, lines)
        }
    }

    /// Block quotes of the person's words (a `<!-- quote: t-… -->` line and the quote around it).
    static func quotedLines(_ lines: [String]) -> [String] {
        var out: [String] = []
        for (i, line) in lines.enumerated() where line.contains("<!-- quote: t-") {
            var start = i, end = i + 1
            func quoted(_ k: Int) -> Bool { lines[k].trimmingCharacters(in: .whitespaces).hasPrefix(">") }
            while start > 0, quoted(start - 1) { start -= 1 }
            while end < lines.count, quoted(end) { end += 1 }
            out += lines[start..<end].map(plain)
        }
        return out
    }

    public struct Refusal {
        public enum Reason: String { case open, protected, quote }
        public let reason: Reason
        public let section: String          // where the kept text is, as the transcript records sections
        public let edits: [String]          // the person's edits in the way, for protected lines
        public let current: String          // that section's text now
    }

    /// Why a revision of `file` to `content` must not be saved, if it mustn't.
    func refusal(revising file: String, content: String) -> Refusal? {
        guard let body = readPage(file)?.body else { return nil }
        let new = Lines(content + "\n").lines.map(Self.plain)
        let newSet = Set(new)
        let ranges = editRanges(of: file)
        let sections = ranges.filter { $0.key != "(page)" }
        func section(of line: String) -> EditRange? {
            let i = Lines(body).lines.firstIndex { Self.plain($0) == line }
            return sections.last { r in i.map { r.lines.contains($0) } ?? false } ?? ranges.last
        }
        if let marker = editMarker, marker.str("file") == file {
            let open = (marker.str("text") ?? "").components(separatedBy: "\n").map(Self.plain)
            let kept = new.count >= open.count && (0...(new.count - open.count)).contains { Array(new[$0..<$0 + open.count]) == open }
            if !kept {
                let r = ranges.first { $0.key == marker.str("key") }
                return Refusal(reason: .open, section: marker.str("section") ?? "", edits: [], current: r?.text ?? marker.str("text") ?? "")
            }
        }
        let missing = protectedLines(of: file).compactMap { p in p.lines.first { !newSet.contains($0) }.map { (p.edit, $0) } }
        if let (_, line) = missing.first {
            let r = section(of: line)
            return Refusal(reason: .protected, section: r?.section ?? "", edits: missing.compactMap { $0.0.str("id") }, current: r?.text ?? "")
        }
        if let line = Self.quotedLines(Lines(body).lines).first(where: { !newSet.contains($0) }) {
            let r = section(of: line)
            return Refusal(reason: .quote, section: r?.section ?? "", edits: [], current: r?.text ?? "")
        }
        return nil
    }

    // MARK: Releases

    /// The person lets Sophia change the lines of these edits. Each gets its own entry, so each can be undone.
    @discardableResult
    public func releaseEdits(_ editIDs: [String], session: String) throws -> [JSONObject] {
        try locked {
            try editIDs.filter { id in
                guard let edit = transcript.first(where: { $0.str("id") == id }), let file = edit.str("file") else { return false }
                return protectedLines(of: file).contains { $0.edit.str("id") == id }
            }.map { id in
                let edit = transcript.first { $0.str("id") == id }!
                return try appendTranscriptLocked(["role": .string("person"), "purpose": .string("release_edit"),
                                            "session": .string(session), "entry": .string(id), "page": .string(actionFile(edit) ?? "")])
            }
        }
    }

    /// Takes a release back: the edit's lines are protected again.
    public func undoRelease(_ releaseID: String, session: String) throws {
        try locked {
            guard let release = transcript.first(where: { $0.str("id") == releaseID }), isReleaseUndoable(release) else { throw StoreError.notFound }
            _ = try appendTranscriptLocked(["role": .string("client"), "purpose": .string("undo_release"), "page": .string(actionFile(release) ?? ""),
                                            "session": .string(session), "entry": .string(releaseID)])
        }
    }
}
