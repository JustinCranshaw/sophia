import Foundation
import SophiaCore

func goalEvidenceFollowsOnlyExplicitAttemptChains() throws {
    let store = try tempStore()
    let goal = try store.writeGoal(text: "Modes", criteria: ["Fixed shape", "Numerical example", "Amplitude and eigenvalue"], revising: nil, quote: nil, session: "s-1")
    let root = goal.str("id")!
    func note(_ kind: String, _ text: String, _ refs: [String], replacing: String? = nil) throws -> JSONObject {
        var fields: JSONObject = ["kind": .string(kind), "text": .string(text), "refs": .array(refs.map(JSON.string))]
        if let replacing { fields["replaces"] = .string(replacing) }
        return try store.appendLearning(fields, by: "sophia", session: "s-1")
    }
    let first = try note("attempt", "The shape stays proportional.", [])
    let unrelated = try note("attempt", "The shape stays proportional.", [])
    let revised = try note("attempt", "The ratio stays fixed while amplitude changes.", [], replacing: first.str("id")!)
    let read = try note("read", "Fixed shape supported; amplitude half covered, omega squared unshown.", [first.str("id")!, root + "#1", root + "#3"])
    expect(store.evidence(forCriterion: root + "#1").attempts == [revised])
    expect(store.evidence(forCriterion: root + "#3").attempts == [revised])
    expect(store.evidence(forCriterion: root + "#2").attempts.isEmpty)
    expect(store.evidence(forCriterion: root + "#2").read == nil)
    expect(store.attemptsWithoutCriterionLinks == [unrelated])
    let correction = try store.appendLearning(["kind": .string("correction"), "text": .string("I explained only the fixed ratio."), "replaces": revised["id"]!], by: "person", session: "s-1")
    expect(store.evidence(forCriterion: root + "#1").attempts == [revised])
    expect(store.correction(of: revised.str("id")!) == correction)
    expect(store.evidence(forCriterion: root + "#1").newerEvidence)
    _ = try store.appendLearning(["kind": .string("correction"), "text": .string("Amplitude is still partial."), "replaces": read["id"]!], by: "person", session: "s-1")
    expect(store.evidence(forCriterion: root + "#3").read == read)
    let removed = try store.deleteLearning(first.str("id")!)
    expect(store.evidence(forCriterion: root + "#1").attempts.isEmpty)
    expect(EvidenceReference.resolve(first.str("id")!, in: store).kind == .unavailable)
    try store.restoreLearning(removed)
    let reopened = try NotebookStore(url: store.url)
    expect(reopened.evidence(forCriterion: root + "#1").attempts == [revised])
    expect(reopened.correction(of: revised.str("id")!) == correction)
}

func goalEvidenceKeepsReadOrderAndHonestUnlinkedAttempts() throws {
    let store = try tempStore()
    let goal = try store.writeGoal(text: "Modes", criteria: ["Explain shape"], revising: nil, quote: nil, session: "s-1")
    let ref = goal.str("id")! + "#1"
    let attempt = try store.appendLearning(["kind": .string("attempt"), "text": .string("A direct linked attempt"), "refs": .array([.string(ref)])], by: "sophia", session: "s-1")
    expect(store.evidence(forCriterion: ref).attempts == [attempt])
    expect(store.evidence(forCriterion: ref).read == nil)
    let old = try store.appendLearning(["kind": .string("read"), "text": .string("Earlier tentative read"), "refs": .array([.string(ref)])], by: "sophia", session: "s-1")
    let removed = try store.deleteLearning(old.str("id")!)
    let latest = try store.appendLearning(["kind": .string("read"), "text": .string("Latest tentative read"), "refs": .array([.string(ref)])], by: "sophia", session: "s-1")
    try store.restoreLearning(removed)
    expect(store.evidence(forCriterion: ref).read == latest)
    let unlinked = try store.appendLearning(["kind": .string("attempt"), "text": .string("Discussed elsewhere"), "refs": .array([])], by: "sophia", session: "s-1")
    _ = try store.appendLearning(["kind": .string("read"), "text": .string("A saved read without a criterion"), "refs": .array([unlinked["id"]!])], by: "sophia", session: "s-1")
    let log = store.url.appendingPathComponent("learning.jsonl"), meta = store.url.appendingPathComponent("notebook.json")
    let before = try Data(contentsOf: log), metadata = try Data(contentsOf: meta)
    expect(store.attemptsWithoutCriterionLinks == [unlinked])
    expect(store.evidence(forCriterion: "g-9999#1").attempts.isEmpty)
    expect(try Data(contentsOf: log) == before && Data(contentsOf: meta) == metadata)
    expect(store.isProvisional(store.goals[0]))
}
