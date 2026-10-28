import Foundation

extension NotebookStore {
    public enum PageProposalError: Error { case missing, stale, editing, invalidEvidence }
    var pageProposalsURL: URL { url.appendingPathComponent("page-proposals.jsonl") }

    /// Proposals are audit records outside the editable Markdown. Only acceptance writes the page.
    public func proposePageChange(file: String, content: String, originNotebook: String,
                                  evidence: JSONObject, session: String, legacyID: String? = nil, baseHash: String? = nil) throws -> JSONObject {
        try locked {
            guard let hash = pageHash(file), page(file) != nil else { throw PageProposalError.missing }
            var fields: JSONObject = ["role": .string("sophia"), "purpose": .string("propose_page_change"),
                "id": .string("pc-" + UUID().uuidString), "at": .string(Self.now()), "session": .string(session),
                "file": .string(file), "basehash": .string(baseHash ?? hash), "content": .string(content),
                "originNotebook": .string(originNotebook), "evidence": .object(evidence)]
            if let legacyID { fields["legacyID"] = .string(legacyID) }
            try Data((fields.line + "\n").utf8).appendOrCreate(at: pageProposalsURL)
            return fields
        }
    }

    public var pageProposalHistory: [JSONObject] { Self.readLines(pageProposalsURL) }
    public func pendingPageProposals(originNotebook: String? = nil) -> [JSONObject] {
        let records = pageProposalHistory
        let decided = Set(records.compactMap { $0.str("proposal") })
        return records.filter { $0.str("purpose") == "propose_page_change" && !decided.contains($0.str("id") ?? "")
            && (originNotebook == nil || $0.str("originNotebook") == originNotebook) }
    }

    /// The whole file hash includes title/frontmatter. Any changed base requires a fresh proposal.
    @discardableResult
    public func acceptPageProposal(_ id: String, session: String) throws -> EditOutcome {
        try locked {
            guard let p = pendingPageProposals().first(where: { $0.str("id") == id }),
                  let file = p.str("file"), let content = p.str("content") else { throw PageProposalError.missing }
            guard pageHash(file) == p.str("basehash") else { throw PageProposalError.stale }
            guard editMarker == nil else { throw PageProposalError.editing }
            guard let body = readPage(file)?.body,
                  let range = Self.editRanges(in: body).first(where: { $0.key == "(page)" }) else { throw PageProposalError.missing }
            let result = try editPage(file: file, section: "(page)", baseHash: range.hash, text: content, session: session, wholeBody: true)
            if case .conflict = result { throw PageProposalError.stale }
            try recordProposalDecision(id, decision: "accepted", session: session)
            return result
        }
    }

    public func rejectPageProposal(_ id: String, session: String) throws {
        try locked {
            guard pendingPageProposals().contains(where: { $0.str("id") == id }) else { throw PageProposalError.missing }
            try recordProposalDecision(id, decision: "rejected", session: session)
        }
    }

    private func recordProposalDecision(_ id: String, decision: String, session: String) throws {
        let record: JSONObject = ["role": .string("person"), "purpose": .string("page_proposal_decision"),
            "proposal": .string(id), "decision": .string(decision), "session": .string(session), "at": .string(Self.now())]
        try Data((record.line + "\n").utf8).appendOrCreate(at: pageProposalsURL)
    }
}
