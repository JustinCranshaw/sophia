import Foundation
@testable import SophiaCore

func sharedAboutMigrationProposalsAndUndo() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("sophia-about-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let a = try NotebookStore(url: root.appendingPathComponent("A"))
    let b = try NotebookStore(url: root.appendingPathComponent("B"))
    for store in [a,b] {
        try store.appendTranscript(["role": .string("person"), "text": .string("I prefer examples from music."), "session": .string("s")])
    }
    let library = LibraryStore(root: root)
    _ = try library.setAbout(text: "I enjoy learning.", replacing: nil, notebook: nil)
    _ = try library.proposeAbout(text: "A pending preference", quote: "I prefer examples", revising: nil, from: a)
    _ = try library.proposeAbout(text: "B private preference", quote: "I prefer examples", revising: nil, from: b)
    let original = try Data(contentsOf: root.appendingPathComponent(".sophia/about.jsonl"))
    let shared = try library.ensureSharedAboutPage(session: "s")
    expect(Library(root: root).notebooks.count == 2)
    expect(library.otherNotebooks(than: "A").allSatisfy { $0.name != ".sophia" && $0.name != "about" })
    expect(shared.page.role == .about && shared.page.scope == .library)
    expect(shared.store.readPage(shared.page.file)?.body.contains("I enjoy learning.") == true)
    expect(shared.store.readPage(shared.page.file)?.body.contains("pending") == false)
    expect(shared.store.pendingPageProposals(originNotebook: "A").count == 1)
    expect(shared.store.pendingPageProposals(originNotebook: "B").count == 1)
    expect(shared.store.pageWrites.isEmpty)
    _ = try library.ensureSharedAboutPage(session: "again")
    expect(shared.store.pageProposalHistory.count == 2)
    expect(try Data(contentsOf: root.appendingPathComponent(".sophia/about.jsonl")) == original)
    let range = try shared.store.beginEdit(file: shared.page.file, key: "(page)", session: "s")!
    let proposal = try library.proposeAboutPage(content: "Personal new body", quote: "I prefer examples", from: a, session: "s")
    expectThrows { try shared.store.acceptPageProposal(proposal.str("id")!, session: "s") }
    shared.store.endEdit()
    let outcome = try shared.store.editPage(file: shared.page.file, section: "(page)", baseHash: range.hash, text: "My own correction", session: "s")
    guard case .saved(let edit) = outcome else { throw NotebookStore.StoreError.notFound }
    expectThrows { try shared.store.acceptPageProposal(proposal.str("id")!, session: "s") }
    let again = try library.ensureSharedAboutPage(session: "restart")
    expect(again.store.readPage(again.page.file)?.body.contains("My own correction") == true)
    try shared.store.undoPageWrite(edit.str("id")!, session: "s")
    let fresh = try library.proposeAboutPage(content: "Accepted music preference", quote: "I prefer examples", from: a, session: "s")
    let accepted = try shared.store.acceptPageProposal(fresh.str("id")!, session: "s")
    guard case .saved(let acceptedEdit) = accepted else { throw NotebookStore.StoreError.notFound }
    expect(!shared.store.protectedLines(of: shared.page.file).isEmpty)
    try shared.store.undoPageWrite(acceptedEdit.str("id")!, session: "s")
    expect(shared.store.readPage(shared.page.file)?.body.contains("I enjoy learning.") == true)
    let rejected = shared.store.pendingPageProposals(originNotebook: "B").first!
    try shared.store.rejectPageProposal(rejected.str("id")!, session: "s")
    expect(shared.store.pendingPageProposals(originNotebook: "B").isEmpty)
    expectThrows { try library.setAbout(text: "Do not mutate legacy audit", replacing: nil, notebook: nil) }
    let context = Prompts.context(a)
    expect(context.contains("A pending preference"))
    expect(!context.contains("B private preference"))
    expect(context.contains("I enjoy learning."))
}
