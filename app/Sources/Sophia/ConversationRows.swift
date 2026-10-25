import SophiaCore

/// Presentation identity only: a streamed text block keeps its reader when it is recorded.
struct ConversationRow: Identifiable {
    enum ID: Hashable {
        case record(scope: String, id: String)
        case reply(scope: String, origin: String?, block: Int)
    }
    let id: ID
    let anchor: String?
    let entry: JSONObject
}

func conversationRows(_ entries: [JSONObject], streaming: String, scope: String) -> [ConversationRow] {
    var rows: [ConversationRow] = []
    var origin: String?
    var block = 0
    for entry in entries {
        if entry["recovered"] == .bool(true) { continue }
        guard let id = entry.str("id") else { continue }
        let role = entry.str("role") ?? ""
        if NotebookStore.isPersonMessage(entry) { origin = id; block = 0 }
        if role == "client", entry["decision"] == nil,
           !["stopped", "undo_page", "goal_noted", "filed_draft"].contains(entry.str("purpose") ?? "") { continue }
        if role == "person", entry.str("purpose") == "release_edit" { continue }
        let identity: ConversationRow.ID
        if role == "sophia" {
            identity = .reply(scope: scope, origin: origin, block: block)
            block += 1
        } else {
            identity = .record(scope: scope, id: id)
        }
        rows.append(ConversationRow(id: identity, anchor: id, entry: entry))
    }
    if !streaming.isEmpty {
        rows.append(ConversationRow(id: .reply(scope: scope, origin: origin, block: block), anchor: nil,
                                    entry: ["role": .string("sophia"), "text": .string(streaming)]))
    }
    return rows
}
