import Foundation
import CryptoKit

/// One notebook directory, as defined in DATA-MODEL.md:
///
///     notebook.json            chapters and page order
///     pages/<file>.md          pages
///     pages/<file>.previous.md one previous version per page
///     transcript.jsonl         conversation and page writes
///     learning.jsonl           goals, notes, takes, corrections, briefings
///
/// Two processes write through this class: the app, and Sophia's tool server (sophia-mcp),
/// which saves her pages and goals. Every write takes a lock on the notebook and rereads
/// the files first, so neither works from a stale copy.
public final class NotebookStore {
    public let url: URL
    public private(set) var meta: JSONObject
    public private(set) var transcript: [JSONObject] = []
    public private(set) var learning: [JSONObject] = []

    public var name: String { url.lastPathComponent }
    var metaURL: URL { url.appendingPathComponent("notebook.json") }
    var transcriptURL: URL { url.appendingPathComponent("transcript.jsonl") }
    var learningURL: URL { url.appendingPathComponent("learning.jsonl") }
    public var pagesURL: URL { url.appendingPathComponent("pages") }

    public init(url: URL) throws {
        self.url = url
        let fm = FileManager.default
        try fm.createDirectory(at: url.appendingPathComponent("pages"), withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: url.appendingPathComponent("notebook.json")),
           let obj = (try? JSONDecoder().decode(JSON.self, from: data))?.object {
            meta = obj
        } else {
            meta = ["chapters": .array([]), "unfiled": .array([])]
            try writeMeta()
        }
        transcript = Self.readLines(transcriptURL)
        learning = Self.readLines(learningURL)
        recoverOrphanPages()
    }

    /// Rereads the notebook files, for changes made by the other process.
    public func reload() {
        if let data = try? Data(contentsOf: metaURL), let obj = (try? JSONDecoder().decode(JSON.self, from: data))?.object { meta = obj }
        transcript = Self.readLines(transcriptURL)
        learning = Self.readLines(learningURL)
    }

    private var lockDepth = 0
    private var lockFD: Int32 = -1

    /// Runs a write under an exclusive lock on the notebook, after rereading its files.
    func locked<T>(_ body: () throws -> T) rethrows -> T {
        if lockDepth == 0 {
            lockFD = open(url.appendingPathComponent(".lock").path, O_CREAT | O_RDWR, 0o644)
            if lockFD >= 0 { flock(lockFD, LOCK_EX) }
            reload()
        }
        lockDepth += 1
        defer {
            lockDepth -= 1
            if lockDepth == 0, lockFD >= 0 { flock(lockFD, LOCK_UN); close(lockFD); lockFD = -1 }
        }
        return try body()
    }

    static func readLines(_ url: URL) -> [JSONObject] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").compactMap { JSON.parse(String($0))?.object }
    }

    // MARK: Writing

    static func now() -> String { ISO8601DateFormatter().string(from: Date()) }

    func writeMeta() throws {
        try Data(JSON.object(meta).pretty.utf8).write(to: metaURL, options: .atomic)
    }

    func append(_ obj: JSONObject, to url: URL) throws {
        let line = Data((obj.line + "\n").utf8)
        if let h = try? FileHandle(forWritingTo: url) {
            defer { try? h.close() }
            try h.seekToEnd()
            try h.write(contentsOf: line)
        } else {
            try line.write(to: url, options: .atomic)
        }
    }

    /// Next id with the given prefix, e.g. "t-" -> "t-0042", "n-" -> "n-12".
    func nextID(_ prefix: String, in items: [JSONObject], width: Int = 0) -> String {
        let used = items.compactMap { $0.str("id") }.filter { $0.hasPrefix(prefix) }
            .compactMap { Int($0.dropFirst(prefix.count)) }
        let n = (used.max() ?? 0) + 1
        return prefix + (width > 0 ? String(format: "%0\(width)d", n) : String(n))
    }

    /// Appends a conversation entry, stamping its id and time.
    @discardableResult
    public func appendTranscript(_ fields: JSONObject) throws -> JSONObject {
        try locked { try appendTranscriptLocked(fields) }
    }

    func appendTranscriptLocked(_ fields: JSONObject) throws -> JSONObject {
        var obj = fields
        obj["id"] = .string(nextID("t-", in: transcript, width: 4))
        obj["at"] = .string(Self.now())
        try append(obj, to: transcriptURL)
        transcript.append(obj)
        return obj
    }

    /// Appends a learning record. `by`, `id`, `at`, and `session` are always set here,
    /// never taken from the writer.
    @discardableResult
    public func appendLearning(_ fields: JSONObject, by: String, session: String) throws -> JSONObject {
        try locked { try appendLearningLocked(fields, by: by, session: session) }
    }

    func appendLearningLocked(_ fields: JSONObject, by: String, session: String) throws -> JSONObject {
        var obj = fields
        for k in ["id", "at", "by", "session"] { obj.removeValue(forKey: k) }
        let prefix = obj.str("kind") == "goal" ? "g-" : "n-"
        let all = learning
        obj["id"] = .string(nextID(prefix, in: all))
        obj["at"] = .string(Self.now())
        obj["by"] = .string(by)
        obj["session"] = .string(session)
        try append(obj, to: learningURL)
        learning.append(obj)
        return obj
    }

    /// Removes records and every record whose `replaces` chain leads to them,
    /// then rewrites learning.jsonl atomically. Returns what was removed, for undo.
    public func deleteLearning(_ id: String) throws -> [JSONObject] {
        try locked { try deleteLearningLocked(id) }
    }

    func deleteLearningLocked(_ id: String) throws -> [JSONObject] {
        var doomed: Set<String> = [id]
        var changed = true
        while changed {
            changed = false
            for r in learning {
                if let rid = r.str("id"), let rep = r.str("replaces"), doomed.contains(rep), !doomed.contains(rid) {
                    doomed.insert(rid); changed = true
                }
            }
        }
        let removed = learning.filter { doomed.contains($0.str("id") ?? "") }
        learning.removeAll { doomed.contains($0.str("id") ?? "") }
        try rewriteLearning()
        return removed
    }

    public func restoreLearning(_ records: [JSONObject]) throws {
        try locked {
            learning.append(contentsOf: records)
            learning.sort { ($0.str("at") ?? "") < ($1.str("at") ?? "") }
            try rewriteLearning()
        }
    }

    func rewriteLearning() throws {
        let text = learning.map { $0.line + "\n" }.joined()
        try Data(text.utf8).write(to: learningURL, options: .atomic)
    }

    // MARK: Sessions

    /// A new session id for this opening of the notebook.
    public func newSessionID() -> String {
        let used = (transcript + learning).compactMap { $0.str("session") }
            .compactMap { Int($0.dropFirst(2)) }
        return "s-" + String((used.max() ?? 0) + 1)
    }

    /// Keeps this notebook out of other notebooks' view (see LibraryStore).
    public func setSeparate(_ on: Bool) throws {
        try locked {
            meta["separate"] = .bool(on)
            try writeMeta()
        }
    }

    /// Something the person said. Their page edits and releases are also `person` entries, with a `purpose`.
    public static func isPersonMessage(_ entry: JSONObject) -> Bool {
        entry.str("role") == "person" && entry["purpose"] == nil
    }

    public var hasEarlierConversation: Bool {
        transcript.contains { Self.isPersonMessage($0) || $0.str("role") == "sophia" }
    }

    /// The person's messages that no checkpoint covers yet, across sessions. A checkpoint entry names
    /// the last message it covered in `through`; an older entry without one covers everything before it.
    /// Messages a checkpoint covered are never offered again, so a deleted note can't be recreated.
    public var unnotedMessages: [JSONObject] {
        var covered = -1
        for (i, e) in transcript.enumerated() where e.str("purpose") == "checkpoint" {
            if let t = e.str("through"), let j = transcript.firstIndex(where: { $0.str("id") == t }) {
                covered = max(covered, j)
            } else if e["through"] == nil {
                covered = max(covered, i)
            }
        }
        return transcript[(covered + 1)...].filter(Self.isPersonMessage)
    }

    /// When the person or Sophia last said something here. A briefing counts.
    public var lastConversationAt: Date? {
        transcript.last { Self.isPersonMessage($0) || $0.str("role") == "sophia" }
            .flatMap { $0.str("at") }
            .flatMap { ISO8601DateFormatter().date(from: $0) }
    }

    /// True when the conversation has been quiet for at least `gap`: the person is coming back,
    /// not relaunching the app or pausing for a moment.
    public func isReturn(after gap: TimeInterval, now: Date = Date()) -> Bool {
        guard let last = lastConversationAt else { return false }
        return now.timeIntervalSince(last) >= gap
    }

    public var claudeSession: String? {
        get { meta.str("claude_session") }
        set {
            locked {
                meta["claude_session"] = newValue.map { .string($0) } ?? .null
                try? writeMeta()
            }
        }
    }

    // MARK: Pages

    public struct Page: Identifiable, Equatable {
        public let file: String
        public let title: String
        public var id: String { file }
        public init(file: String, title: String) { self.file = file; self.title = title }
    }

    public var pageFiles: [String] {
        let chaptered = (meta["chapters"]?.array ?? []).flatMap { $0["pages"]?.array ?? [] }.compactMap(\.string)
        let unfiled = (meta["unfiled"]?.array ?? []).compactMap(\.string)
        return chaptered + unfiled
    }

    public var pages: [Page] {
        pageFiles.map { Page(file: $0, title: readPage($0)?.title ?? $0) }
    }

    /// A chapter groups pages in the book. Its number is optional ("0" in "Chapter 0: Foundations").
    public struct Chapter: Identifiable, Equatable {
        public let number: String?
        public let title: String
        public let pages: [Page]
        public var id: String { (number ?? "") + "|" + title }
        /// "Chapter 0: Foundations", or the title alone.
        public var heading: String { number.map { "Chapter \($0): \(title)" } ?? title }
    }

    public var chapters: [Chapter] {
        (meta["chapters"]?.array ?? []).compactMap(\.object).filter { !($0["pages"]?.array ?? []).isEmpty }.map { c in
            Chapter(number: c.str("number"), title: c.str("title") ?? "Untitled",
                    pages: (c["pages"]?.array ?? []).compactMap(\.string).map { Page(file: $0, title: readPage($0)?.title ?? $0) })
        }
    }

    /// Pages not in any chapter, in book order.
    public var unfiledPages: [Page] {
        (meta["unfiled"]?.array ?? []).compactMap(\.string).map { Page(file: $0, title: readPage($0)?.title ?? $0) }
    }

    public func chapter(of file: String) -> Chapter? {
        chapters.first { $0.pages.contains { $0.file == file } }
    }

    /// Splits a leading section number from a title: "0.1 Surprise" → ("0.1", "Surprise").
    /// Also reads chapter headings such as "Chapter 0: Foundations".
    public static func splitNumber(_ title: String) -> (number: String?, rest: String) {
        let t = title.trimmingCharacters(in: .whitespaces)
        let pattern = #"^(?:(?:chapter|part)\s+)?(\d+(?:\.\d+)*)(?:[.:)]\s*|\s+)(?:[—–-]\s*)?(.+)$"#
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let m = re.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)),
              let n = Range(m.range(at: 1), in: t), let r = Range(m.range(at: 2), in: t) else { return (nil, t) }
        return (String(t[n]), String(t[r]))
    }

    /// A section of a page: one of its `##` or `###` headings.
    public struct Section: Equatable {
        public let level: Int
        public let title: String
        public let index: Int          // position among the page's sections, as the reader counts them
    }

    /// The `##` and `###` headings of a page, outside code fences, in order.
    public func sections(of file: String) -> [Section] {
        guard let body = readPage(file)?.body else { return [] }
        return Self.sections(in: body)
    }

    static func sections(in body: String) -> [Section] {
        headings(Lines(body).lines).filter { $0.level >= 2 && !$0.title.isEmpty }.enumerated().map {
            Section(level: $1.level, title: $1.title, index: $0)
        }
    }

    /// Finds a section by its title, ignoring case, spacing, and punctuation.
    public func section(_ title: String, of file: String) -> Section? {
        func clean(_ s: String) -> String { s.lowercased().filter { $0.isLetter || $0.isNumber } }
        let want = clean(title)
        return sections(of: file).first { clean($0.title) == want }
    }

    /// The text of one section: its heading through to the next heading at the same or a higher level.
    public func sectionText(_ section: Section, of file: String) -> String? {
        guard let body = readPage(file)?.body else { return nil }
        return Self.editRanges(in: body).first { $0.index == section.index }?.text
    }

    /// Puts pages in a chapter, in the order given, after any pages already there. The chapter is
    /// matched by number or title, or created; a new numbered chapter goes in number order.
    /// Pages leave wherever they were. Chapters left empty are removed.
    public func fileInChapter(_ files: [String], chapter heading: String) throws -> Chapter {
        try locked {
            let known = Set(pageFiles)
            guard !files.isEmpty, files.allSatisfy(known.contains) else { throw StoreError.notFound }
            let (number, title) = Self.splitNumber(heading)
            var chapters = (meta["chapters"]?.array ?? []).compactMap(\.object)
            func without(_ list: JSON?) -> JSON { .array((list?.array ?? []).filter { !files.contains($0.string ?? "") }) }
            meta["unfiled"] = without(meta["unfiled"])
            for i in chapters.indices { chapters[i]["pages"] = without(chapters[i]["pages"]) }
            let same: (JSONObject) -> Bool = { c in
                if let number, c.str("number") == number { return true }
                return c.str("title")?.lowercased() == title.lowercased()
            }
            if let i = chapters.firstIndex(where: same) {
                chapters[i]["pages"] = .array((chapters[i]["pages"]?.array ?? []) + files.map { .string($0) })
                if let number { chapters[i]["number"] = .string(number) }
                chapters[i]["title"] = .string(title)
            } else {
                var c: JSONObject = ["title": .string(title), "pages": .array(files.map { .string($0) })]
                if let number { c["number"] = .string(number) }
                let at = number.flatMap { n in chapters.firstIndex { ($0.str("number")).map { Self.numberSorts($0, after: n) } ?? true } } ?? chapters.count
                chapters.insert(c, at: at)
            }
            chapters.removeAll { ($0["pages"]?.array ?? []).isEmpty }
            meta["chapters"] = .array(chapters.map { .object($0) })
            try writeMeta()
            return self.chapters.first { $0.pages.contains { $0.file == files[0] } }!
        }
    }

    /// Compares section numbers part by part: "10" comes after "9".
    static func numberSorts(_ a: String, after b: String) -> Bool {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }, y = b.split(separator: ".").map { Int($0) ?? 0 }
        return x.lexicographicallyPrecedes(y) == false && x != y
    }

    public func readPage(_ file: String) -> (title: String, body: String)? {
        guard let text = try? String(contentsOf: pagesURL.appendingPathComponent(file), encoding: .utf8) else { return nil }
        return Self.splitFrontmatter(text)
    }

    static func splitFrontmatter(_ text: String) -> (title: String, body: String) {
        guard text.hasPrefix("---\n"), let end = text.range(of: "\n---\n", range: text.index(text.startIndex, offsetBy: 4)..<text.endIndex) else {
            return ("Untitled", text)
        }
        let header = text[text.index(text.startIndex, offsetBy: 4)..<end.lowerBound]
        var title = "Untitled"
        for line in header.split(separator: "\n") where line.hasPrefix("title:") {
            title = line.dropFirst(6).trimmingCharacters(in: .whitespaces)
            if let data = title.data(using: .utf8), let s = try? JSONDecoder().decode(String.self, from: data) { title = s }
        }
        return (title, String(text[end.upperBound...]))
    }

    /// A page file present on disk but missing from notebook.json (for example after a crash
    /// part-way through Accept) is listed as unfiled, so nothing accepted is lost.
    func recoverOrphanPages() {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: pagesURL.path)) ?? []
        let known = Set(pageFiles)
        let orphans = files.filter { $0.hasSuffix(".md") && !$0.hasSuffix(".previous.md") && !known.contains($0) }.sorted()
        guard !orphans.isEmpty else { return }
        var unfiled = meta["unfiled"]?.array ?? []
        unfiled.append(contentsOf: orphans.map { .string($0) })
        meta["unfiled"] = .array(unfiled)
        try? writeMeta()
    }

    // MARK: Page writes

    /// Sophia saves pages directly. A new page is added to the book; a revision keeps the
    /// page's file and saves the version it replaces as <file>.previous.md. Writes, in order:
    /// the page file, then notebook.json, then the transcript entry.
    ///
    /// A revision that would change the section the person has open, drop or alter lines they
    /// wrote (unless they released that edit), or drop a quote of their words is not saved:
    /// the returned entry has `refused: true`, with Sophia's `why` if she gave one.
    @discardableResult
    public func writePage(title: String, content: String, revising file: String?, session: String, toolUseID: String,
                          why: String? = nil) throws -> JSONObject {
        try locked {
            let titleJSON = JSON.string(title).line
            let text = "---\ntitle: \(titleJSON)\n---\n" + content + "\n"
            if let file, pageFiles.contains(file), let refusal = refusal(revising: file, content: content) {
                var entry: JSONObject = ["role": .string("tool"), "tool": .string("write_page"), "session": .string(session),
                                         "tool_use": .string(toolUseID), "file": .string(file), "title": .string(readPage(file)?.title ?? title),
                                         "refused": .bool(true), "reason": .string(refusal.reason.rawValue),
                                         "section": .string(refusal.section), "current": .string(refusal.current),
                                         "edits": .array(refusal.edits.map { .string($0) })]
                if let first = refusal.edits.first { entry["edit"] = .string(first) }
                if let why = why?.trimmingCharacters(in: .whitespacesAndNewlines), !why.isEmpty { entry["why"] = .string(why) }
                return try appendTranscriptLocked(entry)
            }
            if let file, pageFiles.contains(file) {
                let current = pagesURL.appendingPathComponent(file)
                let previous = pagesURL.appendingPathComponent(Self.previousName(file))
                try? FileManager.default.removeItem(at: previous)
                try FileManager.default.copyItem(at: current, to: previous)
                try Data(text.utf8).write(to: current, options: .atomic)
                return try appendTranscriptLocked(["role": .string("tool"), "tool": .string("write_page"), "session": .string(session),
                                                   "tool_use": .string(toolUseID), "file": .string(file), "title": .string(title),
                                                   "revised": .bool(true)])
            }
            let name = uniqueFile(for: title)
            try Data(text.utf8).write(to: pagesURL.appendingPathComponent(name), options: .atomic)
            var unfiled = meta["unfiled"]?.array ?? []
            unfiled.append(.string(name))
            meta["unfiled"] = .array(unfiled)
            try writeMeta()
            return try appendTranscriptLocked(["role": .string("tool"), "tool": .string("write_page"), "session": .string(session),
                                               "tool_use": .string(toolUseID), "file": .string(name), "title": .string(title)])
        }
    }

    static func previousName(_ file: String) -> String { String(file.dropLast(3)) + ".previous.md" }

    public func hasPreviousVersion(_ file: String) -> Bool {
        FileManager.default.fileExists(atPath: pagesURL.appendingPathComponent(Self.previousName(file)).path)
    }

    public func readPreviousVersion(_ file: String) -> (title: String, body: String)? {
        readPage(Self.previousName(file))
    }

    /// The transcript entry for each page Sophia wrote, oldest first. Refused writes changed nothing and aren't included.
    public var pageWrites: [JSONObject] { transcript.filter { $0.str("tool") == "write_page" && $0["refused"] != .bool(true) } }

    /// A write that can still be undone: Sophia's page write or the person's edit, with nothing written to that page since.
    public func isLatestWrite(_ entryID: String) -> Bool {
        guard let i = transcript.firstIndex(where: { $0.str("id") == entryID }), let file = transcript[i].str("file") else { return false }
        return !transcript[(i + 1)...].contains { e in
            e.str("file") == file && (e.str("purpose") == "edit_page" || e.str("purpose") == "undo_page"
                || (e.str("tool") == "write_page" && e["refused"] != .bool(true)))
        }
    }

    public func pageWrite(toolUse id: String) -> JSONObject? { pageWrites.last { $0.str("tool_use") == id } }

    public enum StoreError: Error, LocalizedError {
        case notFound
        public var errorDescription: String? { "That change can't be undone any more." }
    }

    /// Undoes a page write: removes a page Sophia added, or puts back the previous version after
    /// her revision or the person's edit. Only the latest write to a page can be undone.
    public func undoPageWrite(_ entryID: String, session: String) throws {
        try locked {
            guard let e = transcript.first(where: { $0.str("id") == entryID }), let file = e.str("file"),
                  e["refused"] != .bool(true), isLatestWrite(entryID) else { throw StoreError.notFound }
            let url = pagesURL.appendingPathComponent(file)
            if e["revised"] == .bool(true) || e.str("purpose") == "edit_page" {
                let previous = pagesURL.appendingPathComponent(Self.previousName(file))
                guard FileManager.default.fileExists(atPath: previous.path) else { throw StoreError.notFound }
                try? FileManager.default.removeItem(at: url)
                try FileManager.default.moveItem(at: previous, to: url)
            } else {
                try? FileManager.default.removeItem(at: url)
                meta["unfiled"] = .array((meta["unfiled"]?.array ?? []).filter { $0.string != file })
                if let chapters = meta["chapters"]?.array {
                    meta["chapters"] = .array(chapters.map { ch in
                        guard var o = ch.object else { return ch }
                        o["pages"] = .array((o["pages"]?.array ?? []).filter { $0.string != file })
                        return .object(o)
                    })
                }
                try writeMeta()
            }
            try appendTranscriptLocked(["role": .string("client"), "session": .string(session), "purpose": .string("undo_page"),
                                        "entry": .string(entryID), "file": .string(file)])
        }
    }

    public func isUndone(_ entryID: String) -> Bool {
        transcript.contains { $0.str("purpose") == "undo_page" && $0.str("entry") == entryID }
    }

    // MARK: Earlier drafts

    /// Notebooks from before Sophia saved pages directly may hold drafts nobody decided on.
    /// They are saved as pages when the notebook opens, so nothing Sophia wrote is hidden.
    public func fileUndecidedDrafts(session: String) {
        try? locked {
            var decided: Set<String> = []
            for e in transcript where e.str("role") == "client" {
                if let p = e.str("proposal"), let d = e.str("decision"), ["accept", "reject", "replaced"].contains(d) { decided.insert(p) }
                if let p = e.str("proposal"), e.str("purpose") == "filed_draft" { decided.insert(p) }
            }
            for e in transcript where e.str("role") == "tool" {
                guard let pid = e.str("proposal"), !decided.contains(pid), let payload = e["payload"]?.object else { continue }
                let w = try writePage(title: payload.str("title") ?? "Untitled", content: payload.str("content") ?? "",
                                      revising: nil, session: session, toolUseID: e.str("tool_use") ?? "")
                try appendTranscriptLocked(["role": .string("client"), "session": .string(session), "purpose": .string("filed_draft"),
                                            "proposal": .string(pid), "file": w["file"] ?? .null])
            }
        }
    }

    // MARK: Goals Sophia writes

    /// Sophia records a goal she heard in the conversation, or revises one. Her goals are provisional
    /// until the person confirms them. She can't mark a goal met or dropped, and criteria only grow,
    /// because notes refer to criteria by position ("g-1#2").
    @discardableResult
    public func writeGoal(text: String, criteria: [String], revising goalID: String?, quote: String?, session: String) throws -> JSONObject {
        try locked {
            var record: JSONObject = ["kind": .string("goal"), "text": .string(text)]
            var all = criteria
            if let goalID, let current = goals.first(where: { rootID(of: $0.str("id") ?? "") == rootID(of: goalID) }) {
                record["replaces"] = current["id"]!
                record["status"] = .string(current.str("status") ?? "working")
                let existing = (current["criteria"]?.array ?? []).compactMap(\.string)
                all = existing + criteria.filter { !existing.contains($0) }
            } else {
                record["status"] = .string("working")
            }
            record["criteria"] = .array(all.map { .string($0) })
            let personMessages = transcript.filter(Self.isPersonMessage)
            if let q = quote, let entry = personMessages.last(where: { RecordChecks.normalize($0.str("text") ?? "").contains(RecordChecks.normalize(q)) }), !q.isEmpty {
                record["quote"] = .object(["entry": entry["id"]!, "text": .string(q)])
            }
            if let last = personMessages.last?.str("id") { record["refs"] = .array([.string(last)]) }
            return try appendLearningLocked(record, by: "sophia", session: session)
        }
    }

    /// Kinds Sophia may note during the conversation, through the `note` tool.
    public static let liveNoteKinds: Set<String> = ["attempt", "question", "follow_up", "background"]
    /// Kinds shown as Sophia's notes.
    public static let noteKinds: Set<String> = ["attempt", "read", "question", "next_step", "follow_up", "background"]
    /// More than this many notes in one session is a log, not notes. Revising doesn't count.
    public static let liveNotesPerSession = 8

    /// A note Sophia writes during the conversation. It passes the same checks as checkpoint notes:
    /// quotes must be the person's exact words from this session, and every note must rest on
    /// something they said or did. Sophia may revise her own notes (for example, to close a
    /// follow-up), never the person's corrections. Returns the saved record, or why it wasn't saved.
    public func writeNote(_ fields: JSONObject, quote: String?, revising noteID: String?, session: String) throws -> (saved: JSONObject?, problems: [String]) {
        try locked {
            var obj = fields
            // Sophia gives the words; the store finds which of the person's messages this session they're from.
            if let q = quote, !q.isEmpty {
                let entry = transcript.last { $0.str("session") == session && Self.isPersonMessage($0)
                    && RecordChecks.normalize($0.str("text") ?? "").contains(RecordChecks.normalize(q)) }
                obj["quote"] = .object(["entry": entry?["id"] ?? .string(""), "text": .string(q)])
            }
            if let noteID {
                guard let current = currentLearning.first(where: { $0.str("id") == noteID }),
                      current.str("by") == "sophia", Self.liveNoteKinds.contains(current.str("kind") ?? "") else {
                    return (nil, ["There is no note \(noteID) of yours that can be revised."])
                }
                if correction(of: noteID) != nil { return (nil, ["The person corrected \(noteID); leave it as they have it."]) }
                if obj["kind"] == nil { obj["kind"] = current["kind"] }
            } else {
                let mine = learning.filter { $0.str("session") == session && $0.str("by") == "sophia"
                    && Self.liveNoteKinds.contains($0.str("kind") ?? "") && $0["replaces"] == nil }
                if mine.count >= Self.liveNotesPerSession {
                    return (nil, ["You've written \(mine.count) notes this session. Revise one instead of adding another."])
                }
            }
            let out = RecordChecks(store: self).check([.object(obj)], allowedKinds: Self.liveNoteKinds, session: session)
            guard var rec = out.kept.first else { return (nil, out.notes) }
            if let noteID { rec["replaces"] = .string(noteID) }
            let saved = try appendLearningLocked(rec, by: "sophia", session: session)
            _ = try appendTranscriptLocked(["role": .string("tool"), "tool": .string("note"), "session": .string(session),
                                            "record": saved["id"]!, "revised": .bool(noteID != nil)])
            return (saved, out.notes)
        }
    }

    /// Notes to show: each chain's latest version by Sophia, with any correction shown on it.
    public var shownNotes: [JSONObject] {
        let revised = Set(learning.filter { $0.str("kind") != "correction" }.compactMap { $0.str("replaces") })
        return learning.filter { Self.noteKinds.contains($0.str("kind") ?? "") && !revised.contains($0.str("id") ?? "") }
    }

    /// A goal is provisional while its current version is Sophia's.
    public func isProvisional(_ goal: JSONObject) -> Bool { goal.str("by") == "sophia" }

    func uniqueFile(for title: String) -> String {
        let base = title.lowercased().map { $0.isLetter || $0.isNumber ? String($0) : "-" }.joined()
            .split(separator: "-").prefix(8).joined(separator: "-")
        let stem = base.isEmpty ? "page" : base
        var name = stem + ".md", n = 2
        while FileManager.default.fileExists(atPath: pagesURL.appendingPathComponent(name).path) || pageFiles.contains(name) {
            name = "\(stem)-\(n).md"; n += 1
        }
        return name
    }

    // MARK: Learning views

    /// The current version of each chain: records that nothing else replaces.
    public var currentLearning: [JSONObject] {
        let replaced = Set(learning.compactMap { $0.str("replaces") })
        return learning.filter { !replaced.contains($0.str("id") ?? "") }
    }

    /// The first id in a record's `replaces` chain. Goal references always use it.
    public func rootID(of id: String) -> String {
        var current = id
        var seen: Set<String> = []
        while let r = learning.first(where: { $0.str("id") == current }), let prev = r.str("replaces"), !seen.contains(prev) {
            seen.insert(current); current = prev
        }
        return current
    }

    public var goals: [JSONObject] {
        currentLearning.filter { $0.str("kind") == "goal" }
    }

    public func record(_ id: String) -> JSONObject? { learning.first { $0.str("id") == id } }

    /// What a correction replaced, if the record was corrected by the person.
    public func correction(of id: String) -> JSONObject? {
        learning.last { $0.str("kind") == "correction" && $0.str("replaces") == id }
    }
}
