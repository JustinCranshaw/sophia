import Foundation
import SophiaCore

/// Read-only presentation of recorded facts; never derives a learner profile or publication date.
enum NotebookPresentation {
    static func confirmedGoals(_ store: NotebookStore) -> [JSONObject] {
        store.goals.filter { $0.str("by") == "person" && $0.str("status") == "working" }
    }
    static func earlyInquiry(_ store: NotebookStore) -> String? {
        store.transcript.first { entry in
            guard NotebookStore.isPersonMessage(entry), NotebookStore.thread(of: entry).isEmpty,
                  let text = entry.str("text")?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
            return text.count >= 24 && text.split(whereSeparator: \.isWhitespace).count >= 5
        }?.str("text")
    }
    static func almanacEntries(_ store: NotebookStore) -> [String: AlmanacEntry] {
        guard Almanac.isConfigured(url: store.url) else { return [:] }
        var entries: [String: AlmanacEntry] = [:]
        for action in store.transcript.reversed() {
            guard let tag = action.str("tool_use"), tag.hasPrefix("almanac:"),
                  let file = action.str("file"), entries[file] == nil,
                  let entry = Almanac.entry(id: String(tag.dropFirst("almanac:".count)), url: store.url) else { continue }
            entries[file] = entry
        }
        return entries
    }
    static func date(_ entry: AlmanacEntry) -> Date? {
        ISO8601DateFormatter().date(from: entry.preparedAt)
    }
    static func publicationDate(_ entry: AlmanacEntry, abbreviated: Bool = false) -> String {
        guard let date = date(entry) else { return "Undated" }
        return abbreviated ? date.formatted(.dateTime.month(.abbreviated).day()) : date.formatted(.dateTime.month(.wide).day().year())
    }
}
