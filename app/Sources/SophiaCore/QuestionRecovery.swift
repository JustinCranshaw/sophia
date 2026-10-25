import Foundation

extension NotebookStore {
    /// The latest question without a completion or intentional-stop boundary in this conversation.
    /// Runtime pending state prevents the same saved entry from being queued twice.
    public func unansweredQuestion(in thread: String, pending: Bool = false) -> JSONObject? {
        guard !pending else { return nil }
        let entries = threadEntries(for: thread)
        guard let index = entries.lastIndex(where: Self.isPersonMessage),
              let text = entries[index].str("text"), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let later = entries[(index + 1)...]
        guard !later.contains(where: { ["replied", "stopped", "clear"].contains($0.str("purpose") ?? "") }) else { return nil }
        // Older clients did not record completion. An old reply or tool result is ambiguous;
        // page-stamped output proves a newer retry attempt, whose completion is recorded.
        let output = later.filter { Self.isMessage($0) || $0.str("role") == "tool" }
        if entries[index]["page"] == nil && !output.isEmpty && !output.contains(where: { $0.str("page") != nil }) { return nil }
        return entries[index]
    }

    public func hasPartialReply(to question: JSONObject) -> Bool {
        let entries = threadEntries(for: Self.thread(of: question))
        guard let index = entries.firstIndex(where: { $0["id"] == question["id"] }) else { return false }
        return entries[(index + 1)...].contains { $0.str("role") == "sophia" && Self.isMessage($0) }
    }
}
