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
    struct Publication { let preparedAt: String }
    static func almanacEntries(_ store: NotebookStore) -> [String: Publication] {
        guard Almanac.isConfigured(url: store.url) else { return [:] }
        // Project the loaded transcript once; notification-target lookup rereads it for each run.
        let undone = Set(store.transcript.filter { $0.str("purpose") == "undo_page" }.compactMap { $0.str("entry") })
        let listed = Set(store.pageFiles)
        var seenRuns = Set<String>(), entries: [String: Publication] = [:]
        for action in store.transcript.reversed() {
            guard action.str("tool") == "write_page", action["refused"] != .bool(true), action["recovered"] != .bool(true),
                  let tag = action.str("tool_use"), tag.hasPrefix("almanac:"), seenRuns.insert(tag).inserted,
                  let write = action.str("id"), !undone.contains(write),
                  let file = action.str("file"), listed.contains(file), entries[file] == nil,
                  store.readPage(file) != nil else { continue }
            entries[file] = Publication(preparedAt: action.str("at") ?? "")
        }
        return entries
    }
    static func date(_ entry: Publication) -> Date? {
        ISO8601DateFormatter().date(from: entry.preparedAt)
    }
    static func publicationDate(_ entry: Publication, abbreviated: Bool = false) -> String {
        guard let date = date(entry) else { return "Undated" }
        return abbreviated ? date.formatted(.dateTime.month(.abbreviated).day()) : date.formatted(.dateTime.month(.wide).day().year())
    }
}
