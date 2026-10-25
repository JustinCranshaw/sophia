import Foundation
import Darwin
import SophiaCore

private struct LinkedReadFixture {
    let library: LibraryStore
    let source: NotebookStore
    let target: NotebookStore
    let sourceFile: String
    let targetFile: String
    let body = "Opening.\n\n## Evidence section\nTARGET_BODY_KEEP\n\n```text\n## Not a heading\n```\n\n## Other section\nOTHER_BODY_KEEP\n"
    init() throws {
        let (library, source, target) = try libraryTemp()
        self.library = library; self.source = source; self.target = target
        sourceFile = try source.writePage(title: "Source", content: "Source body.", revising: nil, session: "s-1", toolUseID: "source").str("file")!
        targetFile = try target.writePage(title: "Target title", content: body, revising: nil, session: "s-1", toolUseID: "target").str("file")!
    }
    func confirm() throws {
        let link = try library.proposeLink(from: source, page: sourceFile, toNotebook: target.name, toPage: targetFile, toSection: "Evidence section", reason: "Developer fixture").saved!
        try library.confirmLink(link.str("id")!)
    }
}

private func readTree(_ root: URL) throws -> [String: Data] {
    var result: [String: Data] = [:]
    guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else { return result }
    for case let url as URL in enumerator {
        let key = String(url.path.dropFirst(root.path.count))
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        if values.isSymbolicLink == true {
            result[key] = Data(("link:" + (try FileManager.default.destinationOfSymbolicLink(atPath: url.path))).utf8)
            enumerator.skipDescendants()
        } else if values.isDirectory == true { result[key + "/"] = Data() }
        else { result[key] = try Data(contentsOf: url) }
    }
    return result
}

func existingNotebookReadsKeepFormatAndNeverRepair() throws {
    let f = try LinkedReadFixture()
    _ = try f.target.fileInChapter([f.targetFile, f.targetFile], chapter: "Chapter 2: Evidence")
    expect(f.target.pageFiles == [f.targetFile])
    let plain = try f.target.writePage(title: "Unnumbered", content: "Plain body", revising: nil, session: "s-1", toolUseID: "plain").str("file")!
    _ = try f.target.fileInChapter([plain, plain], chapter: "More evidence")
    _ = try f.target.writePage(title: "Loose", content: "Loose body", revising: nil, session: "s-1", toolUseID: "loose")
    let legal = try Library(root: f.library.root).create(named: "C\\C++ notes")
    let legalStore = try NotebookStore(url: legal)
    let legalFile = try legalStore.writePage(title: "Backslash notebook", content: "Legal body", revising: nil, session: "s-1", toolUseID: "legal").str("file")!
    expect(ExistingNotebook(root: f.library.root, name: legal.lastPathComponent)?.readPage(legalFile)?.body == legalStore.readPage(legalFile)?.body)
    let meta = f.target.url.appendingPathComponent("notebook.json")
    let originalMeta = try Data(contentsOf: meta)
    var duplicated = try JSONSerialization.jsonObject(with: originalMeta) as! [String: Any]
    var chapters = duplicated["chapters"] as! [[String: Any]]
    chapters[0]["pages"] = [f.targetFile, f.targetFile]
    duplicated["chapters"] = chapters
    duplicated["unfiled"] = [f.targetFile, "loose.md", "loose.md"]
    try JSONSerialization.data(withJSONObject: duplicated).write(to: meta)
    let beforeDuplicates = try readTree(f.library.root)
    let projected = ExistingNotebook(root: f.library.root, name: f.target.name)!
    expect(projected.pageFiles == [f.targetFile, plain, "loose.md"])
    expect(projected.readPage(f.targetFile) != nil)
    expect(try readTree(f.library.root) == beforeDuplicates)
    try originalMeta.write(to: meta)
    let orphan = f.target.pagesURL.appendingPathComponent("unlisted.md")
    try "---\ntitle: Unlisted private body\n---\nNOT_LISTED".write(to: orphan, atomically: true, encoding: .utf8)
    let before = try readTree(f.library.root)
    let existing = ExistingNotebook(root: f.library.root, name: f.target.name)!
    expect(existing.readPage(f.targetFile)?.body == f.target.readPage(f.targetFile)?.body)
    expect(existing.readPage("unlisted.md") == nil)
    expect(existing.pageList(sections: true) == Prompts.pageList(f.target, sections: true))
    expect(existing.readPage(f.targetFile)?.sectionText(named: "evidence SECTION")?.contains("TARGET_BODY_KEEP") == true)
    expect(existing.readPage(f.targetFile)?.sectionText(named: "evidence SECTION")?.contains("OTHER_BODY_KEEP") == false)
    expect(existing.readPage(f.targetFile)?.sectionText(named: "Not a heading") == nil)
    expect(existing.readPage(f.targetFile)?.sectionText(named: "Renamed section") == nil)
    expect(f.library.otherNotebooks(than: f.source.name).count == 2)
    expect(try readTree(f.library.root) == before)
}

func linkedReadsFailClosedWithoutCreatingMissingOrCorruptTargets() throws {
    let f = try LinkedReadFixture()
    if case .failure(.notAllowed) = f.library.readLinkedPage(f.targetFile, in: f.target.name, from: f.source.name) {} else { expect(false) }
    try f.confirm()
    if case .success(let page) = f.library.readLinkedPage(f.targetFile, in: f.target.name, from: f.source.name) { expect(page.title == "Target title") } else { expect(false) }
    try f.target.setSeparate(true)
    if case .failure(.notAllowed) = f.library.readLinkedPage(f.targetFile, in: f.target.name, from: f.source.name) {} else { expect(false) }
    try f.target.setSeparate(false)
    let targetMeta = f.target.url.appendingPathComponent("notebook.json"), original = try Data(contentsOf: targetMeta)
    for invalid in ["{", "[]", "{\"chapters\":[],\"unfiled\":[],\"separate\":\"unknown\"}", "{\"chapters\":[],\"unfiled\":[\"../outside.md\"]}"] {
        try Data(invalid.utf8).write(to: targetMeta)
        let before = try readTree(f.library.root)
        expect(ExistingNotebook(root: f.library.root, name: f.target.name) == nil)
        if case .failure(.unavailable) = f.library.readLinkedPage(f.targetFile, in: f.target.name, from: f.source.name) {} else { expect(false) }
        expect(f.library.otherNotebooks(than: f.source.name).isEmpty)
        expect(try readTree(f.library.root) == before)
    }
    try original.write(to: targetMeta)
    let sourceMeta = f.source.url.appendingPathComponent("notebook.json"), originalSource = try Data(contentsOf: sourceMeta)
    try Data("{\"chapters\":[],\"unfiled\":[],\"separate\":7}".utf8).write(to: sourceMeta)
    expect(!f.library.mayRead(f.targetFile, in: f.target.name, from: f.source.name))
    expect(f.library.otherNotebooks(than: f.source.name).isEmpty)
    try originalSource.write(to: sourceMeta)
    let moved = f.library.root.deletingLastPathComponent().appendingPathComponent("sophia-held-" + UUID().uuidString)
    try FileManager.default.moveItem(at: f.target.url, to: moved)
    let before = try readTree(f.library.root)
    if case .failure(.unavailable) = f.library.readLinkedPage(f.targetFile, in: f.target.name, from: f.source.name) {} else { expect(false) }
    expect(try f.library.proposeLink(from: f.source, page: f.sourceFile, toNotebook: f.target.name, toPage: f.targetFile, reason: "Missing").saved == nil)
    expect(f.library.otherNotebooks(than: f.source.name).isEmpty)
    expect(!FileManager.default.fileExists(atPath: f.target.url.path))
    expect(try readTree(f.library.root) == before)
}

func existingNotebookRejectsEscapesAndSpecialFiles() throws {
    let f = try LinkedReadFixture(); try f.confirm()
    let fm = FileManager.default
    let outside = fm.temporaryDirectory.appendingPathComponent("sophia-canary-" + UUID().uuidString)
    let canary = try NotebookStore(url: outside)
    _ = try canary.writePage(title: "OUTSIDE_CANARY_SECRET", content: "OUTSIDE_CANARY_SECRET", revising: nil, session: "s-1", toolUseID: "canary")
    let canaryFile = canary.pagesURL.appendingPathComponent("outside-canary-secret.md")
    let originalCanary = try readTree(outside)
    for invalid in ["", ".", "..", "../Other", "/tmp/Other", "bad\0name"] { expect(ExistingNotebook(root: f.library.root, name: invalid) == nil) }
    let heldReader = ExistingNotebook(root: f.library.root, name: f.target.name)!
    let originalBody = heldReader.readPage(f.targetFile)!.body
    let held = f.target.url.appendingPathExtension("held")
    try fm.moveItem(at: f.target.url, to: held)
    try fm.createSymbolicLink(at: f.target.url, withDestinationURL: outside)
    expect(ExistingNotebook(root: f.library.root, name: f.target.name) == nil)
    // A held directory identity may still read its original contents after rename,
    // but cannot redirect to the replacement symlink/canary.
    expect(heldReader.readPage(f.targetFile)?.body == originalBody)
    try fm.removeItem(at: f.target.url); try fm.moveItem(at: held, to: f.target.url)
    let pages = f.target.pagesURL, heldPages = f.target.url.appendingPathComponent("held-pages")
    try fm.moveItem(at: pages, to: heldPages); try fm.createSymbolicLink(at: pages, withDestinationURL: canary.pagesURL)
    expect(ExistingNotebook(root: f.library.root, name: f.target.name) == nil)
    try fm.removeItem(at: pages); try fm.moveItem(at: heldPages, to: pages)
    let page = pages.appendingPathComponent(f.targetFile), heldPage = pages.appendingPathComponent("held-page")
    try fm.moveItem(at: page, to: heldPage); try fm.createSymbolicLink(at: page, withDestinationURL: canaryFile)
    expect(ExistingNotebook(root: f.library.root, name: f.target.name)!.readPage(f.targetFile) == nil)
    expect(!f.library.otherNotebooks(than: f.source.name).map(\.pages).joined().contains("OUTSIDE_CANARY_SECRET"))
    try fm.removeItem(at: page)
    expect(mkfifo(page.path, 0o600) == 0)
    expect(ExistingNotebook(root: f.library.root, name: f.target.name)!.readPage(f.targetFile) == nil)
    try fm.removeItem(at: page); try fm.moveItem(at: heldPage, to: page)
    let meta = f.target.url.appendingPathComponent("notebook.json"), heldMeta = meta.appendingPathExtension("held")
    try fm.moveItem(at: meta, to: heldMeta); try fm.createSymbolicLink(at: meta, withDestinationURL: canary.url.appendingPathComponent("notebook.json"))
    expect(ExistingNotebook(root: f.library.root, name: f.target.name) == nil)
    try fm.removeItem(at: meta); try fm.moveItem(at: heldMeta, to: meta)
    expect(try readTree(outside) == originalCanary)
}
