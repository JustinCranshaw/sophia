import Foundation

/// The client checks from DATA-MODEL.md, "How records arrive, and what the client checks".
/// Everything Sophia writes passes through here; anything that fails is shown to the
/// person and not stored.
public struct RecordChecks {
    public struct Outcome {
        public var kept: [JSONObject] = []
        public var notes: [String] = []   // what was dropped or rejected, and why
    }

    public static let checkpointKinds: Set<String> = ["attempt", "read", "question", "next_step", "follow_up", "background"]
    public static let briefingKinds: Set<String> = ["briefing"]
    /// A briefing is two short sentences; anything longer is a recap the person didn't ask for.
    public static let briefingWordLimit = 60

    /// Fields only the app sets; anything Sophia supplies for them is discarded.
    static let clientOnly: Set<String> = ["id", "at", "by", "session", "status", "decision", "replaces", "deleted"]

    let store: NotebookStore

    public init(store: NotebookStore) { self.store = store }

    static func normalize(_ s: String) -> String {
        s.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    /// Does `ref` point to something that exists?
    func resolves(_ ref: String) -> Bool {
        if ref.hasPrefix("p:") { return store.pageFiles.contains(String(ref.dropFirst(2))) }
        if ref.hasPrefix("t-") { return store.transcript.contains { $0.str("id") == ref } }
        let base = ref.split(separator: "#").first.map(String.init) ?? ref
        guard let rec = store.record(base) else { return false }
        if let hash = ref.firstIndex(of: "#") {
            guard rec.str("kind") == "goal", let n = Int(ref[ref.index(after: hash)...]) else { return false }
            let count = store.goals.first { store.rootID(of: $0.str("id") ?? "") == base }?["criteria"]?.array?.count ?? 0
            return n >= 1 && n <= count
        }
        return true
    }

    func isEvidenceOfUnderstanding(_ ref: String) -> Bool {
        if ref.hasPrefix("t-") { return store.transcript.first { $0.str("id") == ref }.map(NotebookStore.isPersonMessage) == true }
        return store.record(ref)?.str("kind") == "attempt"
    }

    /// `items` is Sophia's output: a list of candidate records.
    /// `session` is the session being summarized; quotes must come from it.
    public func check(_ items: [JSON], allowedKinds: Set<String>, session: String) -> Outcome {
        check(items, allowedKinds: allowedKinds) { $0.str("session") == session }
    }

    /// Notes on a span of messages that may cross sessions: quotes must come from `quoteEntries`.
    public func check(_ items: [JSON], allowedKinds: Set<String>, quoteEntries: Set<String>) -> Outcome {
        check(items, allowedKinds: allowedKinds) { quoteEntries.contains($0.str("id") ?? "") }
    }

    func check(_ items: [JSON], allowedKinds: Set<String>, quotable: (JSONObject) -> Bool) -> Outcome {
        var out = Outcome()
        for (i, item) in items.enumerated() {
            guard var obj = item.object else { out.notes.append("Item \(i + 1) wasn't a record."); continue }
            let kind = obj.str("kind") ?? ""
            let label = "\(kind.isEmpty ? "record" : kind) “\(String((obj.str("text") ?? "").prefix(60)))”"
            guard allowedKinds.contains(kind) else { out.notes.append("Not kept: \(label). Sophia can't write records of kind “\(kind)”."); continue }
            for k in Self.clientOnly { obj.removeValue(forKey: k) }
            guard let text = obj.str("text"), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                out.notes.append("Not kept: \(label). It had no text."); continue
            }
            let words = text.split(whereSeparator: { $0.isWhitespace }).count
            if kind == "briefing" && words > Self.briefingWordLimit {
                out.notes.append("Not kept: \(label). It ran to \(words) words; a briefing is two short sentences."); continue
            }

            // References must exist.
            let refs = (obj["refs"]?.array ?? []).compactMap(\.string)
            let valid = refs.filter(resolves)
            let invalid = refs.filter { !resolves($0) }
            if !invalid.isEmpty { out.notes.append("Dropped references that don't exist (\(invalid.joined(separator: ", "))) from \(label).") }
            obj["refs"] = .array(valid.map { .string($0) })

            // Quotes must be the person's exact words from this session. Briefings carry none.
            if let q = obj["quote"]?.object {
                let entry = store.transcript.first { $0.str("id") == q.str("entry") }
                let ok = kind != "briefing"
                    && entry.map(NotebookStore.isPersonMessage) == true
                    && entry.map(quotable) == true
                    && Self.normalize(entry?.str("text") ?? "").contains(Self.normalize(q.str("text") ?? "\u{0}"))
                    && !(q.str("text") ?? "").trimmingCharacters(in: .whitespaces).isEmpty
                if ok {
                    obj["quote"] = .object(["entry": .string(q.str("entry")!), "text": .string(q.str("text")!)])
                } else {
                    obj.removeValue(forKey: "quote")
                    obj["paraphrase"] = .bool(true)
                    out.notes.append("Removed a quote from \(label): those exact words aren't in the messages these notes cover, so it shows as Sophia's paraphrase.")
                }
            } else if obj["quote"] != nil {
                obj.removeValue(forKey: "quote")
            }

            // An interpretation with nothing behind it can't be stored.
            if obj["quote"] == nil && valid.isEmpty {
                out.notes.append("Not kept: \(label). It pointed to nothing you said or did."); continue
            }
            // Reading a page is not evidence of understanding.
            if kind == "read" && !valid.contains(where: isEvidenceOfUnderstanding) {
                out.notes.append("Not kept: \(label). A read must point to one of your attempts or messages."); continue
            }
            out.kept.append(obj)
        }
        return out
    }

    /// Reads a checkpoint reply: {"notes": [...], "memory": [...]}, or a bare list of notes from
    /// older prompts. `memory` is nil when the reply leaves it out (or empty), so memory isn't wiped by accident.
    public static func parseCheckpoint(_ text: String) -> (notes: [JSON], memory: [NotebookStore.MemoryLine]?, parsed: Bool) {
        guard let v = extractJSON(text) else { return ([], nil, false) }
        if let list = v.array { return (list, nil, true) }
        let notes = v["notes"]?.array ?? []
        let lines = (v["memory"]?.array ?? []).compactMap { l -> NotebookStore.MemoryLine? in
            guard let t = l["text"]?.string else { return nil }
            return .init(id: l["id"]?.string, text: t, refs: (l["refs"]?.array ?? []).compactMap(\.string))
        }
        return (notes, lines.isEmpty ? nil : lines, true)
    }

    /// Finds the JSON array or object in a reply that may have prose or a code fence around it.
    public static func extractJSON(_ text: String) -> JSON? {
        if let direct = JSON.parse(text.trimmingCharacters(in: .whitespacesAndNewlines)) { return direct }
        for (open, close) in [("[", "]"), ("{", "}")] {
            if let a = text.firstIndex(of: Character(open)), let b = text.lastIndex(of: Character(close)), a < b,
               let v = JSON.parse(String(text[a...b])) { return v }
        }
        return nil
    }
}
