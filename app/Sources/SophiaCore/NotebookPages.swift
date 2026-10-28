import Foundation

extension NotebookStore {
    public enum NotebookPageError: Error, LocalizedError {
        case invalidEvidence, invalidRole, reservedPage, quota, migrationDamaged
        public var errorDescription: String? {
            switch self {
            case .invalidEvidence: return "The change needs an exact quote from the person or references to existing evidence."
            case .invalidRole: return "This write path is only for Sophia’s notes or working memory."
            case .reservedPage: return "Use set_goal, note, set_memory or about_you for this page’s checked write path."
            case .quota: return "The note update limit for this conversation has been reached. Continue in the conversation without another notes update."
            case .migrationDamaged: return "The saved page migration cannot be read safely. Existing pages and evidence were preserved."
            }
        }
    }
    private var notebookPagesMigrationURL: URL { url.appendingPathComponent("notebook-pages-migration.json") }
    private static let learningPageRoles: [PageRole] = [.goals, .notes, .memory]

    public func notebookPage(role: PageRole) -> Page? { pages.first { $0.role == role && $0.scope == .notebook } }

    /// One-time import. The immutable snapshot retains legacy identities, quotes and replacement chains.
    /// Afterwards Markdown is authoritative; learning records are never projected over a person's edits.
    @discardableResult
    public func ensureNotebookPages(session: String) throws -> [Page] {
        try locked {
            let snapshot: JSONObject
            if FileManager.default.fileExists(atPath: notebookPagesMigrationURL.path) {
                guard let data = try? Data(contentsOf: notebookPagesMigrationURL),
                      let value = try? JSONDecoder().decode(JSON.self, from: data), let obj = value.object,
                      obj["pages"]?.object != nil, let records = obj["learning"]?.array, records.allSatisfy({ $0.object != nil }) else { throw NotebookPageError.migrationDamaged }
                snapshot = obj
            } else {
                // A lenient log projection must not become an irreversible partial migration.
                let records: [JSONObject]
                if FileManager.default.fileExists(atPath: learningURL.path) {
                    guard let data = try? Data(contentsOf: learningURL), let text = String(data: data, encoding: .utf8) else { throw NotebookPageError.migrationDamaged }
                    records = try text.split(separator: "\n").map { line in
                        guard let record = JSON.parse(String(line))?.object else { throw NotebookPageError.migrationDamaged }
                        return record
                    }
                } else { records = [] }
                try checkLearningIdentities(records)
                var files: JSONObject = [:]
                for role in Self.learningPageRoles {
                    files[role.rawValue] = .string(notebookPage(role: role)?.file ?? uniqueFile(for: Self.learningPageTitle(role)))
                }
                snapshot = ["pages": .object(files), "learning": .array(records.map { .object($0) })]
                try Data(snapshot.line.utf8).write(to: notebookPagesMigrationURL, options: .atomic)
            }
            let records = snapshot["learning"]!.array!.compactMap(\.object)
            let replaced = Set(records.filter { $0.str("kind") != "correction" }.compactMap { $0.str("replaces") })
            let current = records.filter { !replaced.contains($0.str("id") ?? "") && $0["retired"] != .bool(true) }
            let activeGoals = current.filter { $0.str("kind") == "goal" }
            func acceptedAncestor(_ goal: JSONObject) -> JSONObject? {
                var candidate = goal, visited = Set<String>()
                while true {
                    if candidate.str("by") == "person" { return candidate }
                    guard let id = candidate.str("id"), visited.insert(id).inserted,
                          let replaces = candidate.str("replaces"), let prior = records.first(where: { $0.str("id") == replaces }) else { return nil }
                    candidate = prior
                }
            }
            let confirmed = activeGoals.compactMap(acceptedAncestor)
            let initialGoals = confirmed.map(Self.legacyGoalProse).joined(separator: "\n\n")
            for role in Self.learningPageRoles {
                guard let file = snapshot["pages"]?[role.rawValue]?.string, file == URL(fileURLWithPath: file).lastPathComponent, file.hasSuffix(".md"), !file.hasSuffix(".previous.md") else { throw NotebookPageError.migrationDamaged }
                let destination = pagesURL.appendingPathComponent(file)
                if !FileManager.default.fileExists(atPath: destination.path) {
                    guard !transcript.contains(where: { $0.str("file") == file }), !hasPreviousVersion(file) else { throw NotebookPageError.migrationDamaged }
                    let body: String
                    if role == .goals { body = initialGoals }
                    else {
                        let items = current.filter { role == .memory ? $0.str("kind") == "memory" : Self.noteKinds.contains($0.str("kind") ?? "") }
                        body = items.map { item in
                            var text = item.str("text") ?? ""
                            if let quote = item["quote"]?["text"]?.string { text += "\n\n> " + quote.replacingOccurrences(of: "\n", with: "\n> ") }
                            if let correction = records.last(where: { $0.str("kind") == "correction" && $0.str("replaces") == item.str("id") }) {
                                text += "\n\nYour correction: " + (correction.str("text") ?? "")
                            }
                            return text
                        }.joined(separator: "\n\n")
                    }
                    try Data(Self.initialLearningPageText(role, body: body).utf8).write(to: destination, options: .atomic)
                    try appendTranscript(["role": .string("client"), "purpose": .string("initialize_page"), "file": .string(file), "page": .string(file), "session": .string(session), "hash": .string(pageHash(file)!)])
                }
                recoverOrphanPages()
                try setPageProperties(file: file, role: role)
                // Imported person corrections and actual quotes keep their existing protection.
                // These client audit entries claim no new person action and have no Undo hash.
                let items = current.filter { role == .memory ? $0.str("kind") == "memory" : role == .notes && Self.noteKinds.contains($0.str("kind") ?? "") }
                var protections: [(String, String)] = []
                for item in items {
                    if item.str("by") == "person", let id = item.str("id"), let text = item.str("text") {
                        protections.append(("person:" + id, text))
                    }
                    if let id = item.str("id"), let quote = item["quote"]?["text"]?.string {
                        protections.append(("quote:" + id, "> " + quote.replacingOccurrences(of: "\n", with: "\n> ")))
                    }
                    if let correction = records.last(where: { $0.str("kind") == "correction" && $0.str("replaces") == item.str("id") }),
                       let id = correction.str("id"), let text = correction.str("text") {
                        protections.append(("correction:" + id, "Your correction: " + text))
                    }
                }
                for (source, text) in protections {
                    guard !transcript.contains(where: { $0.str("migrationSource") == source && $0.str("file") == file }) else { continue }
                    try appendTranscript(["role": .string("client"), "purpose": .string("edit_page"), "file": .string(file), "page": .string(file), "session": .string(session),
                        "migrationSource": .string(source), "section": .string("(page)"), "hunks": .array([.object(["before": .string(""), "after": .string(text)])])])
                }
            }
            let goalFile = snapshot["pages"]!["goals"]!.string!
            let original = Self.initialLearningPageText(.goals, body: initialGoals)
            for goal in current where goal.str("kind") == "goal" && goal.str("by") == "sophia" {
                guard let id = goal.str("id"), !pageProposalHistory.contains(where: { $0.str("legacyID") == id }) else { continue }
                _ = try proposePageChange(file: goalFile,
                    content: activeGoals.compactMap { candidate -> String? in
                        if candidate.str("id") == id { return Self.legacyGoalProse(goal) }
                        return acceptedAncestor(candidate).map(Self.legacyGoalProse)
                    }.joined(separator: "\n\n"),
                    originNotebook: name, evidence: goal, session: session, legacyID: id, baseHash: Self.hash(original))
            }
            return Self.learningPageRoles.compactMap { notebookPage(role: $0) }
        }
    }

    private static func learningPageTitle(_ role: PageRole) -> String {
        switch role { case .goals: return "Goals"; case .notes: return "Sophia’s notes"; default: return "Working memory" }
    }
    private static func initialLearningPageText(_ role: PageRole, body: String) -> String {
        "---\ntitle: \(JSON.string(learningPageTitle(role)).line)\n---\n" + body + "\n"
    }
    private static func legacyGoalProse(_ goal: JSONObject) -> String {
        var text = "## " + (goal.str("text") ?? "Goal")
        if goal.str("by") == "person", let status = goal.str("status"), ["met", "dropped"].contains(status) { text += "\n\nMarked " + status + " by you." }
        let criteria = (goal["criteria"]?.array ?? []).compactMap(\.string)
        if !criteria.isEmpty { text += "\n\n" + criteria.map { "- " + $0 }.joined(separator: "\n") }
        return text
    }

    /// The ordinary conversation tool cannot bypass reviewed goals or evidence-checked notes.
    /// Check the role after the same locked reload used for the write.
    public func writeConversationPage(title: String, content: String, revising file: String?, session: String,
                                      toolUseID: String, why: String? = nil, thread: String = "") throws -> JSONObject {
        try locked {
            if let file {
                guard let existing = page(file) else { throw StoreError.notFound }
                guard ![PageRole.goals, .notes, .memory, .about].contains(existing.role) else { throw NotebookPageError.reservedPage }
            }
            return try writePage(title: title, content: content, revising: file, session: session, toolUseID: toolUseID, why: why, thread: thread)
        }
    }

    /// Goals are prose, with no inferred confirmation/status from their Markdown syntax.
    public func proposeGoalsPage(content: String, quote: String, session: String, thread: String = "") throws -> JSONObject {
        try locked {
            try ensureNotebookPages(session: session)
            let evidence = try checkedPageEvidence(content: content, quote: quote, refs: [], session: session, quoteEntries: Set(threadEntries(for: thread).filter(Self.isPersonMessage).compactMap { $0.str("id") }))
            var proposalEvidence: JSONObject = ["notebook": .string(name), "refs": evidence["refs"] ?? .array([])]
            if let quote = evidence["quote"]?.object { proposalEvidence["entry"] = quote["entry"]; proposalEvidence["quote"] = quote["text"] }
            return try proposePageChange(file: notebookPage(role: .goals)!.file, content: content, originNotebook: name, evidence: proposalEvidence, session: session)
        }
    }

    @discardableResult
    public func writeNotebookNotes(content: String, quote: String? = nil, refs: [String], session: String, thread: String = "") throws -> JSONObject {
        try writeNotebookLearningPage(role: .notes, content: content, quote: quote, refs: refs, session: session, thread: thread)
    }
    @discardableResult
    public func writeNotebookMemory(content: String, refs: [String], session: String, thread: String = "") throws -> JSONObject {
        try writeNotebookLearningPage(role: .memory, content: content, quote: nil, refs: refs, session: session, thread: thread)
    }

    private func checkedPageEvidence(content: String, quote: String?, refs: [String], session: String, quoteEntries: Set<String>? = nil) throws -> JSONObject {
        var candidate: JSONObject = ["kind": .string("background"), "text": .string(content.isEmpty ? "Clear working memory" : content), "refs": .array(refs.map { .string($0) })]
        if let q = quote, !q.isEmpty {
            if let entry = transcript.last(where: { Self.isPersonMessage($0) && (quoteEntries?.contains($0.str("id") ?? "") ?? ($0.str("session") == session)) && RecordChecks.normalize($0.str("text") ?? "").contains(RecordChecks.normalize(q)) }) {
                candidate["quote"] = .object(["entry": entry["id"]!, "text": .string(q)])
            } else { candidate["paraphrase"] = .bool(true) }
        }
        let allowed = quoteEntries ?? Set(transcript.filter { $0.str("session") == session }.compactMap { $0.str("id") })
        let result = RecordChecks(store: self).check([.object(candidate)], allowedKinds: ["background"], quoteEntries: allowed)
        guard let kept = result.kept.first else { throw NotebookPageError.invalidEvidence }
        return kept
    }

    private func writeNotebookLearningPage(role: PageRole, content: String, quote: String?, refs: [String], session: String, thread: String, quoteEntries: Set<String>? = nil, liveQuota: Bool = true) throws -> JSONObject {
        try locked {
            guard [.notes, .memory].contains(role) else { throw NotebookPageError.invalidRole }
            try ensureNotebookPages(session: session)
            let evidence = try checkedPageEvidence(content: content, quote: quote, refs: refs, session: session, quoteEntries: quoteEntries)
            let page = notebookPage(role: role)!
            if liveQuota && role == .notes && readPage(page.file)?.body != content + "\n" {
                let count = transcript.filter { $0.str("purpose") == "notebook_page_evidence" && $0.str("session") == session && $0.str("pageRole") == role.rawValue && $0["checkpoint"] != .bool(true) }.count
                guard count < Self.liveNotesPerSession else { throw NotebookPageError.quota }
            }
            let expected = "---\ntitle: \(JSON.string(page.title).line)\n---\n" + content + "\n"
            if refusal(revising: page.file, content: content) != nil || pageHash(page.file) == Self.hash(expected) {
                return try writePage(title: page.title, content: content, revising: page.file, session: session, toolUseID: "learning-page-" + UUID().uuidString, thread: thread)
            }
            // Reserve and persist the evidence before changing a body. An interrupted candidate
            // remains historical proposed material; only the recorded page write establishes save.
            var audit = evidence
            audit["kind"] = .string("page_evidence")
            audit["proposed"] = .bool(true)
            audit["pageRole"] = .string(role.rawValue)
            audit["page"] = .string(page.file)
            audit["basehash"] = .string(pageHash(page.file)!)
            let record = try appendLearning(audit, by: "sophia", session: session)
            let result = try writePage(title: page.title, content: content, revising: page.file, session: session, toolUseID: "learning-page-" + UUID().uuidString, thread: thread)
            try appendTranscript(["role": .string("tool"), "purpose": .string("notebook_page_evidence"), "pageRole": .string(role.rawValue), "file": .string(page.file), "page": .string(thread), "record": record["id"]!, "write": result["id"]!, "session": .string(session), "checkpoint": .bool(!liveQuota)])
            return result
        }
    }

    /// Checkpoint payloads contain complete Markdown bodies (or null to leave a page alone).
    /// Old structured checkpoint authoring is deliberately not another content authority.
    public func finishNotebookPageCheckpoint(_ text: String, failed: Bool, through: String, entries: Set<String>, session: String, catchUp: Bool) throws -> CheckpointResult {
        try locked {
            guard !failed, let object = RecordChecks.extractJSON(text)?.object,
                  object["notes"] != nil, object["memory"] != nil else { return .failed }
            for role in ["notes", "memory"] where object[role] != .null {
                guard object[role]?.string != nil else { return .failed }
            }
            try ensureNotebookPages(session: session)
            let refs = (object["refs"]?.array ?? []).compactMap(\.string)
            let quote = object.str("quote")
            // Validate both evidence and write protection before either body changes.
            for role in [PageRole.notes, .memory] {
                guard let body = object[role.rawValue]?.string else { continue }
                _ = try checkedPageEvidence(content: body, quote: quote, refs: refs, session: session, quoteEntries: entries)
                if refusal(revising: notebookPage(role: role)!.file, content: body) != nil { return .failed }
            }
            for role in [PageRole.notes, .memory] {
                guard let body = object[role.rawValue]?.string else { continue }
                let result = try writeNotebookLearningPage(role: role, content: body, quote: quote, refs: refs, session: session, thread: "", quoteEntries: entries, liveQuota: false)
                if result["refused"] == .bool(true) { return .failed }
            }
            try appendTranscript(["role": .string("client"), "purpose": .string("checkpoint"), "page": .string(""), "through": .string(through), "session": .string(session), "catch_up": .bool(catchUp), "page_format": .string("markdown"), "kept": .array([])])
            return .saved
        }
    }
}
