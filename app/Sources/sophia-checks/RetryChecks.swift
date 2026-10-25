import Foundation
import SophiaCore

func savedQuestionsRemainRetryableUntilCompletedStoppedOrCleared() throws {
    let store = try tempStore()
    let page = try store.writePage(title: "Soil", content: "Existing page stays readable.", revising: nil, session: "s-1", toolUseID: "seed").str("file")!
    let originalBody = store.readPage(page)?.body
    let text = "Are fungi helping plants or breaking down leaves?\nPlease answer here, with no page changes."
    let question = try store.appendTranscript(["role": .string("person"), "page": .string(""), "session": .string("s-1"), "text": .string(text)])
    expect(store.unansweredQuestion(in: "")?["id"] == question["id"])
    expect(store.unansweredQuestion(in: "", pending: true) == nil)
    let reopened = try NotebookStore.open(url: store.url)
    expect(reopened.unansweredQuestion(in: "")?.str("text") == text)
    expect(!Prompts.context(reopened, before: question.str("id")).contains("] person: " + text))
    let other = try store.appendTranscript(["role": .string("person"), "page": .string(page), "session": .string("s-1"), "text": .string("Question on the page.")])
    expect(store.unansweredQuestion(in: page, pending: NotebookStore.isPending(thread: page, running: nil, queued: [page])) == nil)
    expect(store.unansweredQuestion(in: page, pending: NotebookStore.isPending(thread: page, running: "", queued: []))?["id"] == other["id"])
    try store.appendTranscript(["role": .string("client"), "page": .string(page), "purpose": .string("replied")])
    expect(store.unansweredQuestion(in: page) == nil)
    expect(store.unansweredQuestion(in: "")?["id"] == question["id"])
    try store.appendTranscript(["role": .string("sophia"), "page": .string(""), "text": .string("A partial answer.")])
    let write = try store.writePage(title: "Saved before interruption", content: "A completed tool result.", revising: nil, session: "s-1", toolUseID: "partial")
    expect(store.hasPartialReply(to: question))
    let context = Prompts.context(store, before: question.str("id"))
    expect(context.contains("A partial answer.") && context.contains("Saved " + write.str("file")!))
    expect(!context.contains("] person: " + text))
    try store.appendTranscript(["role": .string("client"), "page": .string(""), "purpose": .string("stopped")])
    expect(store.unansweredQuestion(in: "") == nil)
    let again = try store.appendTranscript(["role": .string("person"), "page": .string(""), "text": .string(text)])
    expect(store.unansweredQuestion(in: "")?["id"] == again["id"])
    try store.appendTranscript(["role": .string("client"), "page": .string(""), "purpose": .string("clear")])
    expect(store.unansweredQuestion(in: "") == nil)
    // Legacy no-output failures remain recoverable; old replies without completion markers
    // are not mislabeled as interrupted, because their old client never wrote those markers.
    let legacy = try tempStore()
    let legacyFile = legacy.url.appendingPathComponent("transcript.jsonl")
    let questionRow: JSONObject = ["id": .string("t-0001"), "role": .string("person"), "text": .string("Old unanswered question.")]
    let answerRow: JSONObject = ["id": .string("t-0002"), "role": .string("sophia"), "text": .string("Old completed answer.")]
    try Data((JSON.object(questionRow).line + "\n").utf8).write(to: legacyFile)
    legacy.reload()
    expect(legacy.unansweredQuestion(in: "")?.str("id") == "t-0001")
    try Data((JSON.object(questionRow).line + "\n" + JSON.object(answerRow).line + "\n").utf8).write(to: legacyFile)
    legacy.reload()
    expect(legacy.unansweredQuestion(in: "") == nil)
    expect(store.readPage(page)?.body == originalBody)
}
