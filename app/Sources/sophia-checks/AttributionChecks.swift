import Foundation
import SophiaCore

func personCorrectionsReachFreshAndOngoingThreadContext() throws {
    let store = try tempStore()
    let a = try store.writePage(title: "Modes", content: "Mode shapes.", revising: nil, session: "s-1", toolUseID: "seed-a").str("file")!
    let b = try store.writePage(title: "Other inquiry", content: "A separate topic.", revising: nil, session: "s-1", toolUseID: "seed-b").str("file")!
    let statement = "Opposite signs move oppositely."
    let message = try store.appendTranscript(["role": .string("person"), "page": .string(a), "session": .string("s-1"), "text": .string(statement)])
    let note = try store.appendLearning(["kind": .string("attempt"), "text": .string("Sophia misread the phase objection."), "quote": .object(["entry": message["id"]!, "text": .string(statement)])], by: "sophia", session: "s-1")
    let foreign = try store.appendLearning(["kind": .string("background"), "text": .string("Foreign note wording."), "refs": .array([.string("p:" + b)])], by: "sophia", session: "s-1")
    try store.setMemory([.init(id: nil, text: "A shared memory interpretation.", refs: [note.str("id")!])], session: "s-1")
    try store.ensureNotebookPages(session: "migration")
    let noteCorrection = "Their phase objection corrected Sophia, not a learner weakness."
    let memoryCorrection = "This is the person's notebook-wide memory correction."
    expect(!Prompts.turnPrefix(store, thread: a).contains(noteCorrection))
    // These are the same checked editor operations the native shared-page UI invokes.
    for (role, correction) in [(NotebookStore.PageRole.notes, noteCorrection), (.memory, memoryCorrection)] {
        let page = store.notebookPage(role: role)!
        let range = try store.beginEdit(file: page.file, key: "(page)", session: "s-1")!
        guard case .saved = try store.editPage(file: page.file, section: "(page)", baseHash: range.hash,
            text: range.text + "\n\nYour correction: " + correction, session: "s-1") else { throw NotebookStore.StoreError.notFound }
        store.endEdit()
        expect(!store.protectedLines(of: page.file).isEmpty)
    }
    for prompt in [Prompts.context(store, thread: a), Prompts.turnPrefix(store, thread: a), Prompts.turnPrefix(store, thread: b), Prompts.briefing(store)] {
        expect(prompt.contains(noteCorrection))
        expect(prompt.contains(memoryCorrection))
        expect(prompt.contains("Sophia misread the phase objection."))
    }
    // Notes are now one editable notebook page. Their source identities remain historical evidence.
    expect(store.record(note.str("id")!)?["quote"]?["entry"] == message["id"])
    expect(store.record(foreign.str("id")!)?["refs"]?.array == [.string("p:" + b)])
    let other = try tempStore()
    expect(!Prompts.context(other).contains(noteCorrection))
    expect(!Prompts.turnPrefix(other, thread: "").contains(memoryCorrection))
    expect(!Prompts.briefing(other).contains("Sophia misread the phase objection."))
}
