import Foundation

/// Sophia's working memory for one notebook, and recall over her long-term notes.
///
/// Memory is a short set of lines about where the inquiry stands now ("rusty on cross-entropy;
/// rebuilt it from −log p"). Each line is a `memory` record in learning.jsonl that cites the notes,
/// messages, pages, or goals it rests on, so forgetting a line loses no evidence. Sophia rewrites
/// the set as a whole; the store keeps unchanged lines, replaces changed ones, and retires the rest.
/// The person can correct or delete any line, and Sophia can't change a line they corrected.
extension NotebookStore {
    public static let memoryLimit = 10
    public static let memoryLineLength = 280

    /// The current memory lines, oldest first.
    public var memory: [JSONObject] {
        let replaced = Set(learning.filter { $0.str("kind") != "correction" }.compactMap { $0.str("replaces") })
        return learning.filter { $0.str("kind") == "memory" && $0["retired"] != .bool(true) && !replaced.contains($0.str("id") ?? "") }
    }

    public struct MemoryLine {
        public var id: String?
        public var text: String
        public var refs: [String]
        public init(id: String?, text: String, refs: [String]) { self.id = id; self.text = text; self.refs = refs }
    }

    /// Replaces Sophia's memory with `lines`. Returns the memory afterwards and what was refused.
    @discardableResult
    public func setMemory(_ lines: [MemoryLine], session: String) throws -> (memory: [JSONObject], problems: [String]) {
        try locked {
            let checks = RecordChecks(store: self)
            var problems: [String] = []
            let current = Dictionary(uniqueKeysWithValues: memory.compactMap { m in m.str("id").map { ($0, m) } })
            var keep: Set<String> = []
            var writes: [JSONObject] = []

            for line in lines {
                let text = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }
                if text.count > Self.memoryLineLength {
                    problems.append("Not kept: “\(text.prefix(50))…” is too long for a memory line; keep each to a sentence or two.")
                    if let id = line.id, current[id] != nil { keep.insert(id) }
                    continue
                }
                let refs = line.refs.filter(checks.resolves)
                if let id = line.id, let old = current[id] {
                    keep.insert(id)
                    let oldRefs = (old["refs"]?.array ?? []).compactMap(\.string)
                    let useRefs = refs.isEmpty ? oldRefs : refs      // a reworded line keeps its evidence
                    if old.str("text") == text && Set(oldRefs) == Set(useRefs) { continue }
                    if correction(of: id) != nil { problems.append("\(id) was corrected by the person; it stays as they have it."); continue }
                    writes.append(["kind": .string("memory"), "replaces": .string(id), "text": .string(text), "refs": .array(useRefs.map { .string($0) })])
                } else {
                    guard !refs.isEmpty else {
                        problems.append("Not kept: “\(text.prefix(50))” points to nothing that exists. Cite the notes (n-…), messages (t-…), pages (p:…), or goals it rests on.")
                        continue
                    }
                    writes.append(["kind": .string("memory"), "text": .string(text), "refs": .array(refs.map { .string($0) })])
                }
            }
            // Lines left out are forgotten, except ones the person corrected.
            var retire: [String] = []
            for id in current.keys.sorted() where !keep.contains(id) {
                if correction(of: id) != nil { problems.append("Kept \(id): the person corrected it."); continue }
                retire.append(id)
            }
            let newCount = writes.filter { $0["replaces"] == nil }.count
            let total = current.count - retire.count + newCount
            if total > Self.memoryLimit {
                return (memory, ["Not changed: memory holds at most \(Self.memoryLimit) lines, and this would make \(total). Drop or merge lines."])
            }
            for w in writes { _ = try appendLearningLocked(w, by: "sophia", session: session) }
            for id in retire {
                _ = try appendLearningLocked(["kind": .string("memory"), "replaces": .string(id), "retired": .bool(true),
                                              "text": .string(current[id]?.str("text") ?? "")], by: "sophia", session: session)
            }
            if !writes.isEmpty || !retire.isEmpty {
                _ = try appendTranscriptLocked(["role": .string("tool"), "tool": .string("memory"), "session": .string(session),
                                                "added": .number(Double(newCount)), "changed": .number(Double(writes.count - newCount)),
                                                "dropped": .number(Double(retire.count))])
            }
            return (memory, problems)
        }
    }

    /// Looks up Sophia's long-term notes, and the person's messages, by note id, by page, or by
    /// words. Words match a note if all of them appear in its text or quote (any order, any case).
    public func recall(ids: [String] = [], page: String? = nil, words: String? = nil, limit: Int = 12) -> (notes: [JSONObject], messages: [JSONObject]) {
        let notes = shownNotes + memory
        var found: [JSONObject] = []
        if !ids.isEmpty {
            let wanted = Set(ids)
            found = learning.filter { wanted.contains($0.str("id") ?? "") }
        }
        if let page, !page.isEmpty {
            let ref = page.hasPrefix("p:") ? page : "p:" + page
            found += notes.filter { ($0["refs"]?.array ?? []).contains(.string(ref)) }
        }
        var messages: [JSONObject] = []
        let terms = (words ?? "").lowercased().split(whereSeparator: { $0.isWhitespace || $0.isPunctuation }).map(String.init)
        if !terms.isEmpty {
            func matches(_ s: String) -> Bool { let l = s.lowercased(); return terms.allSatisfy { l.contains($0) } }
            found += notes.filter { matches(($0.str("text") ?? "") + " " + ($0["quote"]?["text"]?.string ?? "")) }
            messages = transcript.filter { NotebookStore.isPersonMessage($0) && matches($0.str("text") ?? "") }
        }
        var seen: Set<String> = []
        found = found.filter { seen.insert($0.str("id") ?? "").inserted }
        return (Array(found.reversed().prefix(limit)), Array(messages.reversed().prefix(5)))
    }
}
