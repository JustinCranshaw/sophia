import Foundation
import CryptoKit
import Darwin

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
            lockFD = Darwin.open(url.appendingPathComponent(".lock").path, O_CREAT | O_RDWR, 0o644)
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

    /// Only the application reconciles unrecorded disk changes. Hashes do not establish authorship;
    /// these records preserve visibility, not permission to undo. Tool processes use the plain initializer.
    public static func open(url: URL) throws -> NotebookStore {
        let store = try NotebookStore(url: url)
        try store.locked {
            let launchFiles = Set(store.pageFiles)
            let recordedFiles = Set(store.transcript.compactMap { $0.str("file") })
            let files = try FileManager.default.contentsOfDirectory(atPath: store.pagesURL.path)
            for file in files.sorted() where file.hasSuffix(".md") && !file.hasSuffix(".previous.md") {
                guard let hash = store.pageHash(file) else { continue }
                let latest = store.transcript.last { $0.str("file") == file && (($0.str("tool") == "write_page" && $0["refused"] != .bool(true)) || ["edit_page", "undo_page"].contains($0.str("purpose") ?? "")) }
                let orphan = !launchFiles.contains(file) && !recordedFiles.contains(file)
                let revision = latest?.str("hash").map { $0 != hash && store.pageHash(Self.previousName(file)) == $0 } ?? false
                if orphan || revision {
                    var e: JSONObject = ["role": .string("client"), "tool": .string("write_page"), "recovered": .bool(true),
                                         "file": .string(file), "page": .string(file), "hash": .string(hash)]
                    if revision { e["revised"] = .bool(true) }
                    _ = try store.appendTranscriptLocked(e)
                }
            }
            store.recoverOrphanPages()
            store.fileUndecidedDrafts(session: store.newSessionID())
        }
        return store
    }

    public static func thread(of entry: JSONObject) -> String { entry.str("page") ?? "" }
    public static func isMessage(_ e: JSONObject) -> Bool {
        ["person", "sophia"].contains(e.str("role") ?? "") && e["purpose"] == nil
    }
    public func threadEntries(for thread: String) -> [JSONObject] {
        transcript.filter { Self.thread(of: $0) == thread }
    }
    func clearPosition(for thread: String, before: String?) -> Int {
        transcript.lastIndex { Self.thread(of: $0) == thread && $0.str("purpose") == "clear" } ?? -1
    }
    public func cursor(for thread: String, before: String? = nil) -> Int {
        guard let checkpoint = transcript.last(where: { $0.str("purpose") == "checkpoint" }) else { return -1 }
        let position = transcript.firstIndex { $0.str("id") == (checkpoint.str("through") ?? checkpoint.str("id")) } ?? -1
        // A retry must retain outcomes after its original question, even when a later
        // conversation has already checkpointed beyond that interrupted turn.
        guard let before, let boundary = transcript.firstIndex(where: { $0.str("id") == before }) else { return position }
        return min(position, boundary)
    }
    public func window(for thread: String, before: String? = nil) -> [JSONObject] {
        let start = max(clearPosition(for: thread, before: before), cursor(for: thread, before: before)) + 1
        let end = transcript.count
        guard start < end else { return [] }
        return transcript[start..<end].filter { Self.thread(of: $0) == thread && $0["recovered"] != .bool(true) && $0.str("id") != before }
    }
    public func carried(for thread: String, before: String? = nil) -> [JSONObject] {
        let start = clearPosition(for: thread, before: before) + 1
        let end = min(transcript.count, cursor(for: thread, before: before) + 1)
        guard start < end else { return [] }
        return Array(transcript[start..<end].filter { Self.thread(of: $0) == thread && Self.isMessage($0) && $0.str("id") != before }.suffix(6))
    }
    public func creatingExchange(for file: String) -> [JSONObject] {
        guard let creation = transcript.firstIndex(where: { $0.str("tool") == "write_page" && $0.str("file") == file
                  && $0["refused"] != .bool(true) && $0["revised"] != .bool(true) && $0["recovered"] != .bool(true) }) else { return [] }
        // An explicitly agent-commissioned entry has no person creating question.
        guard !(transcript[creation].str("tool_use") ?? "").hasPrefix("almanac:") else { return [] }
        let origin = Self.thread(of: transcript[creation])
        guard origin != file, let begin = transcript[..<creation].lastIndex(where: { Self.thread(of: $0) == origin && Self.isPersonMessage($0) }) else { return [] }
        let end = transcript[(begin + 1)...].firstIndex { Self.thread(of: $0) == origin && Self.isPersonMessage($0) } ?? transcript.count
        let turn = transcript[begin..<end].filter { Self.thread(of: $0) == origin && Self.isMessage($0) }
        return [transcript[begin]] + Array(turn.filter { $0.str("role") == "sophia" }.prefix(1))
    }
    public func notes(for thread: String) -> [JSONObject] {
        let messages = Set(threadEntries(for: thread).filter(Self.isMessage).compactMap { $0.str("id") })
        return shownNotes.filter { note in
            let refs = Set((note["refs"]?.array ?? []).compactMap(\.string))
            return (!thread.isEmpty && refs.contains("p:" + thread)) || !refs.intersection(messages).isEmpty
                || note["quote"]?["entry"]?.string.map(messages.contains) == true
        }
    }
    public enum NextStep { case wait, reply }
    public static func nextStep(thread: String, pending: Bool) -> NextStep { pending ? .wait : .reply }
    public static func isPending(thread: String, running: String?, queued: [String]) -> Bool {
        running == thread || queued.contains(thread)
    }

    public enum CheckpointResult: Equatable { case failed, saved }
    /// Validate the whole reply before touching notes or memory. Rejection reasons stay private.
    public func finishCheckpoint(_ text: String, failed: Bool, through: String, entries: Set<String>, session: String, catchUp: Bool) throws -> CheckpointResult {
        try locked {
            guard !failed, let value = RecordChecks.extractJSON(text),
                  value.array != nil || value["notes"]?.array != nil else { return .failed }
            let (items, memory, parsed) = RecordChecks.parseCheckpoint(text)
            guard parsed else { return .failed }
            let out = RecordChecks(store: self).check(items, allowedKinds: RecordChecks.checkpointKinds, quoteEntries: entries)
            guard items.isEmpty || !out.kept.isEmpty else { return .failed }
            var kept: [JSON] = []
            for rec in out.kept { kept.append(try appendLearningLocked(rec, by: "sophia", session: session)["id"]!) }
            if let memory { _ = try setMemory(memory, session: session) }
            try appendTranscriptLocked(["role": .string("client"), "page": .string(""), "session": .string(session),
                                        "purpose": .string("checkpoint"), "through": .string(through),
                                        "catch_up": .bool(catchUp), "kept": .array(kept)])
            return .saved
        }
    }

    // MARK: Writing

    static func now() -> String { ISO8601DateFormatter().string(from: Date()) }

    func saveAlmanacMetadata(_ value: JSON) throws {
        meta["almanac"] = value
        try writeMeta()
    }

    func writeMeta() throws {
        try Data(JSON.object(meta).pretty.utf8).write(to: metaURL, options: .atomic)
    }

    func append(_ obj: JSONObject, to url: URL) throws {
        let line = Data((obj.line + "\n").utf8)
        guard FileManager.default.fileExists(atPath: url.path) else {
            try line.write(to: url, options: .atomic)
            return
        }
        // An existing log that cannot be opened must stay intact, never become one new line.
        let h = try FileHandle(forWritingTo: url)
        defer { try? h.close() }
        let end = try h.seekToEnd()
        if end > 0 {
            let read = try FileHandle(forReadingFrom: url)
            defer { try? read.close() }
            try read.seek(toOffset: end - 1)
            let last = try read.read(upToCount: 1)
            if last != Data([0x0a]) { try h.write(contentsOf: Data([0x0a])) }
        }
        try h.write(contentsOf: line)
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
        if obj["page"] == nil { obj["page"] = .string("") }
        if ["checkpoint", "briefing", "briefing_failed", "briefing_dropped"].contains(obj.str("purpose") ?? "") || obj.str("tool") == "memory" { obj["page"] = .string("") }
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
        obj["id"] = .string(try reserveLearningID(prefix: prefix, fields: obj))
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
        try checkLearningIdentities(learning)
        try preserveLearningIDFloor()
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
        try rewriteLearning(learning.filter { !doomed.contains($0.str("id") ?? "") })
        return removed
    }

    public func restoreLearning(_ records: [JSONObject]) throws {
        try locked {
            try checkLearningIdentities(learning + records)
            try preserveLearningIDFloor(adding: records)
            let restored = (learning + records).sorted { ($0.str("at") ?? "") < ($1.str("at") ?? "") }
            try rewriteLearning(restored)
        }
    }

    func rewriteLearning(_ records: [JSONObject]) throws {
        let text = records.map { $0.line + "\n" }.joined()
        try Data(text.utf8).write(to: learningURL, options: .atomic)
        learning = records
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

    // MARK: Pages

    public enum PageRole: String, Codable { case content, notebook, chapter, about, goals, notes, memory }
    public enum PageScope: String, Codable { case notebook, library }

    public struct Page: Identifiable, Equatable {
        public let file: String
        public let title: String
        public let role: PageRole
        public let scope: PageScope
        public var id: String { file }
        public init(file: String, title: String, role: PageRole = .content, scope: PageScope = .notebook) {
            self.file = file; self.title = title; self.role = role; self.scope = scope
        }
    }

    public var pageFiles: [String] {
        let chaptered = (meta["chapters"]?.array ?? []).flatMap { $0["pages"]?.array ?? [] }.compactMap(\.string)
        let unfiled = (meta["unfiled"]?.array ?? []).compactMap(\.string)
        let roots = [meta.str("overview")] + (meta["chapters"]?.array ?? []).map { $0["intro"]?.string }
        var seen = Set<String>()
        return (roots.compactMap { $0 } + chaptered + unfiled).filter { seen.insert($0).inserted }
    }

    public func page(_ file: String) -> Page? {
        guard pageFiles.contains(file) else { return nil }
        let properties = meta["pageProperties"]?[file]
        return Page(file: file, title: readPage(file)?.title ?? file,
                    role: properties?["role"]?.string.flatMap(PageRole.init(rawValue:)) ?? .content,
                    scope: properties?["scope"]?.string.flatMap(PageScope.init(rawValue:)) ?? .notebook)
    }
    public var pages: [Page] { pageFiles.compactMap(page) }
    public var contentPages: [Page] { pages.filter { $0.role == .content } }
    public var overviewPage: Page? { meta.str("overview").flatMap(page) }

    /// A chapter groups pages in the book. Its number is optional ("0" in "Chapter 0: Foundations").
    public struct Chapter: Identifiable, Equatable {
        public let number: String?
        public let title: String
        public let pages: [Page]
        public let intro: Page?
        public init(number: String?, title: String, pages: [Page], intro: Page? = nil) {
            self.number = number; self.title = title; self.pages = pages; self.intro = intro
        }
        public var id: String { intro?.file ?? (number ?? "") + "|" + title }
        /// "Chapter 0: Foundations", or the title alone.
        public var heading: String { number.map { "Chapter \($0): \(title)" } ?? title }
    }

    public var chapters: [Chapter] {
        (meta["chapters"]?.array ?? []).compactMap(\.object).filter { !($0["pages"]?.array ?? []).isEmpty || $0.str("intro") != nil }.map { c in
            Chapter(number: c.str("number"), title: c.str("title") ?? "Untitled",
                    pages: (c["pages"]?.array ?? []).compactMap(\.string).compactMap(page), intro: c.str("intro").flatMap(page))
        }
    }

    /// Pages not in any chapter, in book order.
    public var unfiledPages: [Page] {
        (meta["unfiled"]?.array ?? []).compactMap(\.string).compactMap(page)
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
    public func fileInChapter(_ files: [String], chapter heading: String, session: String = "", thread: String = "") throws -> Chapter {
        try locked {
            var seen = Set<String>()
            let files = files.filter { seen.insert($0).inserted }
            let known = Set(contentPages.map(\.file))
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
                if let intro = chapters[i].str("intro"), let page = readPage(intro), page.title != title {
                    let outcome = try writePage(title: title, content: page.body, revising: intro,
                                                session: session, toolUseID: "chapter-title:" + UUID().uuidString, thread: thread)
                    guard outcome["refused"] != .bool(true) else { throw StoreError.notFound }
                }
                chapters[i]["pages"] = .array((chapters[i]["pages"]?.array ?? []) + files.map { .string($0) })
                if let number { chapters[i]["number"] = .string(number) }
                chapters[i]["title"] = .string(title)
            } else {
                var c: JSONObject = ["title": .string(title), "pages": .array(files.map { .string($0) })]
                if let number { c["number"] = .string(number) }
                let at = number.flatMap { n in chapters.firstIndex { ($0.str("number")).map { Self.numberSorts($0, after: n) } ?? true } } ?? chapters.count
                chapters.insert(c, at: at)
            }
            chapters.removeAll { ($0["pages"]?.array ?? []).isEmpty && $0.str("intro") == nil }
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

    public static func splitFrontmatter(_ text: String) -> (title: String, body: String) {
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

    /// Add real, initially empty overview pages without replacing any existing content.
    /// Metadata reserves each filename first, so an interrupted initialization resumes at the same file.
    /// Existing JSONL and Markdown remain untouched; the original ordering metadata is retained once.
    public func ensureOverviewPages(session: String) throws {
        try locked {
            if meta.str("overview") == nil {
                let backup = url.appendingPathComponent("notebook.before-page-roots.json")
                if !FileManager.default.fileExists(atPath: backup.path) {
                    try Data(contentsOf: metaURL).write(to: backup, options: .atomic)
                }
                let file = uniqueFile(for: "Notebook introduction")
                meta["overview"] = .string(file)
                setPageProperties(file, role: .notebook)
                try writeMeta()
            }
            if let file = meta.str("overview") { try initializePage(file, title: name, session: session) }
            var chapters = (meta["chapters"]?.array ?? []).compactMap(\.object)
            for i in chapters.indices {
                if chapters[i].str("intro") == nil {
                    let file = uniqueFile(for: "Chapter " + (chapters[i].str("number") ?? "") + " " + (chapters[i].str("title") ?? "Introduction"))
                    chapters[i]["intro"] = .string(file)
                    setPageProperties(file, role: .chapter)
                    meta["chapters"] = .array(chapters.map(JSON.object))
                    try writeMeta()
                }
                if let file = chapters[i].str("intro") {
                    try initializePage(file, title: chapters[i].str("title") ?? "Chapter", session: session)
                }
            }
        }
    }

    /// Attach purpose and sharing metadata to an existing ordinary Markdown page.
    /// This does not change its bytes, write permissions, history, or editor path.
    public func setPageProperties(file: String, role: PageRole, scope: PageScope = .notebook) throws {
        try locked {
            guard pageFiles.contains(file), readPage(file) != nil else { throw StoreError.notFound }
            var properties = meta["pageProperties"]?.object ?? [:]
            properties[file] = .object(["role": .string(role.rawValue), "scope": .string(scope.rawValue)])
            meta["pageProperties"] = .object(properties)
            try writeMeta()
        }
    }

    private func setPageProperties(_ file: String, role: PageRole) {
        var properties = meta["pageProperties"]?.object ?? [:]
        properties[file] = .object(["role": .string(role.rawValue), "scope": .string(PageScope.notebook.rawValue)])
        meta["pageProperties"] = .object(properties)
    }

    private func initializePage(_ file: String, title: String, session: String) throws {
        guard ExistingNotebook.validComponent(file) else { throw StoreError.notFound }
        let destination = pagesURL.appendingPathComponent(file)
        guard !FileManager.default.fileExists(atPath: destination.path) else { return }
        guard !transcript.contains(where: { $0.str("file") == file }) else { throw StoreError.notFound }
        let text = "---\ntitle: " + JSON.string(title).line + "\n---\n"
        try Data(text.utf8).write(to: destination, options: .atomic)
        _ = try appendTranscriptLocked(["role": .string("client"), "purpose": .string("initialize_page"),
                                       "session": .string(session), "file": .string(file), "hash": .string(Self.hash(text))])
    }

    // MARK: Page writes

    /// Sophia saves pages directly. A new page is added to the book; a revision keeps the
    /// page's file and saves the version it replaces as <file>.previous.md. Writes, in order:
    /// the page file, then its transcript entry, then notebook.json.
    ///
    /// A revision that would change the section the person has open, drop or alter lines they
    /// wrote (unless they released that edit), or drop a quote of their words is not saved:
    /// the returned entry has `refused: true`, with Sophia's `why` if she gave one.
    @discardableResult
    public func writePage(title: String, content: String, revising file: String?, session: String, toolUseID: String,
                          why: String? = nil, thread: String = "") throws -> JSONObject {
        try locked {
            let titleJSON = JSON.string(title).line
            let text = "---\ntitle: \(titleJSON)\n---\n" + content + "\n"
            if let file, pageFiles.contains(file), let refusal = refusal(revising: file, content: content) {
                var entry: JSONObject = ["role": .string("tool"), "tool": .string("write_page"), "session": .string(session),
                                         "tool_use": .string(toolUseID), "file": .string(file), "title": .string(readPage(file)?.title ?? title),
                                         "page": .string(file), "refused": .bool(true), "reason": .string(refusal.reason.rawValue),
                                         "section": .string(refusal.section), "current": .string(refusal.current),
                                         "edits": .array(refusal.edits.map { .string($0) })]
                if let first = refusal.edits.first { entry["edit"] = .string(first) }
                if let why = why?.trimmingCharacters(in: .whitespacesAndNewlines), !why.isEmpty { entry["why"] = .string(why) }
                return try appendTranscriptLocked(entry)
            }
            if let file, pageFiles.contains(file) {
                let current = pagesURL.appendingPathComponent(file)
                let previous = pagesURL.appendingPathComponent(Self.previousName(file))
                let bytes = Data(text.utf8)
                let unchanged = try Data(contentsOf: current) == bytes
                if !unchanged {
                    if FileManager.default.fileExists(atPath: previous.path) {
                        try FileManager.default.removeItem(at: previous)
                    }
                    try FileManager.default.copyItem(at: current, to: previous)
                    try bytes.write(to: current, options: .atomic)
                }
                var entry: JSONObject = ["role": .string("tool"), "tool": .string("write_page"), "session": .string(session),
                                         "tool_use": .string(toolUseID), "file": .string(file), "title": .string(title),
                                         "revised": .bool(true), "page": .string(thread), "hash": .string(Self.hash(text))]
                if unchanged { entry["unchanged"] = .bool(true) }
                return try appendTranscriptLocked(entry)
            }
            let name = uniqueFile(for: title)
            try Data(text.utf8).write(to: pagesURL.appendingPathComponent(name), options: .atomic)
            let entry = try appendTranscriptLocked(["role": .string("tool"), "tool": .string("write_page"), "session": .string(session),
                                               "tool_use": .string(toolUseID), "file": .string(name), "title": .string(title),
                                               "page": .string(thread), "hash": .string(Self.hash(text))])
            var unfiled = meta["unfiled"]?.array ?? []
            unfiled.append(.string(name))
            meta["unfiled"] = .array(unfiled)
            try writeMeta()
            return entry
        }
    }

    static func previousName(_ file: String) -> String { String(file.dropLast(3)) + ".previous.md" }

    public func hasPreviousVersion(_ file: String) -> Bool {
        FileManager.default.fileExists(atPath: pagesURL.appendingPathComponent(Self.previousName(file)).path)
    }

    public func readPreviousVersion(_ file: String) -> (title: String, body: String)? {
        readPage(Self.previousName(file))
    }

    /// Page-write outcomes and unknown-provenance reconciliation records, oldest first.
    /// Refused writes changed nothing and aren't included; a client record does not establish authorship.
    public var pageWrites: [JSONObject] { transcript.filter { $0.str("tool") == "write_page" && $0["refused"] != .bool(true) } }

    /// A write that can still be undone: Sophia's page write or the person's edit, with nothing written to that page since.
    public func isLatestWrite(_ entryID: String) -> Bool {
        guard let e = transcript.first(where: { $0.str("id") == entryID }), let file = actionFile(e) else { return false }
        return latestPageAction(for: file)?.str("id") == entryID
    }

    func actionFile(_ entry: JSONObject) -> String? {
        if let file = entry.str("file") { return file }
        if ["release_edit", "undo_release"].contains(entry.str("purpose") ?? ""),
           let target = transcript.first(where: { $0.str("id") == entry.str("entry") }) { return actionFile(target) }
        return nil
    }

    public func latestPageAction(for file: String) -> JSONObject? {
        transcript.last { e in
            actionFile(e) == file && ((e.str("tool") == "write_page" && e["refused"] != .bool(true))
                || ["edit_page", "release_edit", "undo_page", "undo_release"].contains(e.str("purpose") ?? ""))
        }
    }

    public func pageHash(_ file: String) -> String? {
        guard let bytes = try? Data(contentsOf: pagesURL.appendingPathComponent(file)) else { return nil }
        return SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }

    public func isUndoable(_ e: JSONObject) -> Bool {
        guard e.str("tool") == "write_page" || e.str("purpose") == "edit_page",
              e["refused"] != .bool(true), e["unchanged"] != .bool(true), e["recovered"] != .bool(true), let id = e.str("id"), let file = e.str("file"),
              let hash = e.str("hash"), isLatestWrite(id), pageHash(file) == hash else { return false }
        if e["revised"] == .bool(true) || e.str("purpose") == "edit_page" {
            guard let previous = pageHash(Self.previousName(file)), previous != hash else { return false }
        }
        return true
    }

    public func isReleaseUndoable(_ e: JSONObject) -> Bool {
        e.str("purpose") == "release_edit" && e.str("id").map(isLatestWrite) == true
    }

    public func pageWrite(toolUse id: String) -> JSONObject? { pageWrites.last { $0.str("tool_use") == id } }

    public enum StoreError: Error, LocalizedError {
        case notFound, learningIdentityConflict, learningIDLimit
        public var errorDescription: String? {
            switch self {
            case .notFound: return "That change can't be undone any more."
            case .learningIdentityConflict: return "Some note records have the same ID. The action wasn't applied; existing records were kept. Preserve the notebook and its backup before resolving those identities."
            case .learningIDLimit: return "The notebook can't safely allocate another note ID. Existing records were kept."
            }
        }
    }

    /// Undoes a page write: removes a page Sophia added, or puts back the previous version after
    /// her revision or the person's edit. Only the latest write to a page can be undone.
    public func undoPageWrite(_ entryID: String, session: String) throws {
        try locked {
            guard let e = transcript.first(where: { $0.str("id") == entryID }), let file = e.str("file"),
                  isUndoable(e) else { throw StoreError.notFound }
            let url = pagesURL.appendingPathComponent(file)
            if e["revised"] == .bool(true) || e.str("purpose") == "edit_page" {
                let previous = pagesURL.appendingPathComponent(Self.previousName(file))
                guard FileManager.default.fileExists(atPath: previous.path) else { throw StoreError.notFound }
                // POSIX rename atomically replaces the canonical file and consumes the copy.
                guard rename(previous.path, url.path) == 0 else { throw StoreError.notFound }
            } else {
                meta["unfiled"] = .array((meta["unfiled"]?.array ?? []).filter { $0.string != file })
                if let chapters = meta["chapters"]?.array {
                    meta["chapters"] = .array(chapters.map { ch in
                        guard var o = ch.object else { return ch }
                        o["pages"] = .array((o["pages"]?.array ?? []).filter { $0.string != file })
                        return .object(o)
                    })
                }
                try writeMeta()
                try FileManager.default.removeItem(at: url)
            }
            var undo: JSONObject = ["role": .string("client"), "session": .string(session), "purpose": .string("undo_page"),
                                        "entry": .string(entryID), "file": .string(file),
                                        "page": .string(e["revised"] == .bool(true) || e.str("purpose") == "edit_page" ? file : Self.thread(of: e))]
            if let hash = pageHash(file) { undo["hash"] = .string(hash) }
            try appendTranscriptLocked(undo)
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
            for e in transcript where e.str("role") == "tool" && e["purpose"] == nil {
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
    public func writeGoal(text: String, criteria: [String], revising goalID: String?, quote: String?, session: String, thread: String = "") throws -> JSONObject {
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
            let personMessages = threadEntries(for: thread).filter(Self.isPersonMessage)
            if let q = quote, let entry = personMessages.last(where: { RecordChecks.normalize($0.str("text") ?? "").contains(RecordChecks.normalize(q)) }), !q.isEmpty {
                record["quote"] = .object(["entry": entry["id"]!, "text": .string(q)])
            }
            if let last = personMessages.last?.str("id") { record["refs"] = .array([.string(last)]) }
            let saved = try appendLearningLocked(record, by: "sophia", session: session)
            try appendTranscriptLocked(["role": .string("client"), "purpose": .string("goal_noted"),
                                        "record": saved["id"]!, "page": .string(thread), "session": .string(session)])
            return saved
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
    public func writeNote(_ fields: JSONObject, quote: String?, revising noteID: String?, session: String, thread: String = "") throws -> (saved: JSONObject?, problems: [String]) {
        try locked {
            var obj = fields
            // Sophia gives the words; the store finds which of the person's messages this session they're from.
            if let q = quote, !q.isEmpty {
                let matches: (JSONObject) -> Bool = { $0.str("session") == session && Self.isPersonMessage($0) && RecordChecks.normalize($0.str("text") ?? "").contains(RecordChecks.normalize(q)) }
                let entry = threadEntries(for: thread).last(where: matches) ?? transcript.last { $0.str("session") == session && matches($0) }
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
            let out = RecordChecks(store: self).check([.object(obj)], allowedKinds: Self.liveNoteKinds, quoteEntries: Set(transcript.filter { $0.str("session") == session }.compactMap { $0.str("id") }))
            guard var rec = out.kept.first else { return (nil, out.notes) }
            if let noteID { rec["replaces"] = .string(noteID) }
            let saved = try appendLearningLocked(rec, by: "sophia", session: session)
            _ = try appendTranscriptLocked(["role": .string("tool"), "tool": .string("note"), "session": .string(session),
                                            "page": .string(thread), "record": saved["id"]!, "revised": .bool(noteID != nil)])
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
        while FileManager.default.fileExists(atPath: pagesURL.appendingPathComponent(name).path) || pageFiles.contains(name) || transcript.contains(where: { $0.str("file") == name }) {
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

extension NotebookStore {
    /// References survive deletion, so legacy notebooks must reserve their identities too.
    private func learningIDFloor(adding records: [JSONObject]) -> [String: Int] {
        var floor = ["n": 0, "g": 0]
        for prefix in ["n", "g"] {
            if let text = meta["learning_ids"]?[prefix]?.string, let value = Int(text), value >= 0 { floor[prefix] = value }
            else if case .number(let number) = meta["learning_ids"]?[prefix], let value = Int(exactly: number), value >= 0 { floor[prefix] = value }
        }
        func include(_ text: String?) {
            guard let text else { return }
            let root = text.split(separator: "#", maxSplits: 1).first.map(String.init) ?? text
            guard root.hasPrefix("n-") || root.hasPrefix("g-"), let value = Int(root.dropFirst(2)), value >= 0 else { return }
            let prefix = String(root.prefix(1))
            floor[prefix] = max(floor[prefix] ?? 0, value)
        }
        for record in learning + transcript + records {
            for key in ["id", "replaces", "record", "goal", "through"] { include(record.str(key)) }
            for key in ["refs", "kept"] { for ref in record[key]?.array ?? [] { include(ref.string) } }
            include(record["quote"]?["entry"]?.string)
        }
        return floor
    }

    func checkLearningIdentities(_ records: [JSONObject]) throws {
        let ids = records.compactMap { $0.str("id") }
        guard ids.count == Set(ids).count else { throw StoreError.learningIdentityConflict }
    }

    /// Reserve under the existing notebook lock, before changing the learning log.
    /// A failed append can leave a harmless gap, but an identity is never recycled.
    func reserveLearningID(prefix: String, fields: JSONObject) throws -> String {
        try checkLearningIdentities(learning)
        var floor = learningIDFloor(adding: [fields])
        let key = String(prefix.prefix(1)), current = floor[key] ?? 0
        guard current < Int.max else { throw StoreError.learningIDLimit }
        floor[key] = current + 1
        meta["learning_ids"] = .object(floor.mapValues { .string(String($0)) })
        try writeMeta()
        return prefix + String(current + 1)
    }

    func preserveLearningIDFloor(adding records: [JSONObject] = []) throws {
        let floor = JSON.object(learningIDFloor(adding: records).mapValues { .string(String($0)) })
        if meta["learning_ids"] != floor { meta["learning_ids"] = floor; try writeMeta() }
    }
}
