import Foundation
import SophiaCore

func sectionTargetsUseVisibleRangesAndDistinctDuplicateHeadings() throws {
    let store = try tempStore()
    let body = "# Practice\n\n## Rhythm\n\n## Pulse\nFirst exercise.\n\n```text\n## Not a heading\n```\n\n## Pulse\nSecond exercise.\n\n### Slower\nKeep the beat."
    let page = try store.writePage(title: "Practice", content: body, revising: nil, session: "navigation", toolUseID: "create").str("file")!
    _ = try store.fileInChapter([page], chapter: "Rhythm")
    let ranges = store.editRanges(of: page).filter { $0.index != nil }
    expect(ranges.map(\.section) == ["Pulse", "Pulse", "Slower"])
    let before = try Data(contentsOf: store.pagesURL.appendingPathComponent(page))
    for (index, range) in ranges.enumerated() {
        expect(try SectionTarget.exact(notebook: store.url, file: page, range: range).resolve(in: store).get() == index)
    }
    expect(SectionTarget(notebook: store.url, file: page, selector: .title("Pulse")).resolve(in: store) == .failure(.ambiguous))
    expect(try SectionTarget(notebook: store.url, file: page, selector: .title("slower")).resolve(in: store).get() == 2)
    expect(try Data(contentsOf: store.pagesURL.appendingPathComponent(page)) == before)
    expect(store.transcript.count == 1)
}

func staleSectionTargetsCannotMoveToRenamedDeletedOrDifferentNotebookContent() throws {
    let store = try tempStore()
    let file = try store.writePage(title: "Math", content: "# Math\n\n## Trace\nOriginal.\n\n## Determinant\nProduct.", revising: nil, session: "navigation", toolUseID: "create").str("file")!
    let target = SectionTarget.exact(notebook: store.url, file: file, range: store.editRanges(of: file).first { $0.index == 0 }!)
    _ = try store.writePage(title: "Math", content: "# Math\n\n## Trace\nChanged.\n\n## Determinant\nProduct.", revising: file, session: "navigation", toolUseID: "revise")
    expect(target.resolve(in: store) == .failure(.changed))
    _ = try store.writePage(title: "Math", content: "# Math\n\n## Renamed\nOriginal.", revising: file, session: "navigation", toolUseID: "rename")
    expect(target.resolve(in: store) == .failure(.changed))
    expect(target.resolve(in: try tempStore()) == .failure(.unavailable))
    try FileManager.default.removeItem(at: store.pagesURL.appendingPathComponent(file))
    expect(target.resolve(in: store) == .failure(.unavailable))
}
