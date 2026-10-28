import Foundation

/// What Sophia keeps across notebooks, in <library>/.sophia/:
///
///     about.jsonl   "About you": the person's background and standing preferences
///     links.jsonl   connections between pages in different notebooks
///
/// Both follow the goals pattern: Sophia proposes, and a line or link is provisional until the
/// person confirms it (a record by the person replaces Sophia’s proposal). The person can add, reword, or
/// delete anything. Only pointers cross notebooks: Sophia sees other notebooks' chapter and page
/// titles, and can read another notebook's page only through a confirmed link. A notebook marked
/// "separate" is left out of all of this.
public final class LibraryStore {
    public let root: URL
    public private(set) var about: [JSONObject] = []
    public private(set) var links: [JSONObject] = []

    public static let aboutLimit = 12

    var dir: URL { root.appendingPathComponent(".sophia") }
    var aboutURL: URL { dir.appendingPathComponent("about.jsonl") }
    var linksURL: URL { dir.appendingPathComponent("links.jsonl") }

    public init(root: URL) {
        self.root = root
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        reload()
    }

    private init(existingRoot root: URL, links: [JSONObject]) {
        self.root = root
        self.links = links
    }

    /// A tool read must not bootstrap the writable shared store.
    public static func readExistingLinkedPage(_ page: String, in other: String, from notebook: String, root: URL) -> Result<ExistingNotebook.Page, LinkedReadError> {
        guard let links = ExistingNotebook.existingLinks(root: root) else { return .failure(.notAllowed) }
        return LibraryStore(existingRoot: root, links: links).readLinkedPage(page, in: other, from: notebook)
    }

    public func reload() {
        about = NotebookStore.readLines(aboutURL)
        links = NotebookStore.readLines(linksURL)
    }

    private var lockDepth = 0
    private var lockFD: Int32 = -1

    func locked<T>(_ body: () throws -> T) rethrows -> T {
        if lockDepth == 0 {
            lockFD = open(dir.appendingPathComponent(".lock").path, O_CREAT | O_RDWR, 0o644)
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

    func append(_ fields: JSONObject, by: String, prefix: String, to url: URL, list: inout [JSONObject]) throws -> JSONObject {
        var obj = fields
        for k in ["id", "at", "by"] { obj.removeValue(forKey: k) }
        let n = (list.compactMap { $0.str("id") }.compactMap { Int($0.dropFirst(prefix.count)) }.max() ?? 0) + 1
        obj["id"] = .string(prefix + String(n))
        obj["at"] = .string(NotebookStore.now())
        obj["by"] = .string(by)
        try Data((obj.line + "\n").utf8).appendOrCreate(at: url)
        list.append(obj)
        return obj
    }

    static func current(_ list: [JSONObject]) -> [JSONObject] {
        let replaced = Set(list.compactMap { $0.str("replaces") })
        return list.filter { !replaced.contains($0.str("id") ?? "") && $0["removed"] != .bool(true) }
    }

    /// Removes a line or link: its whole chain, earlier versions and later ones.
    func remove(_ id: String, from list: inout [JSONObject], at url: URL) throws {
        var root = id
        while let prev = list.first(where: { $0.str("id") == root })?.str("replaces") { root = prev }
        var doomed: Set<String> = [root], changed = true
        while changed {
            changed = false
            for r in list { if let rid = r.str("id"), let rep = r.str("replaces"), doomed.contains(rep), doomed.insert(rid).inserted { changed = true } }
        }
        list.removeAll { doomed.contains($0.str("id") ?? "") }
        try Data(list.map { $0.line + "\n" }.joined().utf8).write(to: url, options: .atomic)
    }

    public static func isProvisional(_ r: JSONObject) -> Bool { r.str("by") == "sophia" }

    // MARK: About you

    /// Current lines. Sophia sees confirmed lines in every notebook, and Sophia’s provisional lines
    /// only in the notebook they came from.
    public var aboutLines: [JSONObject] { Self.current(about) }

    public func aboutLines(visibleIn notebook: String) -> [JSONObject] {
        aboutLines.filter { !Self.isProvisional($0) || $0.str("notebook") == notebook }
    }

    /// Sophia proposes a line about the person, resting on their exact words in `store`.
    public func proposeAbout(text: String, quote: String, revising id: String?, from store: NotebookStore) throws -> (saved: JSONObject?, problem: String?) {
        try locked {
            guard !hasSharedAboutMigration else { return (nil, "About you is a Markdown page now; propose a whole-page change instead.") }
            let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty, t.count <= NotebookStore.memoryLineLength else { return (nil, "A line about the person is one short sentence.") }
            let q = quote.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !q.isEmpty, let entry = store.transcript.last(where: { NotebookStore.isPersonMessage($0)
                && RecordChecks.normalize($0.str("text") ?? "").contains(RecordChecks.normalize(q)) }) else {
                return (nil, "Not saved: a line about the person must rest on their exact words in this notebook, and that quote doesn't match.")
            }
            var rec: JSONObject = ["kind": .string("about"), "text": .string(t), "notebook": .string(store.name),
                                   "quote": .object(["entry": entry["id"]!, "text": .string(q)])]
            if let id {
                guard let cur = aboutLines.first(where: { $0.str("id") == id }) else { return (nil, "There is no line \(id).") }
                guard Self.isProvisional(cur) else { return (nil, "The person confirmed \(id); ask them if it should change.") }
                rec["replaces"] = .string(id)
            } else if aboutLines.count >= Self.aboutLimit {
                return (nil, "About you holds at most \(Self.aboutLimit) lines. Revise one instead.")
            }
            return (try append(rec, by: "sophia", prefix: "a-", to: aboutURL, list: &about), nil)
        }
    }

    /// The person confirms a line, rewords one, or adds their own.
    @discardableResult
    public func setAbout(text: String, replacing id: String?, notebook: String?) throws -> JSONObject {
        try locked {
            guard !hasSharedAboutMigration else { throw SharedAboutError.legacyReadOnly }
            var rec: JSONObject = ["kind": .string("about"), "text": .string(text.trimmingCharacters(in: .whitespacesAndNewlines))]
            if let id, let cur = about.first(where: { $0.str("id") == id }) {
                rec["replaces"] = .string(id)
                for k in ["quote", "notebook"] { if let v = cur[k] { rec[k] = v } }
            } else if let notebook { rec["notebook"] = .string(notebook) }
            return try append(rec, by: "person", prefix: "a-", to: aboutURL, list: &about)
        }
    }

    public func deleteAbout(_ id: String) throws { try locked {
        guard !hasSharedAboutMigration else { throw SharedAboutError.legacyReadOnly }
        try remove(id, from: &about, at: aboutURL)
    } }

    // MARK: Links

    /// A link joins a page (or a whole notebook) here to a page in another notebook, with a reason.
    public var currentLinks: [JSONObject] { Self.current(links) }

    public func links(touching notebook: String) -> [JSONObject] {
        currentLinks.filter { $0["from"]?["notebook"]?.string == notebook || $0["to"]?["notebook"]?.string == notebook }
    }

    /// Sophia proposes a link from `from` (a page here, or nil for the notebook) to a page elsewhere.
    public func proposeLink(from store: NotebookStore, page: String?, section fromSection: String? = nil, toNotebook: String, toPage: String,
                            toSection: String? = nil, reason: String) throws -> (saved: JSONObject?, problem: String?) {
        try locked {
            guard let local = ExistingNotebook(root: root, name: store.name), !local.isSeparate else {
                return (nil, "This notebook is unavailable or kept separate, so it isn't linked to others.")
            }
            guard toNotebook != store.name, let other = ExistingNotebook(root: root, name: toNotebook), !other.isSeparate else {
                return (nil, "There is no other available notebook named \(toNotebook) to link to.")
            }
            guard let targetPage = other.readPage(toPage) else {
                return (nil, "\(toNotebook) has no page \(toPage). Use a file name from the list of other notebooks.")
            }
            if let page, !store.pageFiles.contains(page) { return (nil, "This notebook has no page \(page).") }
            // Deep links name a section by its title, as written in the page.
            var targetSection: String?
            if let t = toSection, !t.isEmpty {
                guard let sec = targetPage.section(named: t) else { return (nil, "\(toPage) has no section “\(t)”. Use a title from the list.") }
                targetSection = sec.title
            }
            var fromSectionTitle: String?
            if let f = fromSection, !f.isEmpty {
                guard let page, let sec = local.readPage(page)?.section(named: f) else { return (nil, "There's no section “\(f)” on that page here.") }
                fromSectionTitle = sec.title
            }
            let r = reason.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !r.isEmpty, r.count <= NotebookStore.memoryLineLength else { return (nil, "Give the link a one-line reason.") }
            if links(touching: store.name).contains(where: { $0["to"]?["page"]?.string == toPage && $0["to"]?["section"]?.string == targetSection
                && $0["from"]?["page"]?.string == page && $0["from"]?["section"]?.string == fromSectionTitle }) {
                return (nil, "That link already exists.")
            }
            var from: JSONObject = ["notebook": .string(store.name)]
            if let page { from["page"] = .string(page) }
            if let fromSectionTitle { from["section"] = .string(fromSectionTitle) }
            var to: JSONObject = ["notebook": .string(toNotebook), "page": .string(toPage)]
            if let targetSection { to["section"] = .string(targetSection) }
            let rec: JSONObject = ["from": .object(from), "to": .object(to), "reason": .string(r)]
            return (try append(rec, by: "sophia", prefix: "l-", to: linksURL, list: &links), nil)
        }
    }

    @discardableResult
    public func confirmLink(_ id: String) throws -> JSONObject? {
        try locked {
            guard let cur = currentLinks.first(where: { $0.str("id") == id }) else { return nil }
            var rec: JSONObject = ["replaces": .string(id)]
            for k in ["from", "to", "reason"] { if let v = cur[k] { rec[k] = v } }
            return try append(rec, by: "person", prefix: "l-", to: linksURL, list: &links)
        }
    }

    public func deleteLink(_ id: String) throws { try locked { try remove(id, from: &links, at: linksURL) } }

    public enum LinkedReadError: Error {
        case notAllowed, unavailable
        public var message: String {
            switch self {
            case .notAllowed: return "You can read another notebook only through a confirmed link, when neither notebook is kept separate."
            case .unavailable: return "That linked notebook or page is no longer available."
            }
        }
    }

    private func linkedNotebook(_ page: String, in other: String, from notebook: String) -> Result<ExistingNotebook, LinkedReadError> {
        guard ExistingNotebook.validComponent(page), ExistingNotebook.validComponent(other), ExistingNotebook.validComponent(notebook) else { return .failure(.unavailable) }
        guard links(touching: notebook).contains(where: { l in
            guard l.str("by") == "person" else { return false }
            return (l["to"]?["notebook"]?.string == other && l["to"]?["page"]?.string == page)
                || (l["from"]?["notebook"]?.string == other && l["from"]?["page"]?.string == page)
        }) else { return .failure(.notAllowed) }
        guard let local = ExistingNotebook(root: root, name: notebook), let target = ExistingNotebook(root: root, name: other) else { return .failure(.unavailable) }
        guard !local.isSeparate, !target.isSeparate else { return .failure(.notAllowed) }
        guard target.pageFiles.contains(page) else { return .failure(.unavailable) }
        return .success(target)
    }

    /// Confirmed permission and readable existing metadata, without repairing either notebook.
    public func mayRead(_ page: String, in other: String, from notebook: String) -> Bool {
        if case .success = linkedNotebook(page, in: other, from: notebook) { return true }
        return false
    }

    public func readLinkedPage(_ page: String, in other: String, from notebook: String) -> Result<ExistingNotebook.Page, LinkedReadError> {
        linkedNotebook(page, in: other, from: notebook).flatMap { target in
            target.readPage(page).map { .success($0) } ?? .failure(.unavailable)
        }
    }

    /// Only titles/section titles cross without a confirmed page link. No Library/Store initializer.
    public func otherNotebooks(than notebook: String) -> [(name: String, pages: String)] {
        guard let local = ExistingNotebook(root: root, name: notebook), !local.isSeparate,
              let urls = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { return [] }
        return urls.sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }.compactMap { url in
            guard url.lastPathComponent != notebook, let other = ExistingNotebook(root: root, name: url.lastPathComponent), !other.isSeparate else { return nil }
            return (other.name, other.pageList(sections: true))
        }
    }

}

extension NotebookStore {
    /// A notebook kept separate isn't listed to, linked from, or read by Sophia in other notebooks.
    public static func isSeparate(_ url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url.appendingPathComponent("notebook.json")),
              let obj = (try? JSONDecoder().decode(JSON.self, from: data))?.object else { return false }
        return obj["separate"] == .bool(true)
    }

    public var isSeparate: Bool { meta["separate"] == .bool(true) }
}

extension Data {
    func appendOrCreate(at url: URL) throws {
        if let h = try? FileHandle(forWritingTo: url) {
            defer { try? h.close() }
            try h.seekToEnd()
            try h.write(contentsOf: self)
        } else {
            try write(to: url, options: .atomic)
        }
    }
}
