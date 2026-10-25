import Foundation
import Darwin

/// An existing notebook's metadata and read-only directory handle. Never creates,
/// repairs, locks, or journals anything, even if its destination disappears.
public final class ExistingNotebook {
    public struct Page {
        public let title: String
        public let body: String
        public var sections: [NotebookStore.Section] { NotebookStore.sections(in: body) }
        public func section(named title: String) -> NotebookStore.Section? {
            func clean(_ s: String) -> String { s.lowercased().filter { $0.isLetter || $0.isNumber } }
            let matches = sections.filter { clean($0.title) == clean(title) }
            return matches.count == 1 ? matches.first : nil
        }
        public func sectionText(named title: String) -> String? {
            guard let section = section(named: title) else { return nil }
            return NotebookStore.editRanges(in: body).first { $0.index == section.index }?.text
        }
    }
    public let name: String
    public let isSeparate: Bool
    public let pageFiles: [String]
    private let pages: ReadDirectory
    private let groups: [(number: String?, title: String, files: [String])]
    private let loose: [String]

    static func validComponent(_ name: String) -> Bool {
        !name.isEmpty && name != "." && name != ".." && !name.contains("/") && !name.contains("\0")
    }

    public init?(root: URL, name: String) {
        guard Self.validComponent(name),
              let library = ReadDirectory(path: root.standardizedFileURL.resolvingSymlinksInPath().path),
              let directory = library.child(name), let pages = directory.child("pages"),
              let data = directory.read("notebook.json"),
              let meta = (try? JSONDecoder().decode(JSON.self, from: data))?.object,
              let chapters = meta["chapters"]?.array, let unfiled = meta["unfiled"]?.array else { return nil }
        func files(_ values: [JSON]) -> [String]? {
            let names = values.compactMap(\.string)
            return names.count == values.count && names.allSatisfy(Self.validComponent) ? names : nil
        }
        guard let loose = files(unfiled) else { return nil }
        var groups: [(number: String?, title: String, files: [String])] = []
        for chapter in chapters {
            guard let c = chapter.object, let title = c.str("title"), let values = c["pages"]?.array,
                  let pages = files(values), c["number"] == nil || c["number"] == .null || c.str("number") != nil else { return nil }
            groups.append((c.str("number"), title, pages))
        }
        // Existing writers allowed repeated page references. Project each once in
        // stored order, without repairing metadata or confusing duplicates with privacy.
        var seen = Set<String>()
        groups = groups.map { ($0.number, $0.title, $0.files.filter { seen.insert($0).inserted }) }
        let looseFiles = loose.filter { seen.insert($0).inserted }
        let all = groups.flatMap(\.files) + looseFiles
        // Absence is the supported legacy optional flag; a malformed flag is not permission.
        guard meta["separate"] == nil || meta["separate"]?.bool != nil else { return nil }
        self.name = name; self.pages = pages; self.groups = groups; self.loose = looseFiles
        self.pageFiles = all; self.isSeparate = meta["separate"]?.bool == true
    }

    // Read shared links without creating .sophia or following replacement symlinks.
    static func existingLinks(root: URL) -> [JSONObject]? {
        guard let library = ReadDirectory(path: root.standardizedFileURL.resolvingSymlinksInPath().path),
              let shared = library.child(".sophia"), let data = shared.read("links.jsonl"),
              let text = String(data: data, encoding: .utf8) else { return nil }
        var records: [JSONObject] = []
        for line in text.split(separator: "\n") {
            guard let record = (try? JSONDecoder().decode(JSON.self, from: Data(line.utf8)))?.object else { return nil }
            records.append(record)
        }
        return records
    }

    public func readPage(_ file: String) -> Page? {
        guard Self.validComponent(file), pageFiles.contains(file),
              let data = pages.read(file),
              let text = String(data: data, encoding: .utf8) else { return nil }
        let parsed = NotebookStore.splitFrontmatter(text)
        return Page(title: parsed.title, body: parsed.body)
    }

    public func pageList(sections: Bool = false) -> String {
        // One read per listed page for this projection. No orphan discovery or metadata repair.
        let read = Dictionary(uniqueKeysWithValues: pageFiles.compactMap { file in readPage(file).map { (file, $0) } })
        func page(_ file: String) -> NotebookStore.Page { .init(file: file, title: read[file]?.title ?? "Unavailable page") }
        let chapters = groups.filter { !$0.files.isEmpty }.map {
            NotebookStore.Chapter(number: $0.number, title: $0.title, pages: $0.files.map(page))
        }
        return Prompts.pageList(chapters: chapters, loose: loose.map(page)) { file in
            sections ? (read[file]?.sections.map(\.title) ?? []) : []
        }
    }
}

/// Descriptor-relative opens reject symlinks at every untrusted notebook/page component.
/// The library root is selected by the person; no pathname from a tool is used as a root.
private final class ReadDirectory {
    let fd: Int32
    private static let flags = O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
    init?(path: String) {
        let fd = Darwin.open(path, Self.flags)
        guard fd >= 0 else { return nil }; self.fd = fd
    }
    private init(fd: Int32) { self.fd = fd }
    deinit { Darwin.close(fd) }
    func child(_ name: String) -> ReadDirectory? {
        let child = openat(fd, name, Self.flags)
        return child >= 0 ? ReadDirectory(fd: child) : nil
    }
    func read(_ name: String) -> Data? {
        let file = openat(fd, name, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK)
        guard file >= 0 else { return nil }
        let handle = FileHandle(fileDescriptor: file, closeOnDealloc: true)
        defer { try? handle.close() }
        var info = stat()
        guard fstat(file, &info) == 0, info.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG) else { return nil }
        do { return try handle.readToEnd() ?? Data() } catch { return nil }
    }
}
