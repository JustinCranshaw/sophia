import Foundation
import SophiaCore

func evidenceReferencesRevealActualLocalMaterialWithoutWrites() throws {
    let store = try tempStore()
    let words = "I can calculate eigenvectors but want the physical picture."
    let person = try store.appendTranscript(["role": .string("person"), "text": .string(words)])
    let reply = try store.appendTranscript(["role": .string("sophia"), "text": .string("A pure mode preserves its relative displacement shape.")])
    let file = try store.writePage(title: "Mode shapes", content: "## Physical picture\nThe shape scales; it does not rotate.", revising: nil, session: "s-1", toolUseID: "tu").str("file")!
    let goal = try store.writeGoal(text: "Understand modes", criteria: ["Explain fixed shape", "Use a numerical example"], revising: nil, quote: words, session: "s-1")
    let log = store.url.appendingPathComponent("transcript.jsonl"), learn = store.url.appendingPathComponent("learning.jsonl")
    let before = try Data(contentsOf: log), learning = try Data(contentsOf: learn)
    let exchange = EvidenceReference.resolve(person.str("id")!, in: store)
    expect(exchange.kind == .exchange && exchange.heading == "Your words" && exchange.text == words && exchange.date == person.str("at"))
    expect(EvidenceReference.resolve(reply.str("id")!, in: store).heading == "Sophia's reply")
    let page = EvidenceReference.resolve("p:" + file, in: store)
    expect(page.kind == .page && page.label == "Mode shapes" && page.page == file && page.text.contains("does not rotate"))
    let criterion = EvidenceReference.resolve(goal.str("id")! + "#2", in: store)
    expect(criterion.kind == .goal && criterion.label == "Use a numerical example" && criterion.heading.contains("Understand modes"))
    expect(EvidenceReference.resolve(goal.str("id")!, in: store).text.contains("1. Explain fixed shape"))
    expect(try Data(contentsOf: log) == before && Data(contentsOf: learn) == learning)
}

func evidenceReferencesDistinguishOriginalInterpretationAndCorrection() throws {
    let store = try tempStore()
    let person = try store.appendTranscript(["role": .string("person"), "text": .string("I challenged Sophia's wording.")])
    let note = try store.appendLearning(["kind": .string("attempt"), "text": .string("Sophia inferred uncertainty."), "quote": .object(["entry": person["id"]!, "text": person["text"]!]), "refs": .array([person["id"]!])], by: "sophia", session: "s-1")
    let id = note.str("id")!
    _ = try store.appendLearning(["kind": .string("correction"), "text": .string("My challenge was valid; the original explanation was wrong."), "replaces": .string(id)], by: "person", session: "s-1")
    let resolved = EvidenceReference.resolve(id, in: store)
    expect(resolved.heading == "Sophia's interpretation" && resolved.text == note.str("text"))
    expect(resolved.quote == person.str("text") && resolved.correction == "My challenge was valid; the original explanation was wrong.")
    expect(resolved.label.contains("My challenge was valid"))
    let memory = try store.appendLearning(["kind": .string("memory"), "text": .string("Keep track of the corrected account."), "refs": .array([.string(id)])], by: "sophia", session: "s-1")
    expect(EvidenceReference.resolve(memory.str("id")!, in: store).heading == "Sophia's working memory")
}

func unavailableEvidenceCannotBecomeAnArbitraryPageOrCriterion() throws {
    let store = try tempStore()
    let person = try store.appendTranscript(["role": .string("person"), "text": .string("Original exchange")])
    let goal = try store.writeGoal(text: "Goal", criteria: ["First criterion"], revising: nil, quote: nil, session: "s-1")
    let note = try store.appendLearning(["kind": .string("question"), "text": .string("Deleted note"), "refs": .array([person["id"]!])], by: "sophia", session: "s-1")
    _ = try store.deleteLearning(note.str("id")!)
    for ref in [note.str("id")!, "p:../notebook.json", "p:https://example.com", "p:missing.md", "t-missing", "g-missing#1", goal.str("id")! + "#0", goal.str("id")! + "#2", goal.str("id")! + "#1#2", "unrecognized"] {
        let evidence = EvidenceReference.resolve(ref, in: store)
        expect(evidence.kind == .unavailable && evidence.page == nil && evidence.reference == ref)
    }
    let files = try FileManager.default.contentsOfDirectory(atPath: store.url.path)
    _ = EvidenceReference.resolve("p:missing.md", in: store)
    expect(try FileManager.default.contentsOfDirectory(atPath: store.url.path) == files)
}
