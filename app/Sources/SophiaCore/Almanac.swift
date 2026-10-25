import Foundation

public struct AlmanacSettings: Codable, Equatable {
    public var enabled: Bool, automatic: Bool, paused: Bool
    public var selectedNotebooks: [String]
    public var topics: String
    public var automaticMinute: Int
    public init(enabled: Bool = false, automatic: Bool = false, paused: Bool = false, selectedNotebooks: [String] = [], topics: String = "", automaticMinute: Int = 540) {
        self.enabled = enabled; self.automatic = automatic; self.paused = paused
        self.selectedNotebooks = selectedNotebooks; self.topics = topics; self.automaticMinute = automaticMinute
    }
}
public enum AlmanacPhase: String, Codable, Equatable { case unconfigured, idle, paused, needsThemes, preparing, ready, failed, cancelled }
public struct AlmanacEntry: Codable, Equatable, Identifiable {
    public var id: String { runID }
    public let file: String, title: String, writeID: String, runID: String, preparedAt: String
}
public struct AlmanacThemes: Codable, Equatable {
    public let notebookNames: [String], topics: String
    public var isEmpty: Bool { notebookNames.isEmpty && topics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}
public struct AlmanacReservation: Codable, Equatable {
    public let id: String, revision: String, day: String, startedAt: String
    public let themes: AlmanacThemes
    public let targetIsSeparate: Bool
    public let manual: Bool
    public let previousTitles: [String]
}
public struct AlmanacSnapshot {
    public let settings: AlmanacSettings?, phase: AlmanacPhase
    public let waitingEntry: AlmanacEntry?, latestEntry: AlmanacEntry?
    public let problem: String?
}
private struct AlmanacState: Codable, Equatable {
    var version = 1
    var settings: AlmanacSettings
    var revision = UUID().uuidString
    var attemptedDay: String?
    var run: AlmanacReservation?
    var phase: AlmanacPhase = .idle
    var waitingEntry: AlmanacEntry?
    var latestEntry: AlmanacEntry?
    var problem: String?
    var snapshot: AlmanacSnapshot {
        .init(settings: settings, phase: !settings.enabled || (settings.paused && phase != .preparing) ? .paused : phase,
              waitingEntry: waitingEntry, latestEntry: latestEntry, problem: problem)
    }
}
public enum AlmanacError: Error, LocalizedError {
    case notConfigured, changed, busy, noThemes, invalidEntry, needsSource, uncertainSave
    public var errorDescription: String? {
        switch self {
        case .notConfigured: return "Choose a newly created Almanac notebook before enabling preparation."
        case .changed: return "Almanac settings or included notebooks changed. Prepare again with the current choices."
        case .busy: return "An Almanac entry is already being prepared."
        case .noThemes: return "Choose an available notebook theme or type a topic first."
        case .invalidEntry: return "Sophia did not return a complete usable Almanac entry. Nothing new was marked ready."
        case .needsSource: return "This entry needs an opened source passage. Almanac preparation can search summaries but cannot open external sources. No entry was marked ready."
        case .uncertainSave: return "Preparation could not be fully recorded. A page may already exist. Inspect the Almanac and reopen this notebook before retrying; an exact recorded save can be reconciled without replacing your edits."
        }
    }
}
public enum Almanac {
    private static func decode(_ value: JSON?) -> AlmanacState? {
        guard let value, let data = try? JSONEncoder().encode(value), let state = try? JSONDecoder().decode(AlmanacState.self, from: data), state.version == 1,
              (0..<1440).contains(state.settings.automaticMinute) else { return nil }
        return state
    }
    fileprivate static func existingState(url: URL) -> AlmanacState? {
        decode(ExistingNotebook(root: url.deletingLastPathComponent(), name: url.lastPathComponent)?.almanacConfiguration)
    }
    public static func snapshot(url: URL) -> AlmanacSnapshot? { existingState(url: url)?.snapshot }
    public static func isConfigured(url: URL) -> Bool { snapshot(url: url) != nil }
    public static func entry(id: String, url: URL) -> AlmanacEntry? {
        guard isConfigured(url: url), let book = ExistingNotebook(root: url.deletingLastPathComponent(), name: url.lastPathComponent),
              let action = book.almanacAction(id: id), let file = action.str("file"), let page = book.readPage(file), let write = action.str("id") else { return nil }
        return .init(file: file, title: page.title, writeID: write, runID: id, preparedAt: action.str("at") ?? "")
    }
    public static func eligibleNotebookNames(root: URL, excluding target: String) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []).compactMap { url in
            guard url.lastPathComponent != target, let book = ExistingNotebook(root: root, name: url.lastPathComponent), !book.isSeparate else { return nil }
            return book.name
        }.sorted()
    }
    public static func themes(settings: AlmanacSettings, target: URL) -> AlmanacThemes {
        let allowed: Set<String>
        if let book = ExistingNotebook(root: target.deletingLastPathComponent(), name: target.lastPathComponent), !book.isSeparate {
            allowed = Set(eligibleNotebookNames(root: target.deletingLastPathComponent(), excluding: target.lastPathComponent))
        } else { allowed = [] }
        var seen = Set<String>()
        return .init(notebookNames: settings.selectedNotebooks.filter { allowed.contains($0) && seen.insert($0).inserted }, topics: settings.topics)
    }
    public static func localDay(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.era, .year, .month, .day], from: date)
        return "\(c.era ?? 0)-\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }
    public static func isDue(settings: AlmanacSettings, lastAttemptDay: String?, hasWaiting: Bool, isPreparing: Bool, acknowledged: Bool, now: Date, calendar: Calendar) -> Bool {
        let time = calendar.dateComponents([.hour, .minute], from: now)
        return settings.enabled && settings.automatic && !settings.paused && acknowledged && !hasWaiting && !isPreparing
            && lastAttemptDay != localDay(now, calendar: calendar)
            && (time.hour ?? 0) * 60 + (time.minute ?? 0) >= settings.automaticMinute
    }
    fileprivate static func state(_ store: NotebookStore) -> AlmanacState? { decode(store.meta["almanac"]) }
    fileprivate static func save(_ state: AlmanacState, in store: NotebookStore) throws {
        try store.saveAlmanacMetadata(JSONDecoder().decode(JSON.self, from: JSONEncoder().encode(state)))
    }
}

extension NotebookStore {
    public var almanacSnapshot: AlmanacSnapshot {
        Almanac.state(self)?.snapshot ?? .init(settings: nil, phase: .unconfigured, waitingEntry: nil, latestEntry: nil, problem: nil)
    }
    public func configureAlmanac(_ settings: AlmanacSettings) throws {
        try locked {
            guard (0..<1440).contains(settings.automaticMinute), Almanac.state(self) != nil || (pageFiles.isEmpty && transcript.isEmpty && learning.isEmpty) else { throw AlmanacError.notConfigured }
            var state = Almanac.state(self) ?? AlmanacState(settings: settings)
            if let pending = state.run, pendingAlmanacAction(pending) != nil {
                guard let entry = recordedAlmanacEntry(pending) else { throw AlmanacError.uncertainSave }
                state.latestEntry = entry; state.waitingEntry = entry
            }
            state.settings = settings; state.revision = UUID().uuidString
            state.run = nil; state.problem = nil; state.phase = state.waitingEntry == nil ? .idle : .ready
            try Almanac.save(state, in: self)
        }
    }
    /// Reconcile only an exact, recorded authored write. Disk orphans never establish success.
    public func reconcileAlmanac(interrupted: Bool = false) throws {
        try locked {
            guard var state = Almanac.state(self) else { return }
            let original = state
            if let run = state.run, let entry = recordedAlmanacEntry(run) {
                state.latestEntry = entry; state.waitingEntry = entry; state.phase = .ready; state.problem = nil; state.run = nil
            } else if let run = state.run, pendingAlmanacAction(run) != nil {
                state.phase = .failed; state.problem = AlmanacError.uncertainSave.localizedDescription
            } else if interrupted && state.phase == .preparing {
                state.phase = .failed; state.problem = "Preparation was interrupted. Choose Retry when you are ready."; state.run = nil
            }
            if let waiting = state.waitingEntry, !pageFiles.contains(waiting.file) || readPage(waiting.file) == nil { state.waitingEntry = nil }
            if state != original { try Almanac.save(state, in: self) }
        }
    }
    public func reserveAlmanac(manual: Bool, acknowledged: Bool, now: Date = Date(), calendar: Calendar = .current) throws -> AlmanacReservation? {
        try locked {
            guard var state = Almanac.existingState(url: url) else { throw AlmanacError.notConfigured }
            if let pending = state.run, pendingAlmanacAction(pending) != nil {
                guard let entry = recordedAlmanacEntry(pending) else { throw AlmanacError.uncertainSave }
                state.latestEntry = entry; state.waitingEntry = entry; state.phase = .ready; state.problem = nil; state.run = nil
                try Almanac.save(state, in: self)
                return nil // A Retry reconciles this recorded run, it does not create a duplicate.
            }
            guard state.phase != .preparing else { if manual { throw AlmanacError.busy }; return nil }
            guard state.settings.enabled, (manual || !state.settings.paused), acknowledged else { return nil }
            if !manual && [.failed, .cancelled].contains(state.phase) { return nil }
            if !manual && !Almanac.isDue(settings: state.settings, lastAttemptDay: state.attemptedDay, hasWaiting: state.waitingEntry != nil, isPreparing: false, acknowledged: acknowledged, now: now, calendar: calendar) { return nil }
            let themes = Almanac.themes(settings: state.settings, target: url)
            guard !themes.isEmpty else { if manual { throw AlmanacError.noThemes }; return nil }
            let run = AlmanacReservation(id: UUID().uuidString, revision: state.revision, day: Almanac.localDay(now, calendar: calendar), startedAt: ISO8601DateFormatter().string(from: now), themes: themes,
                targetIsSeparate: isSeparate, manual: manual, previousTitles: transcript.filter { $0.str("tool") == "write_page" && ($0.str("tool_use") ?? "").hasPrefix("almanac:") && $0["refused"] != .bool(true) }.compactMap { $0.str("title") }.suffix(30).map { $0 })
            state.attemptedDay = run.day; state.run = run; state.phase = .preparing; state.problem = nil
            try Almanac.save(state, in: self)
            return run
        }
    }
    public func almanacRunIsCurrent(_ run: AlmanacReservation) -> Bool {
        reload()
        guard let state = Almanac.existingState(url: url), state.run?.id == run.id, state.revision == run.revision, state.phase == .preparing,
              state.settings.enabled, (run.manual || !state.settings.paused) else { return false }
        return isSeparate == run.targetIsSeparate && Almanac.themes(settings: state.settings, target: url) == run.themes
    }
    public func failAlmanac(_ run: AlmanacReservation, message: String, cancelled: Bool = false) throws {
        try locked {
            guard var state = Almanac.state(self), state.run?.id == run.id else { return }
            // Keep the run identity until a possible recorded partial save has been reconciled.
            state.phase = cancelled ? .cancelled : .failed; state.problem = message
            try Almanac.save(state, in: self)
        }
    }
    public func acknowledgeAlmanacOpening(file: String) throws {
        try locked {
            guard var state = Almanac.state(self), state.waitingEntry?.file == file else { return }
            state.waitingEntry = nil
            if state.phase == .ready { state.phase = .idle }
            try Almanac.save(state, in: self)
        }
    }
    private func pendingAlmanacAction(_ run: AlmanacReservation) -> JSONObject? {
        guard let action = transcript.last(where: { $0.str("tool") == "write_page" && $0.str("tool_use") == "almanac:" + run.id && $0["refused"] != .bool(true) && $0["recovered"] != .bool(true) }),
              let id = action.str("id"), !isUndone(id) else { return nil }
        return action
    }
    private func recordedAlmanacEntry(_ run: AlmanacReservation, verifyOriginalBody: Bool = false) -> AlmanacEntry? {
        guard let action = pendingAlmanacAction(run), let file = action.str("file"), pageFiles.contains(file),
              let title = action.str("title"), let id = action.str("id"), let current = readPage(file),
              !verifyOriginalBody || action.str("hash") == pageHash(file) else { return nil }
        return .init(file: file, title: current.title.isEmpty ? title : current.title, writeID: id, runID: run.id, preparedAt: action.str("at") ?? run.startedAt)
    }
    public func recordAlmanacSearch(_ source: AlmanacSearchEvidence, run: AlmanacReservation, session: String) throws {
        try locked {
            guard almanacRunIsCurrent(run) else { throw AlmanacError.changed }
            guard !transcript.contains(where: { $0.str("almanac_run") == run.id && $0.str("tool_use_id") == source.id }) else { return }
            try appendTranscriptLocked(["role": .string("tool"), "tool": .string("WebSearch"), "purpose": .string("almanac_source"), "session": .string(session), "almanac_run": .string(run.id), "tool_use_id": .string(source.id), "query": source.input["query"] ?? .null, "input": source.input, "content": source.content, "metadata": source.metadata, "is_error": .bool(source.isError)])
        }
    }

    /// No model writes: the host commits exactly one new page, through the ordinary writer/Undo path.
    public func saveAlmanac(_ draft: AlmanacDraft, evidence: [AlmanacSearchEvidence], run: AlmanacReservation, session: String) throws -> AlmanacEntry {
        try locked {
            guard almanacRunIsCurrent(run), var state = Almanac.state(self) else { throw AlmanacError.changed }
            let body = try draft.pageBody(evidence: evidence)
            for source in evidence { try recordAlmanacSearch(source, run: run, session: session) }
            _ = try writePage(title: draft.title, content: body, revising: nil, session: session, toolUseID: "almanac:" + run.id)
            guard let entry = recordedAlmanacEntry(run, verifyOriginalBody: true) else { throw AlmanacError.uncertainSave }
            state.latestEntry = entry; state.waitingEntry = entry; state.phase = .ready; state.problem = nil; state.run = nil
            try Almanac.save(state, in: self)
            return entry
        }
    }
}
