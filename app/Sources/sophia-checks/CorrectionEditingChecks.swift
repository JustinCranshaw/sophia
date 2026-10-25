import Foundation
import SophiaCore

func editedCorrectionsKeepOriginalEvidenceAndReachNextTurn() throws {
    let store = try tempStore()
    let message = try store.appendTranscript(["role": .string("person"), "text": .string("I can follow simple tab slowly.")])
    let note = try store.appendLearning(["kind": .string("background"), "text": .string("Reads tab fluently."), "refs": .array([message["id"]!])], by: "sophia", session: "s-1")
    try store.setMemory([.init(id: nil, text: "Prefers no chronology.", refs: [note.str("id")!])], session: "s-1")
    for original in [note, store.memory[0]] {
        let id = original.str("id")!
        for text in ["First person correction.", "Refined person correction."] {
            try store.appendLearning(["kind": .string("correction"), "replaces": .string(id), "text": .string(text)], by: "person", session: "s-1")
        }
        expect(store.correction(of: id)?.str("text") == "Refined person correction.")
        expect(store.record(id) == original)
        for prompt in [Prompts.context(store), Prompts.turnPrefix(store, thread: "")] {
            expect(prompt.contains("Refined person correction."))
            expect(!prompt.contains("First person correction."))
            expect(prompt.contains(original.str("text")!))
            for ref in original["refs"]!.array! { expect(prompt.contains(ref.string!)) }
        }
        let removed = try store.deleteLearning(id)
        expect(removed.count == 3 && store.correction(of: id) == nil)
        try store.restoreLearning(removed)
        expect(store.record(id) == original)
        expect(store.correction(of: id)?.str("text") == "Refined person correction.")
    }
}
