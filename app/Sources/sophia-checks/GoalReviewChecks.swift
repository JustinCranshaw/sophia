import Foundation
import SophiaCore

func goalConfirmationKeepsAllReviewedCriteriaAndProvenance() throws {
    let store = try tempStore()
    let text = "I want physical intuition and a tiny numerical example."
    let message = try store.appendTranscript(["role": .string("person"), "text": .string(text)])
    let criteria = ["Explain the physical picture.", "Work a small numerical example.", "Derive the eigenvalue condition."]
    let proposed = try store.writeGoal(text: "Understand vibration modes", criteria: criteria, revising: nil, quote: text, session: "s-1")
    let id = proposed.str("id")!
    expect(proposed["quote"]?["entry"] == message["id"])
    // Reword/status/criterion-add are not alternate confirmation paths.
    expectThrows { try store.updatePersonGoal(id, text: "Narrower", session: "s-1") }
    expectThrows { try store.updatePersonGoal(id, status: "met", session: "s-1") }
    expectThrows { try store.updatePersonGoal(id, addCriterion: "An unseen addition", session: "s-1") }
    let confirmed = try store.confirmGoalProposal(id, session: "s-1")
    expect(!store.isProvisional(confirmed))
    for key in ["text", "criteria", "quote", "refs"] { expect(confirmed[key] == proposed[key]) }
    expect(store.rootID(of: confirmed.str("id")!) == id)
    expect(confirmed["criteria"]?.array?.compactMap(\.string) == criteria)
}

func staleGoalDecisionsRefuseWithoutMutation() throws {
    let store = try tempStore()
    let first = try store.writeGoal(text: "Compare two sources", criteria: ["Distinguish source from interpretation"], revising: nil, quote: nil, session: "s-1")
    let second = try store.writeGoal(text: "Compare two sources in depth", criteria: ["Evaluate constitutional legacy"], revising: first.str("id"), quote: nil, session: "s-2")
    let file = store.url.appendingPathComponent("learning.jsonl"), meta = store.url.appendingPathComponent("notebook.json")
    let before = try Data(contentsOf: file), metadata = try Data(contentsOf: meta)
    expectThrows { try store.confirmGoalProposal(first.str("id")!, session: "s-1") }
    expectThrows { try store.declineGoalProposal(first.str("id")!, session: "s-1") }
    expect(try Data(contentsOf: file) == before && Data(contentsOf: meta) == metadata)
    expect(store.goals == [second])
    let confirmed = try store.confirmGoalProposal(second.str("id")!, session: "s-1")
    _ = try store.writeGoal(text: "Another revision", criteria: ["A further criterion"], revising: confirmed.str("id"), quote: nil, session: "s-3")
    let changed = try Data(contentsOf: file)
    expectThrows { try store.updatePersonGoal(confirmed.str("id")!, text: "A stale edit", session: "s-1") }
    expect(try Data(contentsOf: file) == changed)
}

func wholeGoalDeclinePreservesEarlierScopeAndEvidencePositions() throws {
    let store = try tempStore()
    let question = "I want to hold a half note for two clicks."
    try store.appendTranscript(["role": .string("person"), "text": .string(question)])
    let proposed = try store.writeGoal(text: "Count two bars", criteria: ["Hold the note for two clicks"], revising: nil, quote: question, session: "s-1")
    let base = try store.confirmGoalProposal(proposed.str("id")!, session: "s-1")
    let root = store.rootID(of: base.str("id")!)
    let note = try store.appendLearning(["kind": .string("attempt"), "text": .string("Evidence for the original first criterion"), "refs": .array([.string(root + "#1")])], by: "sophia", session: "s-1")
    let revision = try store.writeGoal(text: "Count and perform", criteria: [], revising: base.str("id"), quote: question, session: "s-2")
    expect(try store.declineGoalProposal(revision.str("id")!, session: "s-1").isEmpty)
    let kept = store.goals[0]
    expect(!store.isProvisional(kept) && store.rootID(of: kept.str("id")!) == root)
    for key in ["text", "criteria", "quote", "refs"] { expect(kept[key] == base[key]) }
    expect(store.record(note.str("id")!) == note)
    expect(store.record(revision.str("id")!) == revision)
    let other = try store.writeGoal(text: "An unwanted whole proposal", criteria: ["Too broad"], revising: nil, quote: nil, session: "s-3")
    let removed = try store.declineGoalProposal(other.str("id")!, session: "s-1")
    expect(removed == [other] && !store.goals.contains { $0["id"] == other["id"] })
    try store.restoreLearning(removed)
    expect(store.goals.contains(other))
}

func decliningReferencedCriteriaCannotRetargetTheirEvidence() throws {
    let store = try tempStore()
    let first = try store.writeGoal(text: "Goal", criteria: ["Criterion A"], revising: nil, quote: nil, session: "s-1")
    let confirmed = try store.confirmGoalProposal(first.str("id")!, session: "s-1")
    let root = store.rootID(of: confirmed.str("id")!)
    let revision = try store.writeGoal(text: "Goal with B", criteria: ["Criterion B"], revising: confirmed.str("id"), quote: nil, session: "s-2")
    let note = try store.appendLearning(["kind": .string("attempt"), "text": .string("Evidence about B"), "refs": .array([.string(root + "#2")])], by: "sophia", session: "s-2")
    let file = store.url.appendingPathComponent("learning.jsonl"), before = try Data(contentsOf: file)
    expectThrows { try store.declineGoalProposal(revision.str("id")!, session: "s-1") }
    expect(try Data(contentsOf: file) == before)
    expect(store.goals == [revision] && store.record(note.str("id")!) == note)
    if let current = store.goals.first, !store.isProvisional(current) {
        let later = try store.updatePersonGoal(current.str("id")!, addCriterion: "Criterion C", session: "s-3")
        print("  repro: saved evidence " + root + "#2 now resolves to " + (later["criteria"]?.array?.last?.string ?? "missing"))
        expect(later["criteria"]?.array?.last?.string == "Criterion B")
    }
}

func deletedCriterionEvidenceCannotBeRetargetedBeforeUndo() throws {
    let store = try tempStore()
    let first = try store.writeGoal(text: "Goal", criteria: ["Criterion A"], revising: nil, quote: nil, session: "s-1")
    let confirmed = try store.confirmGoalProposal(first.str("id")!, session: "s-1")
    let root = store.rootID(of: confirmed.str("id")!)
    let revision = try store.writeGoal(text: "Goal with B", criteria: ["Criterion B"], revising: confirmed.str("id"), quote: nil, session: "s-2")
    let note = try store.appendLearning(["kind": .string("attempt"), "text": .string("Evidence about B"), "refs": .array([.string(root + "#2")])], by: "sophia", session: "s-2")
    let removed = try store.deleteLearning(note.str("id")!)
    expectThrows { try store.declineGoalProposal(revision.str("id")!, session: "s-1") }
    if let current = store.goals.first, !store.isProvisional(current) {
        _ = try store.updatePersonGoal(current.str("id")!, addCriterion: "Criterion C", session: "s-3")
    }
    try store.restoreLearning(removed)
    let current = store.goals[0]
    if current["criteria"]?.array?[1].string != "Criterion B" { print("  undo criterion reference " + root + "#2 resolves to " + (current["criteria"]?.array?.last?.string ?? "missing")) }
    expect(current["criteria"]?.array?[1].string == "Criterion B")
    expect(store.record(note.str("id")!) == note && store.isProvisional(current))
}
