import SophiaCore

/// Presentation only: preserve streaming readers and every raw record in grouped updates.
struct ConversationRow: Identifiable {
    enum ID: Hashable {
        case record(scope: String, id: String)
        case reply(scope: String, origin: String?, block: Int)
    }
    let id: ID
    let anchor: String?
    var entries: [JSONObject]
    var entry: JSONObject { entries[0] }
    var anchors: [String] { entries.compactMap { $0.str("id") } }

    init(id: ID, anchor: String?, entry: JSONObject) {
        self.id = id; self.anchor = anchor; self.entries = [entry]
    }
}

func conversationRows(_ entries: [JSONObject], streaming: String, scope: String, thread: String? = nil) -> [ConversationRow] {
    var rows: [ConversationRow] = []
    var origin: String?
    var originThread: String?
    var block = 0
    var previousWasUpdate = false
    for entry in entries {
        let mayExtend = previousWasUpdate
        // Even a hidden record is a boundary; never group across a checkpoint or action.
        previousWasUpdate = false
        if let thread, NotebookStore.thread(of: entry) != thread { continue }
        if entry["recovered"] == .bool(true) || entry["migrationSource"] != nil { continue }
        guard let id = entry.str("id") else { continue }
        let role = entry.str("role") ?? ""
        if NotebookStore.isPersonMessage(entry) { origin = id; originThread = NotebookStore.thread(of: entry); block = 0 }
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
        let eligible = origin != nil && originThread == NotebookStore.thread(of: entry) && successfulNotebookUpdate(entry)
        if eligible, mayExtend, let previous = rows.last,
           previous.entry.str("session") == entry.str("session"),
           NotebookStore.thread(of: previous.entry) == NotebookStore.thread(of: entry) {
            rows[rows.count - 1].entries.append(entry)
        } else {
            rows.append(ConversationRow(id: identity, anchor: id, entry: entry))
        }
        previousWasUpdate = eligible
    }
    if !streaming.isEmpty {
        rows.append(ConversationRow(id: .reply(scope: scope, origin: origin, block: block), anchor: nil,
                                    entry: ["role": .string("sophia"), "text": .string(streaming)]))
    }
    return rows
}

/// Only emitted success shapes qualify; a refusal/error or incomplete legacy entry stays visible.
func failedNotebookUpdate(_ entry: JSONObject) -> Bool {
    entry["refused"] == .bool(true) || entry["is_error"] == .bool(true)
        || (entry["error"] != nil && entry["error"] != .null && entry["error"] != .bool(false))
}

func successfulNotebookUpdate(_ entry: JSONObject) -> Bool {
    guard entry.str("role") == "tool", entry["purpose"] == nil, !failedNotebookUpdate(entry),
          let session = entry.str("session"), !session.isEmpty else { return false }
    if entry.str("tool") == "note" { return entry.str("record").map { !$0.isEmpty } ?? false }
    guard entry.str("tool") == "memory" else { return false }
    var changed = false
    for key in ["added", "changed", "dropped"] {
        guard case .number(let count)? = entry[key], count >= 0, count.rounded() == count else { return false }
        changed = changed || count > 0
    }
    return changed
}
