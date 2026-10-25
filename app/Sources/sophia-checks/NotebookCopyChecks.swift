import Foundation
@testable import SophiaCore

private func copiedFiles(_ root: URL) throws -> [String: Data] {
    var files: [String: Data] = [:]
    let enumerator = FileManager.default.enumerator(atPath: root.path)!
    for case let relative as String in enumerator {
        let url = root.appendingPathComponent(relative)
        if try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
            files[relative] = try Data(contentsOf: url)
        }
    }
    return files
}

func wholeNotebookCopyPreservesBytesEvidenceAndContinuedWrites() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("sophia-copy-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appendingPathComponent("source/Restored inquiry"), destination = root.appendingPathComponent("destination/Restored inquiry")
    let store = try NotebookStore(url: source)
    let person = try store.appendTranscript(["role": .string("person"), "text": .string("I want to understand why the octave halves a string's length.")])
    let page = try store.writePage(title: "String modes", content: "Original evidence.", revising: nil, session: "copy-fixture", toolUseID: "first").str("file")!
    _ = try store.writePage(title: "String modes", content: "Revised evidence, tied to the conversation.", revising: page, session: "copy-fixture", toolUseID: "revision")
    let second = try store.writePage(title: "An open question", content: "What changes with tension?", revising: nil, session: "copy-fixture", toolUseID: "second").str("file")!
    _ = try store.fileInChapter([second, page], chapter: "1. Questions")
    let goal = try store.writeGoal(text: "Understand octave length", criteria: ["Explain the physical reason"], revising: nil, quote: person.str("text"), session: "copy-fixture")
    _ = try store.confirmGoalProposal(goal.str("id")!, session: "copy-fixture")
    let note = try store.appendLearning(["kind": .string("question"), "text": .string("What does tension change?"), "refs": .array([person["id"]!])], by: "sophia", session: "copy-fixture")
    _ = try store.appendLearning(["kind": .string("correction"), "text": .string("Compare fixed tension first."), "replaces": note["id"]!], by: "person", session: "copy-fixture")
    let deleted = try store.appendLearning(["kind": .string("question"), "text": .string("Deleted fixture")], by: "sophia", session: "copy-fixture")
    _ = try store.deleteLearning(deleted.str("id")!)
    let bytes = try copiedFiles(source), metadata = store.meta
    try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
    try FileManager.default.copyItem(at: source, to: destination)
    expect(try copiedFiles(destination) == bytes)
    let restored = try NotebookStore.open(url: destination)
    expect(restored.meta == metadata && restored.transcript == store.transcript && restored.learning == store.learning)
    expect(restored.chapters.first?.pages.map(\.file) == [second, page])
    expect(restored.goals == store.goals && restored.correction(of: note.str("id")!)?.str("text") == "Compare fixed tension first.")
    expect(restored.record(note.str("id")!)?["refs"] == .array([person["id"]!]))
    let revision = restored.pageWrite(toolUse: "revision")!
    expect(restored.isUndoable(revision))
    try restored.undoPageWrite(revision.str("id")!, session: "restored")
    expect(restored.readPage(page)?.body.trimmingCharacters(in: .whitespacesAndNewlines) == "Original evidence.")
    let next = try restored.appendLearning(["kind": .string("question"), "text": .string("Continue the restored inquiry"), "refs": .array([person["id"]!])], by: "sophia", session: "restored")
    expect(Int(next.str("id")!.dropFirst(2))! > Int(deleted.str("id")!.dropFirst(2))!)
    expect(try copiedFiles(source) == bytes) // Continuing/Undo on the restore never changes the backup.
}

func wholeLibraryCopyIncludesSharedBackgroundAndLinks() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("sophia-library-copy-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appendingPathComponent("source"), destination = root.appendingPathComponent("destination")
    let a = try NotebookStore(url: source.appendingPathComponent("A")), b = try NotebookStore(url: source.appendingPathComponent("B"))
    let pa = try a.writePage(title: "Mode", content: "Evidence A", revising: nil, session: "fixture", toolUseID: "a").str("file")!
    let pb = try b.writePage(title: "Octave", content: "Evidence B", revising: nil, session: "fixture", toolUseID: "b").str("file")!
    let shared = LibraryStore(root: source)
    _ = try shared.setAbout(text: "Synthetic fixture: I prefer a physical example.", replacing: nil, notebook: nil)
    let link = try shared.proposeLink(from: a, page: pa, toNotebook: b.name, toPage: pb, reason: "Related modes").saved!
    try shared.confirmLink(link.str("id")!)
    let bytes = try copiedFiles(source)
    try FileManager.default.copyItem(at: source, to: destination)
    let copied = try copiedFiles(destination)
    expect(copied == bytes)
    let restored = LibraryStore(root: destination)
    expect(restored.about == shared.about && restored.links == shared.links)
    expect(restored.mayRead(pb, in: b.name, from: a.name))
    expect(Library(root: destination).notebooks.map(\.lastPathComponent) == ["A", "B"])
}
