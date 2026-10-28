import Foundation
@testable import SophiaCore

func notebookLearningPagesKeepMarkdownAndHistoricalEvidence() throws {
    let store = try tempStore()
    defer { try? FileManager.default.removeItem(at: store.url) }
    let message = try store.appendTranscript(["role": .string("person"), "text": .string("I want to understand entropy, and I need musical examples."), "session": .string("s")])
    let ref = message.str("id")!
    let goal = try store.writeGoal(text: "Understand entropy", criteria: ["Explain uncertainty"], revising: nil, quote: "I want to understand entropy", session: "s")
    var confirmed: JSONObject = ["kind": .string("goal"), "replaces": goal["id"]!, "text": .string("Understand entropy"), "criteria": goal["criteria"]!, "status": .string("working")]
    confirmed = try store.appendLearning(confirmed, by: "person", session: "s")
    let revision = try store.writeGoal(text: "Understand entropy with music", criteria: ["Compare distributions"], revising: confirmed.str("id"), quote: "I need musical examples", session: "s")
    let note = try store.writeNote(["kind": .string("background"), "text": .string("A tentative earlier interpretation"), "refs": .array([.string(ref)])], quote: "I need musical examples", revising: nil, session: "s").saved!
    let correction = try store.appendLearning(["kind": .string("correction"), "replaces": note["id"]!, "text": .string("My actual correction")], by: "person", session: "s")
    _ = try store.setMemory([.init(id: nil, text: "Earlier working memory", refs: [ref])], session: "s")
    let originalLearning = try Data(contentsOf: store.url.appendingPathComponent("learning.jsonl"))
    let staleToolStore = try NotebookStore(url: store.url)
    let imported = try store.ensureNotebookPages(session: "migration")
    expect(imported.count == 3)
    let goals = store.notebookPage(role: .goals)!, notes = store.notebookPage(role: .notes)!, memory = store.notebookPage(role: .memory)!
    expect(store.readPage(goals.file)!.body.contains("## Understand entropy\n"))
    expect(!store.readPage(goals.file)!.body.contains("with music"))
    expect(store.pendingPageProposals(originNotebook: store.name).contains { $0.str("legacyID") == revision.str("id") && $0.str("content")?.contains("with music") == true })
    expect(try Data(contentsOf: store.url.appendingPathComponent("learning.jsonl")) == originalLearning)
    expect(store.record(goal.str("id")!) != nil && store.record(correction.str("id")!) != nil)
    expect(!store.protectedLines(of: notes.file).isEmpty)
    expect(store.pageWrites.isEmpty)
    // Even a long-lived tool store rereads role metadata under its write lock.
    expectThrows { try staleToolStore.writeConversationPage(title: "Goals", content: "Bypass review", revising: goals.file, session: "s", toolUseID: "bypass") }
    expectThrows { try staleToolStore.writeConversationPage(title: "Notes", content: "Bypass evidence", revising: notes.file, session: "s", toolUseID: "bypass") }
    try store.ensureNotebookPages(session: "restart")
    expect(store.pendingPageProposals(originNotebook: store.name).count == 1)
    expectThrows { try store.writeNotebookNotes(content: "Unsupported change", refs: [], session: "s") }
    let refused = try store.writeNotebookNotes(content: "Erase the person’s imported correction", refs: [ref], session: "s")
    expect(refused["refused"] == .bool(true))
    let initialNotes = store.readPage(notes.file)!.body
    let written = try store.writeNotebookNotes(content: initialNotes + "\nA new interpretation backed by the conversation.", refs: [ref], session: "s")
    expect(written["refused"] != .bool(true))
    try store.undoPageWrite(written.str("id")!, session: "s")
    expect(store.readPage(notes.file)!.body == initialNotes)
    let range = try store.beginEdit(file: memory.file, key: "(page)", session: "s")!
    let personal = try store.editPage(file: memory.file, section: "(page)", baseHash: range.hash, text: "My personal working memory", session: "s")
    guard case .saved = personal else { throw NotebookStore.StoreError.notFound }
    store.endEdit()
    expect(try store.writeNotebookMemory(content: "Overwrite personal words", refs: [ref], session: "s")["refused"] == .bool(true))
    let before = store.readPage(memory.file)!.body
    try store.ensureNotebookPages(session: "again")
    expect(store.readPage(memory.file)!.body == before)
    let context = Prompts.context(store)
    expect(context.contains("My personal working memory"))
    expect(!Prompts.memoryText(store).contains("Earlier working memory"))
    let proposal = try store.proposeGoalsPage(content: "A freeform goal paragraph", quote: "I want to understand entropy", session: "s")
    let goalRange = try store.beginEdit(file: goals.file, key: "(page)", session: "s")!
    _ = try store.editPage(file: goals.file, section: "(page)", baseHash: goalRange.hash, text: "My chosen goals", session: "s")
    store.endEdit()
    expectThrows { try store.acceptPageProposal(proposal.str("id")!, session: "s") }
    expect(store.readPage(goals.file)!.body.contains("My chosen goals"))
}

func notebookPageCheckpointValidatesBeforeWriting() throws {
    let store = try tempStore()
    defer { try? FileManager.default.removeItem(at: store.url) }
    let message = try store.appendTranscript(["role": .string("person"), "text": .string("Explain with a concrete example."), "session": .string("s")])
    let ref = message.str("id")!
    try store.ensureNotebookPages(session: "s")
    let notes = store.notebookPage(role: .notes)!, memory = store.notebookPage(role: .memory)!
    let body: JSONObject = ["notes": .string("A useful example remains open."), "memory": .string("Return to the example."), "refs": .array([.string(ref)])]
    expect(try store.finishNotebookPageCheckpoint(body.line, failed: false, through: ref, entries: [ref], session: "s", catchUp: false) == .saved)
    expect(store.readPage(notes.file)!.body.contains("A useful example"))
    expect(store.readPage(memory.file)!.body.contains("Return to the example"))
    let latest = store.pageWrites.last!
    try store.undoPageWrite(latest.str("id")!, session: "s")
    let oldShape = "{\"notes\": [], \"memory\": []}"
    expect(try store.finishNotebookPageCheckpoint(oldShape, failed: false, through: ref, entries: [ref], session: "s", catchUp: false) == .failed)
    let range = try store.beginEdit(file: memory.file, key: "(page)", session: "s")!
    _ = try store.editPage(file: memory.file, section: "(page)", baseHash: range.hash, text: "My protected memory", session: "s")
    store.endEdit()
    let notesBefore = store.readPage(notes.file)!.body
    expect(try store.finishNotebookPageCheckpoint(body.line, failed: false, through: ref, entries: [ref], session: "s", catchUp: false) == .failed)
    expect(store.readPage(notes.file)!.body == notesBefore)
    // A damaged audit log must refuse before a canonical body changes.
    let duplicate = store.learning.first!
    let log = store.url.appendingPathComponent("learning.jsonl")
    var bytes = try Data(contentsOf: log)
    bytes.append(Data((duplicate.line + "\n").utf8))
    try bytes.write(to: log, options: .atomic)
    store.reload()
    expectThrows { try store.writeNotebookNotes(content: "Should not replace notes when evidence cannot be recorded", refs: [ref], session: "another") }
    expect(store.readPage(notes.file)!.body == notesBefore)
}
