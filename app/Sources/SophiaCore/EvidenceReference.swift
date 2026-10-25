import Foundation

/// Read-only presentation of existing local evidence; never opens a store.
public struct EvidenceReference: Equatable {
    public enum Kind: String { case page, exchange, goal, note, unavailable }
    public let reference: String
    public let kind: Kind
    public let label: String
    public let heading: String
    public let text: String
    public let date: String?
    public let quote: String?
    public let correction: String?
    public let page: String?

    public static func resolve(_ ref: String, in store: NotebookStore) -> Self {
        func result(_ kind: Kind, _ label: String, _ heading: String, _ text: String, date: String? = nil, quote: String? = nil, correction: String? = nil, page: String? = nil) -> Self {
            Self(reference: ref, kind: kind, label: label, heading: heading, text: text, date: date, quote: quote, correction: correction, page: page)
        }
        func unavailable() -> Self { result(.unavailable, "Unavailable evidence", "Evidence unavailable", "This supporting item is missing, deleted, or no longer identifiable in this notebook.") }
        func excerpt(_ text: String) -> String { String(text.split(whereSeparator: \.isWhitespace).joined(separator: " ").prefix(80)) }
        if ref.hasPrefix("p:") {
            let file = String(ref.dropFirst(2))
            guard store.pageFiles.contains(file), let page = store.readPage(file) else { return unavailable() }
            return result(.page, page.title, "Notebook page · current version", page.body, page: file)
        }
        if ref.hasPrefix("t-") {
            let entries = store.transcript.filter { $0.str("id") == ref }
            guard entries.count == 1, let entry = entries.first, let text = entry.str("text"), !text.isEmpty else { return unavailable() }
            let author = entry.str("role") == "person" ? "Your words" : entry.str("role") == "sophia" ? "Sophia's reply" : "Recorded exchange"
            return result(.exchange, author + ": " + excerpt(text), author, text, date: entry.str("at"))
        }
        let parts = ref.split(separator: "#", omittingEmptySubsequences: false)
        guard parts.count <= 2, let base = parts.first.map(String.init) else { return unavailable() }
        let records = store.learning.filter { $0.str("id") == base }
        guard records.count == 1, let record = records.first else { return unavailable() }
        if record.str("kind") == "goal" {
            let goals = store.goals.filter { store.rootID(of: $0.str("id") ?? "") == store.rootID(of: base) }
            guard goals.count == 1, let goal = goals.first, let title = goal.str("text") else { return unavailable() }
            let criteria = goal["criteria"]?.array ?? []
            if parts.count == 2 {
                guard let position = Int(parts[1]), position > 0, position <= criteria.count, let criterion = criteria[position - 1].string else { return unavailable() }
                return result(.goal, criterion, "Goal criterion · " + title, criterion, date: goal.str("at"))
            }
            return result(.goal, title, "Goal · " + (store.isProvisional(goal) ? "provisional" : goal.str("status") ?? "working"), ([title] + criteria.enumerated().map { "\($0.offset + 1). \($0.element.string ?? "Unavailable criterion")" }).joined(separator: "\n"), date: goal.str("at"))
        }
        guard parts.count == 1, let text = record.str("text") else { return unavailable() }
        let heading = record.str("by") == "person" ? "Your record" : record.str("kind") == "memory" ? "Sophia's working memory" : "Sophia's interpretation"
        return result(.note, heading + ": " + excerpt(store.correction(of: base)?.str("text") ?? text), heading, text, date: record.str("at"), quote: record["quote"]?["text"]?.string, correction: store.correction(of: base)?.str("text"))
    }
}
