import Foundation

/// The folder that holds notebooks. Each notebook is a directory with a notebook.json.
public struct Library {
    public let root: URL

    public init(root: URL? = nil) {
        if let r = root {
            self.root = r
        } else if let env = ProcessInfo.processInfo.environment["SOPHIA_LIBRARY"] {
            self.root = URL(fileURLWithPath: env)
        } else {
            self.root = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Documents").appendingPathComponent("Sophia")
        }
        try? FileManager.default.createDirectory(at: self.root, withIntermediateDirectories: true)
    }

    public var notebooks: [URL] {
        let items = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        return items.filter { FileManager.default.fileExists(atPath: $0.appendingPathComponent("notebook.json").path) }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    }

    public func create(named name: String) throws -> URL {
        let clean = name.replacingOccurrences(of: "/", with: "-").trimmingCharacters(in: .whitespaces)
        let url = root.appendingPathComponent(clean.isEmpty ? "Untitled" : clean)
        _ = try NotebookStore(url: url)
        return url
    }
}
