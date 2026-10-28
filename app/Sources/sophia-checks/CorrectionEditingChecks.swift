import Foundation
import SophiaCore

func editedCorrectionsKeepOriginalEvidenceAndReachNextTurn() throws {
    let store = try tempStore()
    let message = try store.appendTranscript(["role": .string("person"), "text": .string("I can follow simple tab slowly.")])
    let note = try store.appendLearning(["kind": .string("background"), "text": .string("Reads tab fluently."), "refs": .array([message["id"]!])], by: "sophia", session: "s-1")
    try store.setMemory([.init(id: nil, text: "Prefers no chronology.", refs: [note.str("id")!])], session: "s-1")
    let originals = [note, store.memory[0]]
    // Legacy corrections are imported once, with their original evidence intact.
    for original in originals {
        for text in ["First person correction for ", "Refined person correction for "] {
            try store.appendLearning(["kind": .string("correction"), "replaces": original["id"]!, "text": .string(text + original.str("id")!)], by: "person", session: "s-1")
        }
    }
    try store.ensureNotebookPages(session: "migration")
    for original in originals {
        let id = original.str("id")!
        expect(store.record(id) == original)
        let history = EvidenceReference.resolve(id, in: store)
        expect(history.correction == "Refined person correction for " + id)
        for ref in original["refs"]!.array! { expect(store.record(id)?["refs"]?.array?.contains(ref) == true) }
        for prompt in [Prompts.context(store), Prompts.turnPrefix(store, thread: "")] {
            expect(prompt.contains("Refined person correction for " + id))
            expect(!prompt.contains("First person correction for " + id))
            expect(prompt.contains(original.str("text")!))
        }
    }
    // Afterwards the actual page editor owns corrections. No log projection may overwrite it.
    let notes = store.notebookPage(role: .notes)!
    let range = try store.beginEdit(file: notes.file, key: "(page)", session: "s-1")!
    let corrected = range.text + "\n\nMy current correction: I read tab slowly, with help."
    guard case .saved = try store.editPage(file: notes.file, section: "(page)", baseHash: range.hash, text: corrected, session: "s-1") else { throw NotebookStore.StoreError.notFound }
    store.endEdit()
    for prompt in [Prompts.context(store), Prompts.turnPrefix(store, thread: ""), Prompts.briefing(store)] {
        expect(prompt.contains("My current correction: I read tab slowly, with help."))
    }
    expect(store.protectedLines(of: notes.file).contains { $0.lines.contains("My current correction: I read tab slowly, with help.") })
    let before = store.readPage(notes.file)!.body
    try store.appendLearning(["kind": .string("correction"), "replaces": note["id"]!, "text": .string("A later historical-only correction")], by: "person", session: "s-1")
    try store.ensureNotebookPages(session: "restart")
    expect(store.readPage(notes.file)!.body == before)
    expect(store.record(note.str("id")!) == note)
}
