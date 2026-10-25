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
    let noteCorrection = "Their phase objection corrected Sophia, not a learner weakness."
    let foreignCorrection = "This correction belongs only in the other inquiry."
    let memoryCorrection = "This is the person's notebook-wide memory correction."
    expect(!Prompts.turnPrefix(store, thread: a).contains(noteCorrection))
    // The same store API used by the native Notes correction action.
    for (record, text) in [(note, noteCorrection), (foreign, foreignCorrection), (store.memory[0], memoryCorrection)] {
        try store.appendLearning(["kind": .string("correction"), "replaces": record["id"]!, "text": .string(text)], by: "person", session: "s-1")
    }
    let context = Prompts.context(store, thread: a)
    let prefix = Prompts.turnPrefix(store, thread: a)
    for text in [noteCorrection, memoryCorrection, "Sophia misread the phase objection."] {
        expect(context.contains(text))
        expect(prefix.contains(text))
    }
    expect(context.contains("\"by\":\"sophia\"") && context.contains("\"by\":\"person\""))
    expect(prefix.contains("\"by\":\"sophia\"") && prefix.contains("\"by\":\"person\""))
    expect(!context.contains(foreignCorrection) && !prefix.contains(foreignCorrection))
    let otherPrefix = Prompts.turnPrefix(store, thread: b)
    expect(otherPrefix.contains(foreignCorrection) && otherPrefix.contains(memoryCorrection))
    expect(!otherPrefix.contains(noteCorrection))
    expect(Prompts.briefing(store).contains(noteCorrection))
}
