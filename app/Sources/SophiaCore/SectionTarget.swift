import Foundation

/// A transient navigation request, never a page edit or a persisted evidence reference.
public struct SectionTarget: Equatable {
    public enum Selector: Equatable {
        case title(String)
        case range(key: String, heading: String, hash: String)
    }
    public let notebook: URL
    public let file: String
    public let selector: Selector
    public init(notebook: URL, file: String, selector: Selector) {
        self.notebook = notebook; self.file = file; self.selector = selector
    }
    public static func exact(notebook: URL, file: String, range: NotebookStore.EditRange) -> Self {
        Self(notebook: notebook, file: file, selector: .range(key: range.key, heading: range.section, hash: range.hash))
    }
    /// Resolve against the same visible ranges used by the reader and source editor.
    /// Legacy title links must identify exactly one section; duplicate titles require a choice.
    public func resolve(in store: NotebookStore) -> Result<Int, NavigationError> {
        guard notebook.standardizedFileURL == store.url.standardizedFileURL,
              store.pageFiles.contains(file), store.readPage(file) != nil else {
            return .failure(.unavailable)
        }
        let ranges = store.editRanges(of: file).filter { $0.index != nil }
        let matches: [NotebookStore.EditRange]
        switch selector {
        case .title(let title):
            func clean(_ text: String) -> String { text.lowercased().filter { $0.isLetter || $0.isNumber } }
            matches = ranges.filter { clean($0.section) == clean(title) }
        case .range(let key, let heading, let hash):
            matches = ranges.filter { $0.key == key && $0.section == heading && $0.hash == hash }
        }
        guard matches.count == 1, let index = matches.first?.index else {
            return .failure(matches.count > 1 ? .ambiguous : .changed)
        }
        return .success(index)
    }
    public enum NavigationError: Error, Equatable, LocalizedError {
        case unavailable, ambiguous, changed
        public var errorDescription: String? {
            switch self {
            case .unavailable: return "This page is no longer available."
            case .ambiguous: return "More than one section has this title. Open the page and choose a section."
            case .changed: return "This section has changed or is no longer available. Open the evidence again to choose a current section."
            }
        }
    }
}
