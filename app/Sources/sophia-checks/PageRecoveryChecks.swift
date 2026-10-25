import Foundation
import SophiaCore

func pageRecoveryRetainsExactRepeatedEditsAndDismissesOnlyOne() throws {
    var recovery = PageEditRecovery()
    let store = try tempStore()
    let page = try store.writePage(title: "Section labels", content: "## First section\nOne.\n\n## Second section\nTwo.", revising: nil, session: "s-1", toolUseID: "section-label-check")
    let file = page.str("file")!
    guard let range = store.editRanges(of: file).first(where: { $0.index == 1 }) else { expect(false); return }
    expect(range.key == "§1" && range.label == "§2" && range.section == "Second section")
    let sectionLabel = "\(range.label) · \(range.section)"
    let first = "\n cafe\u{301} ∑\n\n", second = "\n café ∑\n\n"
    recovery.keep(file: "same.md", title: "Original page", section: "(page)", text: first)
    let firstID = recovery.edits[0].id
    recovery.keep(file: "same.md", title: "Original page", section: sectionLabel, text: second)
    expect(recovery.edits.count == 2)
    expect(recovery.edits[0].text.utf8.elementsEqual(first.utf8))
    expect(recovery.edits[1].text.utf8.elementsEqual(second.utf8))
    expect(!first.utf8.elementsEqual(second.utf8))
    let secondID = recovery.edits[1].id
    recovery.dismiss(firstID)
    expect(recovery.edits.count == 1 && recovery.edits[0].id == secondID)
    expect(recovery.edits[0].text.utf8.elementsEqual(second.utf8))
    expect(recovery.edits[0].title == "Original page" && recovery.edits[0].section == "§2 · Second section")
    recovery.dismiss(firstID) // A stale dismissal cannot clear the next item.
    expect(recovery.edits.count == 1)
    recovery.dismiss(secondID)
    expect(recovery.edits.isEmpty)
}
