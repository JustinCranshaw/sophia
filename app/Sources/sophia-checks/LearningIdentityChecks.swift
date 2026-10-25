import Foundation
import SophiaCore

func learningIdentitiesSurviveDeletionCorrectionAndUndo() throws {
    let store = try tempStore()
    let a = try store.appendLearning(["kind": .string("background"), "text": .string("Note A"), "refs": .array([.string("t-0001")])], by: "sophia", session: "s-1")
    let b = try store.appendLearning(["kind": .string("background"), "text": .string("Note B"), "refs": .array([.string("t-0002")])], by: "sophia", session: "s-1")
    let removed = try store.deleteLearning(b.str("id")!)
    let reopened = try NotebookStore(url: store.url)
    let correction = try reopened.appendLearning(["kind": .string("correction"), "replaces": a["id"]!, "text": .string("Person's corrected A")], by: "person", session: "s-2")
    expect(correction.str("id") == "n-3")
    try store.restoreLearning(removed) // Other process reloads the reserved watermark under lock.
    expect(store.record(b.str("id")!) == b && store.record(a.str("id")!) == a)
    expect(store.correction(of: a.str("id")!) == correction && store.correction(of: b.str("id")!) == nil)
    expect(store.rootID(of: correction.str("id")!) == a.str("id"))
    expect(Set(store.learning.compactMap { $0.str("id") }).count == store.learning.count)
    let next = try store.appendLearning(["kind": .string("background"), "text": .string("After Undo")], by: "sophia", session: "s-2")
    expect(next.str("id") == "n-4")
    let goal = try store.appendLearning(["kind": .string("goal"), "text": .string("Old goal")], by: "person", session: "s-2")
    _ = try store.deleteLearning(goal.str("id")!)
    let afterReopen = try NotebookStore(url: store.url).appendLearning(["kind": .string("goal"), "text": .string("New goal")], by: "person", session: "s-3")
    expect(afterReopen.str("id") == "g-2")
}

func legacyLearningReferencesReserveIDsAndRestoreRefusesCollisions() throws {
    let store = try tempStore()
    try store.appendTranscript(["role": .string("tool"), "record": .string("n-80"), "kept": .array([.string("n-90")]), "refs": .array([.string("g-40#2")]), "text": .string("n-9999 is only prose, not an identity reference.")])
    let first = try store.appendLearning(["kind": .string("background"), "text": .string("Legacy references")], by: "sophia", session: "s-1")
    expect(first.str("id") == "n-91")
    let goal = try store.appendLearning(["kind": .string("goal"), "text": .string("A new goal")], by: "person", session: "s-1")
    expect(goal.str("id") == "g-41")
    let before = try Data(contentsOf: store.url.appendingPathComponent("learning.jsonl"))
    let metaBefore = try Data(contentsOf: store.url.appendingPathComponent("notebook.json"))
    expectThrows { try store.restoreLearning([first]) }
    expect(try Data(contentsOf: store.url.appendingPathComponent("learning.jsonl")) == before)
    expect(try Data(contentsOf: store.url.appendingPathComponent("notebook.json")) == metaBefore)
    var conflicting = first; conflicting["text"] = .string("A different legacy record with the same ID")
    expectThrows { try store.restoreLearning([conflicting]) }
    expect(store.record(first.str("id")!) == first)
    var deleted = first; deleted["id"] = .string("n-200")
    expectThrows { try store.restoreLearning([deleted, deleted]) }
    expect(store.learning.count == 2)
    // A legacy collision already on disk is not repaired or allowed to spread.
    try Data((JSON.object(first).line + "\n" + JSON.object(conflicting).line + "\n").utf8).write(to: store.url.appendingPathComponent("learning.jsonl"))
    store.reload()
    expectThrows { try store.appendLearning(["kind": .string("correction"), "replaces": first["id"]!, "text": .string("Ambiguous target")], by: "person", session: "s-1") }
    expectThrows { try store.deleteLearning(first.str("id")!) }
    expect(store.learning.count == 2)
}

func aFailedLearningAppendKeepsExistingEvidence() throws {
    let store = try tempStore()
    try store.appendLearning(["kind": .string("background"), "text": .string("Existing evidence must survive.")], by: "sophia", session: "s-1")
    let file = store.url.appendingPathComponent("learning.jsonl")
    let before = try Data(contentsOf: file)
    try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: file.path)
    defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: file.path) }
    expectThrows { try store.appendLearning(["kind": .string("correction"), "replaces": .string("n-1"), "text": .string("A draft that could not be saved.")], by: "person", session: "s-1") }
    expect(try Data(contentsOf: file) == before)
    // Transcript uses the same append helper and must retain its existing evidence too.
    try store.appendTranscript(["role": .string("person"), "text": .string("An existing question")])
    let transcript = store.url.appendingPathComponent("transcript.jsonl")
    let conversation = try Data(contentsOf: transcript)
    try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: transcript.path)
    defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: transcript.path) }
    expectThrows { try store.appendTranscript(["role": .string("person"), "text": .string("A second question that cannot be saved")]) }
    expect(try Data(contentsOf: transcript) == conversation)
}
