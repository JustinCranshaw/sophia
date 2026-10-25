import Foundation

/// A read-only projection of saved links, never a score or inferred association.
public struct GoalCriterionEvidence {
    public let attempts: [JSONObject]
    public let read: JSONObject?
    public let newerEvidence: Bool
}

extension NotebookStore {
    private static func evidenceSavedBefore(_ a: JSONObject, _ b: JSONObject) -> Bool {
        let left = (a.str("at") ?? "", Int((a.str("id") ?? "").split(separator: "-").last ?? "") ?? 0)
        let right = (b.str("at") ?? "", Int((b.str("id") ?? "").split(separator: "-").last ?? "") ?? 0)
        return left < right
    }

    public func evidence(forCriterion ref: String) -> GoalCriterionEvidence {
        guard ref.contains("#"), EvidenceReference.resolve(ref, in: self).kind == .goal else {
            return GoalCriterionEvidence(attempts: [], read: nil, newerEvidence: false)
        }
        // shownNotes keeps the latest Sophia revision beneath the person's correction.
        let notes = shownNotes
        let reads = notes.filter { $0.str("kind") == "read" && ($0["refs"]?.array ?? []).contains(.string(ref)) }
        let citedAttemptRoots = Set(reads.flatMap { ($0["refs"]?.array ?? []).compactMap(\.string) }.compactMap { id -> String? in
            // Missing ids remain unavailable; do not guess a chain or match shared words/messages.
            guard record(id)?.str("kind") == "attempt" else { return nil }
            return rootID(of: id)
        })
        let attempts = notes.filter { r in
            r.str("kind") == "attempt" && ((r["refs"]?.array ?? []).contains(.string(ref)) || citedAttemptRoots.contains(rootID(of: r.str("id") ?? "")))
        }.sorted(by: Self.evidenceSavedBefore)
        let read = reads.max(by: Self.evidenceSavedBefore)
        let latestReadVersion = read.map { correction(of: $0.str("id") ?? "") ?? $0 }
        let newer = latestReadVersion.map { interpretation in
            attempts.contains { Self.evidenceSavedBefore(interpretation, correction(of: $0.str("id") ?? "") ?? $0) }
        } ?? false
        return GoalCriterionEvidence(attempts: attempts, read: read, newerEvidence: newer)
    }

    public var attemptsWithoutCriterionLinks: [JSONObject] {
        let linked = Set(goals.flatMap { goal -> [JSONObject] in
            let root = rootID(of: goal.str("id") ?? "")
            return (goal["criteria"]?.array ?? []).indices.flatMap { evidence(forCriterion: "\(root)#\($0 + 1)").attempts }
        }.compactMap { $0.str("id") })
        return shownNotes.filter { $0.str("kind") == "attempt" && !linked.contains($0.str("id") ?? "") }.sorted(by: Self.evidenceSavedBefore)
    }
}
