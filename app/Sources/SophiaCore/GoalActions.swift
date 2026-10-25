import Foundation

extension NotebookStore {
    public enum GoalActionError: Error, LocalizedError {
        case changed, criteriaDiffer
        public var errorDescription: String? {
            switch self {
            case .changed: return "That goal changed. Review its current version before deciding."
            case .criteriaDiffer: return "Keeping an earlier version with different criteria could reassign saved or undoable evidence. Leave this proposal provisional or choose a separate narrower goal."
            }
        }
    }

    private func goalForPersonAction(_ id: String, provisional: Bool) throws -> JSONObject {
        guard let goal = goals.first(where: { $0.str("id") == id }), isProvisional(goal) == provisional else { throw GoalActionError.changed }
        return goal
    }

    private func goalVersion(_ goal: JSONObject, replacing id: String) -> JSONObject {
        var next: JSONObject = ["kind": .string("goal"), "replaces": .string(id)]
        for key in ["text", "status", "criteria", "quote", "refs"] { if let value = goal[key] { next[key] = value } }
        return next
    }

    /// The exact version shown to the person must still be current under the writer's lock.
    @discardableResult
    public func confirmGoalProposal(_ id: String, session: String) throws -> JSONObject {
        try locked {
            let goal = try goalForPersonAction(id, provisional: true)
            return try appendLearningLocked(goalVersion(goal, replacing: id), by: "person", session: session)
        }
    }

    /// Whole-proposal decline keeps criterion positions meaningful; no criterion rewriting.
    public func declineGoalProposal(_ id: String, session: String) throws -> [JSONObject] {
        try locked {
            let goal = try goalForPersonAction(id, provisional: true)
            if let previousID = goal.str("replaces") {
                guard let previous = record(previousID), previous.str("kind") == "goal" else { throw GoalActionError.changed }
                guard (previous["criteria"]?.array ?? []) == (goal["criteria"]?.array ?? []) else { throw GoalActionError.criteriaDiffer }
                try appendLearningLocked(goalVersion(previous, replacing: id), by: previous.str("by") ?? "person", session: session)
                return []
            }
            return try deleteLearningLocked(id)
        }
    }

    /// Editing a confirmed goal cannot double as confirmation of an unseen proposal.
    @discardableResult
    public func updatePersonGoal(_ id: String, text: String? = nil, status: String? = nil, addCriterion: String? = nil, session: String) throws -> JSONObject {
        try locked {
            let goal = try goalForPersonAction(id, provisional: false)
            var next = goalVersion(goal, replacing: id)
            if let text { next["text"] = .string(text) }
            if let status { next["status"] = .string(status) }
            if let criterion = addCriterion?.trimmingCharacters(in: .whitespacesAndNewlines), !criterion.isEmpty {
                next["criteria"] = .array((goal["criteria"]?.array ?? []) + [.string(criterion)])
            }
            return try appendLearningLocked(next, by: "person", session: session)
        }
    }
}
