import Foundation

/// Only the currently open notebook session owns this value; it is not a draft store.
public struct PageEditRecovery {
    public struct Edit: Identifiable {
        public let id = UUID()
        public let file: String
        public let title: String
        public let section: String
        public let text: String
    }
    public private(set) var edits: [Edit] = []
    public init() {}
    public mutating func keep(file: String, title: String, section: String, text: String) {
        edits.append(Edit(file: file, title: title, section: section, text: text))
    }
    public mutating func dismiss(_ id: UUID) { edits.removeAll { $0.id == id } }
}
