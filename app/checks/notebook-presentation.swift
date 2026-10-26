import Foundation
import SophiaCore

@main struct NotebookPresentationChecks {
    static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true).appendingPathComponent(UUID().uuidString)
        let store = try NotebookStore(url: root.appendingPathComponent("Ordinary"))
        func require(_ condition: Bool, _ message: String) { precondition(condition, message) }
        for (author, status, text) in [("person", "working", "Confirmed aim"), ("sophia", "working", "Unconfirmed suggestion"), ("person", "met", "Earlier aim"), ("unknown", "working", "Unattributed import")] {
            _ = try store.appendLearning(["kind": .string("goal"), "status": .string(status), "text": .string(text)], by: author, session: "controlled-check")
        }
        require(NotebookPresentation.confirmedGoals(store).map { $0.str("text")! } == ["Confirmed aim"], "Only explicit person-confirmed working goals belong in the home purpose")
        _ = try store.appendTranscript(["role": .string("person"), "page": .string(""), "text": .string("hi")])
        _ = try store.appendTranscript(["role": .string("person"), "page": .string("another-page.md"), "text": .string("This page-only question must not become the notebook introduction.")])
        require(NotebookPresentation.earlyInquiry(store) == nil, "Weak greetings/page questions do not become the notebook's opening inquiry")
        let inquiry = "What changes when a circle is viewed from an angle?"
        _ = try store.appendTranscript(["role": .string("person"), "page": .string(""), "text": .string(inquiry)])
        require(NotebookPresentation.earlyInquiry(store) == inquiry, "Historical inquiry preserves actual words")
        require(NotebookPresentation.almanacEntries(store).isEmpty, "Ordinary notebooks never get publication dates")

        let almanac = try NotebookStore(url: root.appendingPathComponent("Almanac"))
        try almanac.configureAlmanac(.init(enabled: true, topics: "Developer-only example"))
        func save(_ title: String) throws -> AlmanacEntry {
            let draft = try AlmanacDraft.parse(JSON.object(["title": .string(title), "body": .string("DEVELOPER-SUPPLIED check, not model output."), "basis": .string("general_knowledge"), "needsOpenedSource": .bool(false)]).line)
            return try almanac.saveAlmanac(draft, evidence: [], run: almanac.reserveAlmanac(manual: true, acknowledged: true)!, session: "controlled-check")
        }
        let first = try save("A recorded entry")
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1)], ofItemAtPath: almanac.pagesURL.appendingPathComponent(first.file).path)
        require(NotebookPresentation.almanacEntries(almanac)[first.file]?.preparedAt == first.preparedAt, "Publication uses the recorded entry, never file modification time")
        let ordinary = try almanac.writePage(title: "A person-directed ordinary page", content: "Not an Almanac preparation.", revising: nil, session: "controlled-check", toolUseID: "ordinary")
        require(NotebookPresentation.almanacEntries(almanac)[ordinary.str("file")!] == nil, "Ordinary pages inside an Almanac remain ordinary")
        let second = try save("An undone entry")
        try almanac.undoPageWrite(second.writeID, session: "controlled-check")
        require(NotebookPresentation.almanacEntries(almanac)[second.file] == nil, "Undone entries do not retain publication presentation")
        let validCount = NotebookPresentation.almanacEntries(almanac).count
        for flag in ["refused", "recovered"] {
            _ = try almanac.appendTranscript(["tool": .string("write_page"), "tool_use": .string("almanac:ignored-" + flag), "file": .string(ordinary.str("file")!), flag: .bool(true)])
        }
        require(NotebookPresentation.almanacEntries(almanac).count == validCount, "Refused and unknown-provenance records cannot add publication dates")
        let pageURL = almanac.pagesURL.appendingPathComponent(first.file)
        let pageBytes = try Data(contentsOf: pageURL)
        try FileManager.default.removeItem(at: pageURL)
        require(NotebookPresentation.almanacEntries(almanac)[first.file] == nil, "Missing pages have no publication label")
        let outside = root.appendingPathComponent("owned-symlink-canary.md")
        try Data("DEVELOPER-OWNED outside-page canary".utf8).write(to: outside)
        try FileManager.default.createSymbolicLink(at: pageURL, withDestinationURL: outside)
        require(almanac.readPage(first.file) != nil, "Control: writable-store lookup follows this owned symlink")
        require(Almanac.entry(id: first.id, url: almanac.url) == nil, "Core rejects a replaced page symlink")
        require(NotebookPresentation.almanacEntries(almanac)[first.file] == nil, "Presentation preserves Core's symlink refusal")
        try FileManager.default.removeItem(at: pageURL)
        try pageBytes.write(to: pageURL)
        require(NotebookPresentation.almanacEntries(almanac)[first.file]?.preparedAt == first.preparedAt, "Restored valid page retains its recorded date")
        let transcript = almanac.url.appendingPathComponent("transcript.jsonl")
        let records = try String(contentsOf: transcript, encoding: .utf8).split(separator: "\n").map { line -> JSONObject in
            var value = JSON.parse(String(line))!.object!
            if value.str("id") == first.writeID { value.removeValue(forKey: "at") }
            return value
        }
        try records.map { JSON.object($0).line + "\n" }.joined().write(to: transcript, atomically: true, encoding: .utf8)
        almanac.reload()
        require(NotebookPresentation.publicationDate(NotebookPresentation.almanacEntries(almanac)[first.file]!) == "Undated", "Missing recorded date never falls back to mtime or today")
        print("Notebook presentation checks passed: explicit goals, historical inquiry, recorded dates, ordinary pages and Undo. No provider or UI invoked.")
    }
}
