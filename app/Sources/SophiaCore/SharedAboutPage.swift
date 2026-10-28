import Foundation

extension LibraryStore {
    public enum SharedAboutError: Error, LocalizedError {
        case legacyReadOnly, invalidLegacy
        public var errorDescription: String? {
            switch self {
            case .legacyReadOnly: return "About you is a Markdown page now; the original records are historical."
            case .invalidLegacy: return "The original About you records could not be read completely. They were preserved; no migration was accepted."
            }
        }
    }
    var hasSharedAboutMigration: Bool {
        FileManager.default.fileExists(atPath: dir.appendingPathComponent("about/legacy-about.json").path)
    }

    /// A real NotebookStore supplies the same Page, source editor, locking and Undo as notebook pages.
    /// Its hidden location keeps it out of ordinary notebook enumeration and tool write paths.
    public func ensureSharedAboutPage(session: String) throws -> (store: NotebookStore, page: NotebookStore.Page) {
        try locked {
            let location = dir.appendingPathComponent("about")
            let store = try NotebookStore(url: location)
            return try store.locked {
                let snapshotURL = location.appendingPathComponent("legacy-about.json")
                let snapshot: [JSONObject]
                if FileManager.default.fileExists(atPath: snapshotURL.path) {
                    guard let data = try? Data(contentsOf: snapshotURL),
                          let saved = try? JSONDecoder().decode(JSON.self, from: data), let records = saved.array, records.allSatisfy({ $0.object != nil }) else {
                        throw NotebookStore.StoreError.notFound
                    }
                    snapshot = records.compactMap(\.object)
                } else {
                    // A permissive legacy read must not turn a transient failure into an
                    // authoritative empty snapshot. Refuse cutover until every line is readable.
                    if FileManager.default.fileExists(atPath: aboutURL.path) {
                        let data = try Data(contentsOf: aboutURL)
                        guard let text = String(data: data, encoding: .utf8) else { throw SharedAboutError.invalidLegacy }
                        snapshot = try text.split(separator: "\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.map { line in
                            guard let record = JSON.parse(String(line))?.object else { throw SharedAboutError.invalidLegacy }
                            return record
                        }
                    } else { snapshot = [] }
                    try Data(JSON.array(snapshot.map { .object($0) }).line.utf8).write(to: snapshotURL, options: .atomic)
                }
                let current = Self.current(snapshot)
                let file = "about-you.md"
                let accepted = current.filter { $0.str("by") == "person" }.compactMap { $0.str("text") }
                let originalBody = accepted.map { "- " + $0 }.joined(separator: "\n")
                let originalText = "---\ntitle: \"About you\"\n---\n" + originalBody + "\n"
                let canonical = store.pagesURL.appendingPathComponent(file)
                if !FileManager.default.fileExists(atPath: canonical.path) {
                    guard !store.transcript.contains(where: { $0.str("file") == file }),
                          !store.hasPreviousVersion(file) else { throw NotebookStore.StoreError.notFound }
                    try Data(originalText.utf8).write(to: canonical, options: .atomic)
                    try store.appendTranscript(["role": .string("client"), "purpose": .string("initialize_page"),
                        "file": .string(file), "page": .string(file), "session": .string(session),
                        "hash": .string(store.pageHash(file)!)])
                }
                store.recoverOrphanPages()
                try store.setPageProperties(file: file, role: .about, scope: .library)
                for record in current where Self.isProvisional(record) {
                    guard let id = record.str("id"), let origin = record.str("notebook"), let text = record.str("text") else { continue }
                    guard !store.pageProposalHistory.contains(where: { $0.str("legacyID") == id }) else { continue }
                    let body = originalBody
                    _ = try store.proposePageChange(file: file, content: body + (body.isEmpty ? "" : "\n") + "- " + text,
                        originNotebook: origin, evidence: record, session: session, legacyID: id, baseHash: NotebookStore.hash(originalText))
                }
                return (store, store.page(file)!)
            }
        }
    }

    /// Sophia's only write path for shared About content. Acceptance belongs to the person.
    public func proposeAboutPage(content: String, quote: String, from notebook: NotebookStore, session: String) throws -> JSONObject {
        notebook.reload()
        let q = quote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let message = notebook.transcript.last(where: { NotebookStore.isPersonMessage($0) &&
                  RecordChecks.normalize($0.str("text") ?? "").contains(RecordChecks.normalize(q))
              }), let id = message.str("id") else { throw NotebookStore.PageProposalError.invalidEvidence }
        let shared = try ensureSharedAboutPage(session: session)
        return try shared.store.proposePageChange(file: shared.page.file, content: content,
            originNotebook: notebook.name, evidence: ["entry": .string(id), "quote": .string(q), "notebook": .string(notebook.name)], session: session)
    }
}
