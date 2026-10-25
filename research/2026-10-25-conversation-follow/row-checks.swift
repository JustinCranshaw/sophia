import Foundation
import SophiaCore
func entry(_ id: String, _ role: String, _ text: String = "", _ purpose: String? = nil) -> JSONObject {
    var e: JSONObject = ["id": .string(id), "role": .string(role), "text": .string(text)]
    if let purpose { e["purpose"] = .string(purpose) }
    return e
}
var checkCount = 0
func check(_ value: @autoclosure () -> Bool, _ name: String) {
    precondition(value(), name); checkCount += 1; print("ok " + name)
}
let brief = entry("t-1", "sophia", "Welcome", "briefing")
let question = entry("t-2", "person", "First question")
let first = entry("t-3", "sophia", "First block")
let tool = entry("t-4", "tool")
let second = entry("t-5", "sophia", "Second block")
let before = conversationRows([brief, question], streaming: "First block", scope: "A/P")
let committed = conversationRows([brief, question, first], streaming: "", scope: "A/P")
check(before.last!.id == committed.last!.id, "stream-to-record preserves reader identity")
check(before.last!.anchor == nil && committed.last!.anchor == "t-3", "real anchor appears separately")
check(before.first!.id != before.last!.id, "briefing before first question does not alias first reply")
let interleaved = conversationRows([brief, question, first, tool], streaming: "Second block", scope: "A/P")
let two = conversationRows([brief, question, first, tool, second], streaming: "", scope: "A/P")
check(interleaved.last!.id == two.last!.id && two[2].id != two.last!.id, "tool interleaving and multiple blocks stay distinct")
let stopped = entry("t-6", "client", "", "stopped")
let retry = conversationRows([brief, question, first, stopped], streaming: "Retry continuation", scope: "A/P")
let retryCommitted = conversationRows([brief, question, first, stopped, entry("t-7", "sophia", "Retry continuation")], streaming: "", scope: "A/P")
check(retry.last!.id == retryCommitted.last!.id && retry.last!.id != committed.last!.id, "Retry keeps question origin and advances past recorded partial block")
let next = conversationRows([brief, question, first, entry("t-8", "person", "Next question")], streaming: "First block", scope: "A/P")
check(next.last!.id != committed.last!.id, "new question does not alias same text from prior turn")
let otherThread = conversationRows([brief, question], streaming: "First block", scope: "A/Q")
let otherNotebook = conversationRows([brief, question], streaming: "First block", scope: "B/P")
check(otherThread.last!.id != before.last!.id && otherNotebook.last!.id != before.last!.id, "thread and notebook scopes do not alias")
let edited = conversationRows([brief, question, entry("t-9", "person", "Page edit", "edit_page")], streaming: "First block", scope: "A/P")
check(edited.last!.id == before.last!.id, "page edits do not become question origins")
check(Set(two.map(\.id)).count == two.count && two.compactMap(\.anchor) == ["t-1", "t-2", "t-3", "t-4", "t-5"], "all rows are unique and retain actual transcript anchors")


func update(_ id: String, _ tool: String = "note", page: String = "P", session: String = "s-1") -> JSONObject {
    var e = entry(id, "tool")
    e["tool"] = .string(tool); e["page"] = .string(page); e["session"] = .string(session)
    if tool == "note" { e["record"] = .string("n-" + id) }
    if tool == "memory" { e["added"] = .number(1); e["changed"] = .number(0); e["dropped"] = .number(0) }
    return e
}
var updateQuestion = question
updateQuestion["page"] = .string("P")
updateQuestion["session"] = .string("s-1")
let n1 = update("u-1"), n2 = update("u-2"), memory = update("u-3", "memory")
let grouped = conversationRows([updateQuestion, n1, n2, memory], streaming: "", scope: "A/P")
check(grouped.count == 2 && grouped.last!.entries == [n1, n2, memory], "adjacent successful note and memory events group without reordering")
check(grouped.last!.anchor == "u-1" && grouped.last!.anchors == ["u-1", "u-2", "u-3"], "every original group anchor remains available")
let growing = conversationRows([updateQuestion, n1, n2, memory, update("u-4")], streaming: "", scope: "A/P")
check(growing.last!.id == grouped.last!.id && growing.last!.anchors.count == 4, "appending a member keeps group identity and changes activity IDs")
let groupedStream = conversationRows([updateQuestion, n1, n2], streaming: "Answer", scope: "A/P")
let groupedMore = conversationRows([updateQuestion, n1, n2, memory], streaming: "Answer", scope: "A/P")
let groupedCommit = conversationRows([updateQuestion, n1, n2, memory, entry("u-5", "sophia", "Answer")], streaming: "", scope: "A/P")
check(groupedStream.last!.id == groupedMore.last!.id && groupedMore.last!.id == groupedCommit.last!.id, "group growth and stream-to-record preserve the reply reader")
check(conversationRows([updateQuestion, n1], streaming: "", scope: "A/P").last!.entries.count == 1, "a single update stays a normal entry")
check(conversationRows([n1, n2], streaming: "", scope: "A/P").allSatisfy { $0.entries.count == 1 }, "no person turn means no inferred group")
check(conversationRows([updateQuestion, n1, update("u-2", session: "s-2")], streaming: "", scope: "A/P").allSatisfy { $0.entries.count == 1 }, "sessions are a grouping boundary")
check(conversationRows([updateQuestion, n1, update("u-2", page: "Q")], streaming: "", scope: "A/P").allSatisfy { $0.entries.count == 1 }, "threads are a grouping boundary")
let important: [JSONObject] = [
    first, entry("b-person", "person", "Next turn"),
    entry("b-undo", "client", "", "undo_page"), entry("b-goal", "client", "", "goal_noted"),
    entry("b-checkpoint", "client", "", "checkpoint"),
    update("b-page", "write_page"), update("b-source", "WebFetch"), update("b-search", "WebSearch"),
    update("b-about", "about_you"), update("b-link", "link"), update("b-chapter", "set_chapter")
]
check(important.allSatisfy { boundary in
    conversationRows([updateQuestion, n1, boundary, n2], streaming: "", scope: "A/P").allSatisfy { $0.entries.count == 1 }
}, "prose, person turns, Undo, goals, checkpoint, page/source/library outcomes never collapse or bridge")
for flag in ["refused", "is_error", "error"] {
    var failure = n2; failure[flag] = flag == "error" ? .string("Denied") : .bool(true)
    check(!successfulNotebookUpdate(failure) && conversationRows([updateQuestion, n1, failure, memory], streaming: "", scope: "A/P").allSatisfy { $0.entries.count == 1 }, "explicit \(flag) remains outside groups and breaks adjacency")
}
var missing = n2; missing.removeValue(forKey: "record")
var incompleteMemory = memory; incompleteMemory.removeValue(forKey: "changed")
var noChange = memory; noChange["added"] = .number(0)
check([missing, incompleteMemory, noChange].allSatisfy { !successfulNotebookUpdate($0) }, "only explicit successful metadata qualifies")
let hidden = entry("hidden", "client", "", "replied")
check(conversationRows([updateQuestion, n1, hidden, n2], streaming: "", scope: "A/P").allSatisfy { $0.entries.count == 1 }, "even filtered records break raw adjacency")
check(grouped.flatMap(\.entries) == [updateQuestion, n1, n2, memory] && Set(grouped.map(\.id)).count == grouped.count, "raw records and unique presentation identities are preserved")
check(conversationRows([question, n1, n2], streaming: "", scope: "A/P").allSatisfy { $0.entries.count == 1 }, "a different thread’s person turn cannot authorize grouping")
print("All \(checkCount) focused presentation checks passed.")
