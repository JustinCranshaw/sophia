import Foundation
import SophiaCore
func entry(_ id: String, _ role: String, _ text: String = "", _ purpose: String? = nil) -> JSONObject {
    var e: JSONObject = ["id": .string(id), "role": .string(role), "text": .string(text)]
    if let purpose { e["purpose"] = .string(purpose) }
    return e
}
func check(_ value: @autoclosure () -> Bool, _ name: String) {
    precondition(value(), name); print("ok " + name)
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
print("All 9 focused presentation identity checks passed.")
