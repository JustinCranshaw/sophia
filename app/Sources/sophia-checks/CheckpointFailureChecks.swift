import Foundation
import SophiaCore

func checkpointFailuresPreserveTheQuestionAndExposePartialNotes() throws {
    let store = try tempStore()
    let files = FileManager.default
    defer { try? files.removeItem(at: store.url) } // this function's exact owned fixture only
    let page = try store.writePage(title: "Checkpoint fixture", content: "SYNTHETIC checkpoint persistence fixture.", revising: nil, session: "fixture", toolUseID: "fixture").str("file")!
    let pageBytes = try Data(contentsOf: store.pagesURL.appendingPathComponent(page))
    let question = try store.appendTranscript(["role": .string("person"), "session": .string("fixture"), "text": .string("Keep the open question; do not change my page.")]).str("id")!
    let originalTranscript = store.transcript
    expect(try store.finishCheckpoint("not JSON", failed: false, through: question, entries: [question], session: "fixture", catchUp: false) == .failed)
    let rejected = JSON.object(["notes": .array([.object(["kind": .string("question"), "text": .string("Invalid evidence"), "refs": .array([.string("t-does-not-exist")])])])]).line
    expect(try store.finishCheckpoint(rejected, failed: false, through: question, entries: [question], session: "fixture", catchUp: false) == .failed)
    expect(store.learning.isEmpty && store.transcript == originalTranscript)
    let valid = JSON.object(["notes": .array([.object(["kind": .string("question"), "text": .string("A controlled kept note"), "refs": .array([.string(question)])])])]).line
    let transcript = store.url.appendingPathComponent("transcript.jsonl")
    try files.setAttributes([.posixPermissions: 0o444], ofItemAtPath: transcript.path)
    expectThrows { try store.finishCheckpoint(valid, failed: false, through: question, entries: [question], session: "fixture", catchUp: false) }
    store.reload()
    expect(store.learning.count == 1) // A failure does not imply "nothing saved".
    expect(store.transcript == originalTranscript)
    expect(store.unnotedMessages.map { $0.str("id") } == [question])
    expect(try Data(contentsOf: store.pagesURL.appendingPathComponent(page)) == pageBytes)
    try files.setAttributes([.posixPermissions: 0o644], ofItemAtPath: transcript.path)
    // A deliberate retention-aware retry need not repeat the note already on disk.
    expect(try store.finishCheckpoint("{\"notes\":[]}", failed: false, through: question, entries: [question], session: "fixture", catchUp: false) == .saved)
    expect(store.learning.count == 1)
    expect(store.transcript.filter { $0.str("purpose") == "checkpoint" }.count == 1)
    expect(store.unnotedMessages.isEmpty)
    expect(try Data(contentsOf: store.pagesURL.appendingPathComponent(page)) == pageBytes)
}
