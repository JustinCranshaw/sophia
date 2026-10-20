import Foundation

/// What Sophia keeps across notebooks, in <library>/.sophia/:
///
///     about.jsonl   "About you": the person's background and standing preferences
///     links.jsonl   connections between pages in different notebooks
///
/// Both follow the goals pattern: Sophia proposes, and a line or link is provisional until the
/// person confirms it (a record by the person replaces hers). The person can add, reword, or
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

    /// Current lines. Sophia sees confirmed lines in every notebook, and her provisional lines
    /// only in the notebook they came from.
    public var aboutLines: [JSONObject] { Self.current(about) }

    public func aboutLines(visibleIn notebook: String) -> [JSONObject] {
        aboutLines.filter { !Self.isProvisional($0) || $0.str("notebook") == notebook }
    }

    /// Sophia proposes a line about the person, resting on their exact words in `store`.
    public func proposeAbout(text: String, quote: String, revising id: String?, from store: NotebookStore) throws -> (saved: JSONObject?, problem: String?) {
        try locked {
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
            var rec: JSONObject = ["kind": .string("about"), "text": .string(text.trimmingCharacters(in: .whitespacesAndNewlines))]
            if let id, let cur = about.first(where: { $0.str("id") == id }) {
                rec["replaces"] = .string(id)
                for k in ["quote", "notebook"] { if let v = cur[k] { rec[k] = v } }
            } else if let notebook { rec["notebook"] = .string(notebook) }
            return try append(rec, by: "person", prefix: "a-", to: aboutURL, list: &about)
        }
    }

    public func deleteAbout(_ id: String) throws { try locked { try remove(id, from: &about, at: aboutURL) } }

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
            if NotebookStore.isSeparate(store.url) { return (nil, "This notebook is kept separate, so it isn't linked to others.") }
            let target = root.appendingPathComponent(toNotebook)
            guard toNotebook != store.name, FileManager.default.fileExists(atPath: target.appendingPathComponent("notebook.json").path),
                  !NotebookStore.isSeparate(target) else { return (nil, "There is no other notebook named \(toNotebook) to link to.") }
            guard let other = try? NotebookStore(url: target), other.pageFiles.contains(toPage) else {
                return (nil, "\(toNotebook) has no page \(toPage). Use a file name from the list of other notebooks.")
            }
            if let page, !store.pageFiles.contains(page) { return (nil, "This notebook has no page \(page).") }
            // Deep links name a section by its title, as written in the page.
            var targetSection: String?
            if let t = toSection, !t.isEmpty {
                guard let sec = other.section(t, of: toPage) else { return (nil, "\(toPage) has no section “\(t)”. Use a title from the list.") }
                targetSection = sec.title
            }
            var fromSectionTitle: String?
            if let f = fromSection, !f.isEmpty {
                guard let page, let sec = store.section(f, of: page) else { return (nil, "There's no section “\(f)” on that page here.") }
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

    /// Can Sophia, working in `notebook`, read `page` in `other`? Only through a confirmed link.
    public func mayRead(_ page: String, in other: String, from notebook: String) -> Bool {
        if NotebookStore.isSeparate(root.appendingPathComponent(other)) || NotebookStore.isSeparate(root.appendingPathComponent(notebook)) { return false }
        return links(touching: notebook).contains { l in
            guard !Self.isProvisional(l) else { return false }
            let to = l["to"]?.object, from = l["from"]?.object
            return (to?.str("notebook") == other && to?.str("page") == page) || (from?.str("notebook") == other && from?.str("page") == page)
        }
    }

    /// The other notebooks' chapter and page titles: all Sophia sees of them.
    public func otherNotebooks(than notebook: String) -> [(name: String, pages: String)] {
        guard !NotebookStore.isSeparate(root.appendingPathComponent(notebook)) else { return [] }
        return Library(root: root).notebooks.filter { $0.lastPathComponent != notebook && !NotebookStore.isSeparate($0) }.compactMap { url in
            guard let s = try? NotebookStore(url: url) else { return nil }
            return (s.name, Prompts.pageList(s, sections: true))
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
