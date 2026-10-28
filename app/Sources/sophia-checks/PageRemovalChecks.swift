import Foundation
@testable import SophiaCore

func deletedPagesRecoverExactBytesAndFiling() throws {
    let store = try tempStore()
    defer { try? FileManager.default.removeItem(at: store.url) }
    let write = try store.writePage(title: "A page", content: "First body", revising: nil, session: "s", toolUseID: "first")
    let file = write.str("file")!
    _ = try store.writePage(title: "A page", content: "Second body", revising: file, session: "s", toolUseID: "second")
    _ = try store.fileInChapter([file], chapter: "1. A chapter")
    try store.ensureOverviewPages(session: "s"); try store.ensureNotebookPages(session: "s")
    let current = try Data(contentsOf: store.pagesURL.appendingPathComponent(file))
    let previous = try Data(contentsOf: store.pagesURL.appendingPathComponent(NotebookStore.previousName(file)))
    let chapter = store.chapters[0].id
    let cached = try NotebookStore(url: store.url)
    let id = try store.deletePage(file, session: "person")
    expect(store.readPage(file) == nil && store.contentPages.isEmpty)
    expect(store.chapters[0].id == chapter && store.chapters[0].pages.isEmpty)
    expect(!FileManager.default.fileExists(atPath: store.pagesURL.appendingPathComponent(file).path))
    expectThrows { try cached.writePage(title: "A page", content: "Late writer", revising: file, session: "stale", toolUseID: "late") }
    let reopened = try NotebookStore.open(url: store.url)
    expect(reopened.deletedPages.count == 1 && reopened.contentPages.isEmpty)
    expectThrows { try reopened.writePage(title: "A page", content: "Late revision", revising: file, session: "s", toolUseID: "late-revision") }
    let new = try reopened.writePage(title: "A page", content: "Different page", revising: nil, session: "s", toolUseID: "new")
    expect(new.str("file") != file)
    _ = try reopened.restoreDeletedPage(id, session: "person")
    expect(try Data(contentsOf: store.pagesURL.appendingPathComponent(file)) == current)
    expect(try Data(contentsOf: store.pagesURL.appendingPathComponent(NotebookStore.previousName(file))) == previous)
    expect(reopened.chapters[0].pages.first?.file == file)
    expect(!reopened.isUndoable(write))
    expectThrows { try cached.appendTranscript(["role": .string("client")]) }
    expectThrows { try reopened.deletePage(reopened.overviewPage!.file, session: "s") }
    for role in [NotebookStore.PageRole.goals, .notes, .memory] { expect(!reopened.canDeletePage(reopened.notebookPage(role: role)!.file)) }
}

func removalRecoveryRefusesCollisionAndSurvivesLeftovers() throws {
    let store = try tempStore()
    defer { try? FileManager.default.removeItem(at: store.url) }
    let file = try store.writePage(title: "Recover me", content: "Original", revising: nil, session: "s", toolUseID: "w").str("file")!
    let bytes = try Data(contentsOf: store.pagesURL.appendingPathComponent(file))
    let id = try store.deletePage(file, session: "s")
    try Data("Unrelated external file".utf8).write(to: store.pagesURL.appendingPathComponent(file))
    expectThrows { try store.restoreDeletedPage(id, session: "s") }
    let reopened = try NotebookStore.open(url: store.url)
    expect(reopened.contentPages.isEmpty && reopened.readPage(file) == nil)
    try bytes.write(to: store.pagesURL.appendingPathComponent(file)) // exact interrupted-removal leftover
    _ = try reopened.restoreDeletedPage(id, session: "s")
    expect(try Data(contentsOf: store.pagesURL.appendingPathComponent(file)) == bytes)
}

func movedNotebooksRejectStaleStoresAndRetireLinkGrants() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("sophia-removal-\(UUID())")
    defer { try? FileManager.default.removeItem(at: root) }
    let library = Library(root: root), source = try NotebookStore(url: library.create(named: "Source")), target = try NotebookStore(url: library.create(named: "Target"))
    let file = try target.writePage(title: "Linked", content: "Target body", revising: nil, session: "s", toolUseID: "w").str("file")!
    let shared = LibraryStore(root: root)
    let proposed = try shared.proposeLink(from: source, page: nil, toNotebook: "Target", toPage: file, reason: "Related inquiry")
    let link = proposed.0!.str("id")!
    _ = try shared.confirmLink(link)
    expect(shared.mayRead(file, in: "Target", from: "Source"))
    try shared.retireLinks(notebook: "Target")
    let moved = root.appendingPathComponent("Moved")
    try target.moveNotebook { try FileManager.default.moveItem(at: $0, to: moved) }
    expectThrows { try target.appendTranscript(["role": .string("client")]) }
    expectThrows { try NotebookStore(url: target.url, existingOnly: true) }
    expect(!FileManager.default.fileExists(atPath: target.url.path))
    try FileManager.default.moveItem(at: moved, to: target.url)
    expectThrows { try target.appendTranscript(["role": .string("client")]) } // Put Back cannot revive old writer
    try FileManager.default.moveItem(at: target.url, to: moved)
    let replacement = try NotebookStore(url: library.create(named: "Target"))
    _ = try replacement.writePage(title: "Linked", content: "Replacement", revising: nil, session: "s", toolUseID: "w")
    expectThrows { try target.writePage(title: "Old", content: "Late write", revising: nil, session: "s", toolUseID: "late") }
    expect(!shared.mayRead(file, in: "Target", from: "Source"))
    expect(!shared.links.isEmpty && shared.currentLinks.isEmpty)
    expectThrows { try library.create(named: "Target") }
}

func failedRemovalPreservesOriginalAndOpenEdits() throws {
    let store = try tempStore()
    defer { try? FileManager.default.removeItem(at: store.url) }
    let file = try store.writePage(title: "Kept", content: "Exact bytes", revising: nil, session: "s", toolUseID: "w").str("file")!
    let bytes = try Data(contentsOf: store.pagesURL.appendingPathComponent(file))
    _ = try store.beginEdit(file: file, key: "(page)", session: "s")
    expectThrows { try store.deletePage(file, session: "s") }
    expect(try Data(contentsOf: store.pagesURL.appendingPathComponent(file)) == bytes)
    store.endEdit()
    try Data("blocked archive path".utf8).write(to: store.url.appendingPathComponent("deleted-pages"))
    expectThrows { try store.deletePage(file, session: "s") }
    expect(try Data(contentsOf: store.pagesURL.appendingPathComponent(file)) == bytes)
    expect(store.deletedPages.isEmpty)
    expectThrows { try store.moveNotebook { _ in throw CocoaError(.fileWriteNoPermission) } }
    expect(store.isAvailable)
    _ = try store.appendTranscript(["role": .string("client"), "purpose": .string("still-writable")])
}

func deletedAlmanacEntryIsNotAdvertisedAsReady() throws {
    let store = try tempStore()
    defer { try? FileManager.default.removeItem(at: store.url) }
    try store.configureAlmanac(.init(enabled: true, topics: "Synthetic curiosity"))
    let run = try store.reserveAlmanac(manual: true, acknowledged: true)!
    let draft = try AlmanacDraft.parse(JSON.object(["title": .string("A disposable entry"), "body": .string("A concrete synthetic explanation."), "basis": .string("general_knowledge"), "needsOpenedSource": .bool(false)]).line)
    let entry = try store.saveAlmanac(draft, evidence: [], run: run, session: "s")
    expect(store.almanacSnapshot.waitingEntry?.file == entry.file)
    let id = try store.deletePage(entry.file, session: "person")
    try store.reconcileAlmanac()
    expect(store.almanacSnapshot.waitingEntry == nil && store.almanacSnapshot.latestEntry == nil)
    expect(Almanac.entry(id: entry.id, url: store.url) == nil)
    _ = try store.restoreDeletedPage(id, session: "person")
    expect(Almanac.entry(id: entry.id, url: store.url)?.file == entry.file)
    expect(store.almanacSnapshot.waitingEntry == nil) // restore is not a new preparation/notification
}
