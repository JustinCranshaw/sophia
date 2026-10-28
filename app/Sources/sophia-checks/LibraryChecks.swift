import Foundation
import SophiaCore

func createdAndEnumeratedNotebooksHaveTheSameURL() throws {
    let files = FileManager.default
    let temporary = files.temporaryDirectory.appendingPathComponent("sophia-library-\(UUID().uuidString)", isDirectory: true)
    try files.createDirectory(at: temporary, withIntermediateDirectories: true)
    defer { try? files.removeItem(at: temporary) }
    let actual = temporary.appendingPathComponent("actual", isDirectory: true)
    try files.createDirectory(at: actual, withIntermediateDirectories: true)
    let alias = temporary.appendingPathComponent("alias", isDirectory: true)
    try files.createSymbolicLink(at: alias, withDestinationURL: actual)
    // Pass a file-style URL through a symlink, before the new notebook exists.
    let library = Library(root: URL(fileURLWithPath: alias.path))
    expect(library.notebooks.isEmpty)
    let created = try library.create(named: "New inquiry")
    guard let enumerated = library.notebooks.first else { expect(false); return }
    expect(created == enumerated)
    expect(created.hasDirectoryPath)
    expect(try NotebookStore(url: created).url == enumerated)
    // AppModel.follow builds its URL this way; selecting/reopening uses enumeration.
    expect(library.root.appendingPathComponent("New inquiry") == enumerated)
    expectThrows { try library.create(named: "New inquiry") } // creation never silently reopens a colliding notebook
    expect(Library(root: alias).notebooks == [created])
}
