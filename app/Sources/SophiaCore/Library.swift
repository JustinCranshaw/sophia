import Foundation

/// The folder that holds notebooks. Each notebook is a directory with a notebook.json.
public struct Library {
    public let root: URL

    public init(root: URL? = nil) {
        let location: URL
        if let r = root {
            location = r
        } else if let env = ProcessInfo.processInfo.environment["SOPHIA_LIBRARY"] {
            location = URL(fileURLWithPath: env)
        } else {
            location = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Documents").appendingPathComponent("Sophia")
        }
        try? FileManager.default.createDirectory(at: location, withIntermediateDirectories: true)
        // Keep directory URLs consistent across creation, enumeration, and following links.
        self.root = URL(fileURLWithPath: location.path, isDirectory: true).resolvingSymlinksInPath()
    }

    public var notebooks: [URL] {
        let items = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        return items.filter { FileManager.default.fileExists(atPath: $0.appendingPathComponent("notebook.json").path) }
            .map { root.appendingPathComponent($0.lastPathComponent, isDirectory: true) }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    }

    public func create(named name: String) throws -> URL {
        let clean = name.replacingOccurrences(of: "/", with: "-").trimmingCharacters(in: .whitespaces)
        let url = root.appendingPathComponent(clean.isEmpty ? "Untitled" : clean, isDirectory: true)
        guard clean != ".", clean != "..", !clean.hasPrefix("."), !FileManager.default.fileExists(atPath: url.path) else { throw CocoaError(.fileWriteFileExists) }
        _ = try NotebookStore(url: url)
        return url
    }
}
