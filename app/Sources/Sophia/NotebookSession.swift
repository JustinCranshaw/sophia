import AppKit
import SophiaCore
import SophiaReader

/// One open notebook: its files, its conversation process, and what the person is looking at.
/// The person's actions write through the store; Sophia's output is checked before it is stored.
final class NotebookSession: ObservableObject {
    enum Place: Hashable { case contents, goals, notes, about, page(String) }
    enum Request: Equatable {
        /// Notes on the person's messages up to `through`; quotes may come only from `entries`.
        case checkpoint(through: String, entries: Set<String>, catchUp: Bool)
        case briefing
    }

    /// How long the conversation must have been quiet for an opening to count as coming back.
    /// Shorter gaps are relaunches or pauses: no briefing, no catch-up notes.
    static let returnGap: TimeInterval = ProcessInfo.processInfo.environment["SOPHIA_RETURN_GAP"].flatMap(TimeInterval.init) ?? 6 * 3600

    let store: NotebookStore
    let library: LibraryStore          // About you and links, shared by every notebook
    let session: String

    // Leaving the page, or hiding the book, commits an open editor; it never discards it.
    @Published var place: Place = .contents { didSet { if case .page(let f) = place, f == editing?.file { return }; commitEdit() } }
    @Published var bookShown = true { didSet { if !bookShown { commitEdit() } } }
    @Published var streaming = ""
    @Published var isResponding = false
    @Published var activity: String?
    @Published var problem: String?
    @Published var lastWrites: [String] = []          // transcript ids of page writes and edits since the person's last message
    @Published var lastReleases: [String] = []        // the person's releases of their edits, undoable until their next message
    @Published var editing: PageEditing?             // the range of a page open in the editor
    @Published var composerFocused = false           // the conversation's composer has focus; an open editor's strip dims
    @Published var lastDeleted: [JSONObject]?        // records; Undo lasts until the next message
    @Published var pendingSection: String?           // a section to scroll to once its page is laid out

    private var engine: ClaudeEngine?
    private var request: Request?
    private var requestText = ""
    private var stopping = false
    private var pendingTools: [String: String] = [:]
    private var turnTexts: [String] = []                // Sophia's text blocks in the current reply
    private var queued: String?            // a message the person sent while notes or a briefing were being written
    private var briefAfterNotes = false
    private var dropBriefing = false
    private var musicWarnings: [String: [MusicWarnings]] = [:]   // each page's current notation warnings, as last rendered
    private var toldMusic: Set<MusicWarnings> = []                // those Sophia has been told about this session
    private var editDraft: String?          // the editor's live text; not published, so typing doesn't redraw the window
    private var terminating: Any?

    init(url: URL) throws {
        store = try NotebookStore(url: url)
        library = LibraryStore(root: url.deletingLastPathComponent())
        session = store.newSessionID()
        // A marker left by a crash would keep Sophia out of a section nobody is editing.
        store.endEdit()
        store.fileUndecidedDrafts(session: session)
        if Snapshot.outDir == nil, store.isReturn(after: Self.returnGap) {
            DispatchQueue.main.async { [weak self] in self?.pickUp() }
        }
        terminating = NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            self?.commitEdit()
        }
    }

    deinit {
        engine?.stop()
        if let terminating { NotificationCenter.default.removeObserver(terminating) }
    }

    func changed() { objectWillChange.send() }

    // MARK: The conversation process

    static func sophiaPrompt() -> String? {
        if let url = Bundle.main.url(forResource: "SOPHIA", withExtension: "md"), let s = try? String(contentsOf: url, encoding: .utf8) { return s }
        // During development: look for SOPHIA.md above the build folder.
        var dir = Bundle.main.executableURL?.deletingLastPathComponent()
        for _ in 0..<8 {
            guard let d = dir else { break }
            let candidate = d.appendingPathComponent("SOPHIA.md")
            if let s = try? String(contentsOf: candidate, encoding: .utf8) { return s }
            dir = d.deletingLastPathComponent()
        }
        return nil
    }

    private func ensureEngine() -> Bool {
        if let e = engine, e.isRunning { return true }
        guard let claude = ClaudeEngine.locateClaude() else {
            problem = "Sophia runs on Claude Code, which isn't installed. Install it from claude.com/code, run `claude` once in Terminal to sign in, then try again."
            return false
        }
        guard let prompt = Self.sophiaPrompt() else { problem = "SOPHIA.md is missing from the app."; return false }
        let tools = Bundle.main.executableURL!.deletingLastPathComponent().appendingPathComponent("sophia-mcp").path
        let e = ClaudeEngine(config: .init(claudePath: claude, toolServerPath: tools, notebookURL: store.url,
                                           systemPrompt: prompt, context: Prompts.context(store), resume: store.claudeSession,
                                           session: session))
        e.onEvent = { [weak self] in self?.handle($0) }
        do { try e.start() } catch { problem = "Couldn't start Claude Code: \(error.localizedDescription)"; return false }
        engine = e
        return true
    }

    func shutdown() { commitEdit(); engine?.stop(); engine = nil }

    private func handle(_ event: ClaudeEngine.Event) {
        switch event {
        case .started(let sid, let source, _, _):
            if source != "none" {
                // Billing guard: Sophia only runs on the person's subscription login.
                engine?.stop()
                isResponding = false
                problem = "Claude Code is set to use an API key (\(source)), which bills separately from your subscription. Sophia won't continue on it. Remove the key from Claude Code's settings or environment, then try again."
                return
            }
            if store.claudeSession != sid, !sid.isEmpty { store.claudeSession = sid }
        case .textDelta(let t):
            if request == nil { streaming += t }
        case .assistantText(let t):
            if request != nil { requestText += t; return }
            // Suppress only verbatim repeats; a similar block may answer an outstanding question.
            defer { turnTexts.append(t) }
            if Prompts.isRestatement(t, of: turnTexts) { streaming = ""; changed(); return }
            try? store.appendTranscript(["role": .string("sophia"), "session": .string(session), "text": .string(t)])
            streaming = ""
            changed()
        case .toolUse(let id, let name, let input):
            pendingTools[id] = name
            if name == "WebSearch" {
                let q = input["query"]?.string ?? ""
                activity = "Searching: \(q)"
                try? store.appendTranscript(["role": .string("tool"), "session": .string(session), "tool": .string("WebSearch"), "query": .string(q)])
                changed()
            } else if name == "mcp__sophia__write_page" {
                activity = "Sophia is writing “\(input["title"]?.string ?? "a page")”…"
            }
        case .toolResult(let id):
            // Sophia's tools write the notebook files themselves; pick up what they wrote.
            guard let name = pendingTools.removeValue(forKey: id), name.hasPrefix("mcp__sophia__") else { break }
            let before = Set(store.pageWrites.compactMap { $0.str("id") })
            let goalsBefore = Set(store.learning.compactMap { $0.str("id") })
            store.reload()
            library.reload()
            if name == "mcp__sophia__set_goal" {
                for g in store.learning where g.str("kind") == "goal" && !goalsBefore.contains(g.str("id") ?? "") {
                    try? store.appendTranscript(["role": .string("client"), "session": .string(session),
                                                 "purpose": .string("goal_noted"), "record": g["id"]!])
                }
            }
            if name == "mcp__sophia__write_page" {
                activity = nil
                let new = store.pageWrites.filter { !before.contains($0.str("id") ?? "") }
                for w in new { if let wid = w.str("id") { lastWrites.append(wid) } }
                if let file = new.last?.str("file") { showWrittenPage(file) }
            }
            changed()
        case .turnDone(let isError, let message, let sid):
            turnTexts = []
            isResponding = false
            activity = nil
            streaming = ""
            if let sid, !sid.isEmpty, store.claudeSession != sid { store.claudeSession = sid }
            if isError && !stopping {
                let m = message ?? "Unknown error"
                problem = m.localizedCaseInsensitiveContains("login") || m.localizedCaseInsensitiveContains("auth")
                    ? "Claude Code isn't signed in. Open Terminal, run `claude`, and sign in with your Claude account. (\(m))"
                    : "Sophia stopped with an error: \(m)"
            }
            let failed = isError && !stopping
            stopping = false
            finishRequest(failed: failed)
            changed()
        case .exited(let code, let stderr):
            engine = nil
            if isResponding {
                isResponding = false
                streaming = ""
                if !stopping {
                    problem = "The connection to Claude Code closed (exit \(code)). Your notebook is untouched. \(stderr.split(separator: "\n").last.map(String.init) ?? "")"
                }
                request = nil
                queued = nil
                briefAfterNotes = false
            }
            stopping = false
            changed()
        }
    }

    // MARK: The person's messages

    /// The person can type while notes or a briefing are being written; the message waits for them.
    var canSend: Bool { !isResponding || (request != nil && queued == nil) }
    /// Sophia is answering the person (as opposed to writing notes or a briefing), so Stop applies.
    var isReplying: Bool { isResponding && request == nil }

    func send(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, canSend else { return }
        problem = nil
        lastWrites = []
        lastReleases = []
        lastDeleted = nil
        // A long quiet with the window left open gets no briefing; Sophia is told the time instead.
        let quiet = store.lastConversationAt.map { Date().timeIntervalSince($0) } ?? 0
        // She hears about the person's edits and releases since their previous message with this one.
        let since = (store.transcript.lastIndex(where: NotebookStore.isPersonMessage) ?? -1) + 1
        // And about notation warnings on pages she hasn't heard of yet, once each.
        let music = musicWarnings.keys.sorted().flatMap { musicWarnings[$0]! }.filter { !toldMusic.contains($0) }
        toldMusic.formUnion(music)
        let outgoing = (quiet >= Self.returnGap ? Prompts.afterQuiet(quiet) : "") + Prompts.bookChanges(store, since: since)
            + Prompts.musicWarnings(music) + t
        try? store.appendTranscript(["role": .string("person"), "session": .string(session), "text": .string(t)])
        changed()
        if request != nil {
            // They've started talking, so a briefing would only interrupt.
            queued = outgoing
            briefAfterNotes = false
            if request == .briefing { dropBriefing = true }
            return
        }
        guard ensureEngine() else { return }
        isResponding = true
        engine?.send(outgoing)
    }

    /// Stops the current reply. The next message resumes the same conversation.
    func stop() {
        guard isResponding else { return }
        stopping = true
        engine?.cancel()
        isResponding = false
        streaming = ""
        activity = nil
        request = nil
        try? store.appendTranscript(["role": .string("client"), "session": .string(session), "purpose": .string("stopped")])
        changed()
    }

    // MARK: Checkpoint and briefing

    var hasUncheckpointedMessages: Bool { !store.unnotedMessages.isEmpty }

    /// Coming back after a while: first notes on any messages left without them (the person may
    /// have closed the window without ending the session), then a short briefing.
    private func pickUp() {
        if !store.unnotedMessages.isEmpty, writeNotes(catchUp: true) { briefAfterNotes = true } else { requestBriefing() }
    }

    func endSession() { writeNotes(catchUp: false) }

    @discardableResult
    private func writeNotes(catchUp: Bool) -> Bool {
        let messages = store.unnotedMessages
        guard !isResponding, let last = messages.last?.str("id"), ensureEngine() else { return false }
        request = .checkpoint(through: last, entries: Set(messages.compactMap { $0.str("id") }), catchUp: catchUp)
        requestText = ""
        isResponding = true
        activity = catchUp ? "Writing notes on your last session…" : "Sophia is writing notes on this session…"
        engine?.send(Prompts.checkpoint(store, messages: messages, catchUp: catchUp))
        return true
    }

    func requestBriefing() {
        guard !isResponding, ensureEngine() else { return }
        request = .briefing
        requestText = ""
        dropBriefing = false
        isResponding = true
        activity = "Sophia is reading back over the notebook…"
        engine?.send(Prompts.briefing(store))
    }

    private func finishRequest(failed: Bool) {
        guard let r = request else { return }
        request = nil
        let text = requestText
        requestText = ""
        let checks = RecordChecks(store: store)
        switch r {
        case .checkpoint(_, _, let catchUp) where failed:
            // Nothing is marked as noted, so the next return tries again.
            if catchUp { problem = "Couldn't write notes on your last session. Sophia will try again next time." }
        case .checkpoint(let through, let entries, let catchUp):
            let (items, memory, parsed) = RecordChecks.parseCheckpoint(text)
            let out = checks.check(items, allowedKinds: RecordChecks.checkpointKinds, quoteEntries: entries)
            var kept: [JSON] = []
            for rec in out.kept {
                if let saved = try? store.appendLearning(rec, by: "sophia", session: session) { kept.append(saved["id"]!) }
            }
            var notes = out.notes
            if let memory, let result = try? store.setMemory(memory, session: session) { notes += result.problems }
            if !parsed && !text.isEmpty { notes.append("Sophia's notes weren't in the expected format, so nothing was kept.") }
            try? store.appendTranscript(["role": .string("client"), "session": .string(session), "purpose": .string("checkpoint"),
                                         "through": .string(through), "catch_up": .bool(catchUp),
                                         "kept": .array(kept), "not_kept": .array(notes.map { .string($0) })])
        case .briefing where failed || dropBriefing:
            dropBriefing = false
        case .briefing:
            var obj = RecordChecks.extractJSON(text)?.object ?? [:]
            let said = obj.str("text")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let words = said.split(whereSeparator: { $0.isWhitespace }).count
            if said.isEmpty || words > RecordChecks.briefingWordLimit {
                // Nothing worth picking up, or a recap nobody asked for: say nothing. The entry isn't shown.
                try? store.appendTranscript(["role": .string("client"), "session": .string(session), "purpose": .string("briefing_dropped"),
                                             "words": .number(Double(words))])
                break
            }
            obj["kind"] = .string("briefing")
            let out = checks.check([.object(obj)], allowedKinds: RecordChecks.briefingKinds, session: session)
            if let rec = out.kept.first, let saved = try? store.appendLearning(rec, by: "sophia", session: session) {
                try? store.appendTranscript(["role": .string("sophia"), "session": .string(session), "purpose": .string("briefing"),
                                             "record": saved["id"]!, "text": saved["text"]!, "refs": saved["refs"] ?? .array([])])
            } else {
                try? store.appendTranscript(["role": .string("client"), "session": .string(session), "purpose": .string("briefing_failed"),
                                             "not_kept": .array(out.notes.map { .string($0) })])
            }
        }
        if case .checkpoint = r, briefAfterNotes {
            briefAfterNotes = false
            requestBriefing()
        } else if let q = queued {
            queued = nil
            if ensureEngine() { isResponding = true; engine?.send(q) }
        }
        changed()
    }

    // MARK: Pages Sophia writes

    /// A page Sophia just wrote opens in the book, unless the person is reading another page,
    /// their goals, or the notes there; then the card in the conversation points to it.
    private func showWrittenPage(_ file: String) {
        switch place {
        case .page(let f) where f != file: if !bookShown { place = .page(file) }
        case .goals, .notes, .about: if !bookShown { place = .page(file) }
        default: place = .page(file)
        }
        bookShown = true
    }

    /// Shows a place in the book, opening the book if it is hidden.
    func show(_ p: Place) { place = p; bookShown = true }

    /// The person's undo of a page Sophia wrote. Available until their next message.
    func undoWrite(_ entryID: String) {
        do {
            try store.undoPageWrite(entryID, session: session)
            lastWrites.removeAll { $0 == entryID }
            if case .page(let f) = place, !store.pageFiles.contains(f) { place = .contents }
        } catch { problem = error.localizedDescription }
        changed()
    }

    /// The most recent write to a page, by either author, if the person can still undo it.
    func undoableWrite(for file: String) -> String? {
        lastWrites.last { id in
            store.transcript.first { $0.str("id") == id }?.str("file") == file && !store.isUndone(id) && store.isLatestWrite(id)
        }
    }

    // MARK: The person's edits

    /// A range of a page open in the editor, as it was when the editor opened.
    struct PageEditing: Equatable {
        let id = UUID().uuidString
        let file: String
        var range: NotebookStore.EditRange
        /// Set when a commit was refused because the range changed underneath: what's there now.
        var conflict: NotebookStore.EditRange?
        var atVisibleTop = false
    }

    /// Opens a range for editing. The store records it, so Sophia can't change it until the commit.
    func beginEdit(file: String, key: String, atVisibleTop: Bool = false) {
        guard editing == nil else { return }
        do {
            guard let range = try store.beginEdit(file: file, key: key, session: session) else { return }
            editDraft = nil
            editing = PageEditing(file: file, range: range, atVisibleTop: atVisibleTop)
        } catch { problem = error.localizedDescription }
    }

    /// What the editor reports. Its messages are proposals, checked against the open range.
    /// The reader rendered a page: its tunes' notation warnings now (MUSIC.md).
    func noteMusic(file: String, warnings: [MusicWarnings]) {
        musicWarnings[file] = warnings.isEmpty ? nil : warnings
    }

    func handle(_ event: ReaderEditEvent, file: String) {
        switch event {
        case .open(let key): beginEdit(file: file, key: key)
        case .draft(let id, let text): if id == editing?.id { editDraft = text }
        case .commit(let id, let hash, let text):
            guard let e = editing, id == e.id, hash == e.range.hash, e.conflict == nil, text.utf8.count < 4_000_000 else { return }
            commitEdit(text: text)
        case .commitNow: if editing?.conflict == nil { commitEdit() }
        case .revert(let id): if id == editing?.id { endEditing() }
        case .keepMine(let id): if id == editing?.id { commitEdit() }
        }
    }

    /// Saves the editor's text. Unchanged text writes nothing. If the range changed since the editor
    /// opened, the editor stays open with the person's text and the change is shown, unless this is
    /// Keep mine (or the person is leaving), which commits against what's there now.
    func commitEdit(text: String? = nil) {
        guard var e = editing else { return }
        let t = text ?? editDraft ?? e.range.text
        let base = e.conflict ?? e.range
        do {
            switch try store.editPage(file: e.file, section: base.key, baseHash: base.hash, text: t, session: session) {
            case .saved(let entry):
                if let id = entry.str("id") { lastWrites.append(id) }
                endEditing()
            case .unchanged:
                endEditing()
            case .conflict(nil):
                // The range is gone from the page (undone, or the page removed). Nothing is discarded:
                // the person's text stays here, selectable, to put back where they want it.
                endEditing()
                problem = "The part of the page you were editing is gone, so your edit wasn't saved. Your text:\n\n" + t
            case .conflict(let current?):
                e.conflict = current
                editDraft = t
                _ = try store.beginEdit(file: e.file, key: current.key, session: session)
                editing = e
            }
        } catch { problem = "Your edit couldn't be saved: \(error.localizedDescription)" }
        changed()
    }

    private func endEditing() {
        store.endEdit()
        editing = nil
        editDraft = nil
    }

    /// ⌘E: the whole page, with the caret where the person is reading.
    func editWholePage() {
        guard bookShown, case .page(let file) = place else { return }
        beginEdit(file: file, key: "(page)", atVisibleTop: true)
    }

    /// The person lets Sophia change the lines a refused revision ran into. Undoable until their next message.
    func release(_ refusal: JSONObject) {
        let edits = (refusal["edits"]?.array ?? []).compactMap(\.string)
        do { lastReleases += try store.releaseEdits(edits, session: session).compactMap { $0.str("id") } }
        catch { problem = error.localizedDescription }
        changed()
    }

    func undoRelease(_ refusal: JSONObject) {
        let edits = Set((refusal["edits"]?.array ?? []).compactMap(\.string))
        for id in lastReleases where edits.contains(store.transcript.first { $0.str("id") == id }?.str("entry") ?? "") {
            try? store.undoRelease(id, session: session)
            lastReleases.removeAll { $0 == id }
        }
        changed()
    }

    // MARK: The person's records

    func addGoal(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        try? store.appendLearning(["kind": .string("goal"), "text": .string(t), "status": .string("working"), "criteria": .array([])], by: "person", session: session)
        changed()
    }

    /// Rewording, adding a criterion, or changing status is a new goal record that replaces the old one.
    func updateGoal(_ goal: JSONObject, text: String? = nil, status: String? = nil, addCriterion: String? = nil) {
        var next: JSONObject = ["kind": .string("goal"), "replaces": goal["id"]!,
                                "text": .string(text ?? goal.str("text") ?? ""),
                                "status": .string(status ?? goal.str("status") ?? "working")]
        var criteria = goal["criteria"]?.array ?? []
        if let c = addCriterion?.trimmingCharacters(in: .whitespacesAndNewlines), !c.isEmpty { criteria.append(.string(c)) }
        next["criteria"] = .array(criteria)
        try? store.appendLearning(next, by: "person", session: session)
        changed()
    }

    /// The person confirms a goal Sophia recorded: the same goal, now theirs.
    func confirmGoal(_ goal: JSONObject) {
        var next: JSONObject = ["kind": .string("goal"), "replaces": goal["id"]!]
        for k in ["text", "status", "criteria"] { if let v = goal[k] { next[k] = v } }
        try? store.appendLearning(next, by: "person", session: session)
        changed()
    }

    /// The person turns down a goal Sophia recorded. A new goal is removed; a revision of a goal
    /// goes back to the version before it.
    func discardGoal(_ goal: JSONObject) {
        guard let id = goal.str("id") else { return }
        if let prevID = goal.str("replaces"), let prev = store.record(prevID) {
            var back: JSONObject = ["kind": .string("goal"), "replaces": .string(id)]
            for k in ["text", "status", "criteria"] { if let v = prev[k] { back[k] = v } }
            try? store.appendLearning(back, by: prev.str("by") ?? "person", session: session)
        } else {
            if let removed = try? store.deleteLearning(id) { lastDeleted = removed }
        }
        changed()
    }

    // MARK: About you and links (library-wide)

    func confirmAbout(_ line: JSONObject) {
        try? library.setAbout(text: line.str("text") ?? "", replacing: line.str("id"), notebook: nil)
        changed()
    }

    func editAbout(_ line: JSONObject?, text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        try? library.setAbout(text: t, replacing: line?.str("id"), notebook: line == nil ? store.name : nil)
        changed()
    }

    func deleteAbout(_ id: String) { try? library.deleteAbout(id); changed() }
    func confirmLink(_ id: String) { try? library.confirmLink(id); changed() }
    func removeLink(_ id: String) { try? library.deleteLink(id); changed() }

    /// The other end of a link, seen from this notebook.
    func otherEnd(of link: JSONObject) -> (notebook: String, page: String?, section: String?)? {
        let from = link["from"]?.object, to = link["to"]?.object
        if from?.str("notebook") == store.name, let n = to?.str("notebook") { return (n, to?.str("page"), to?.str("section")) }
        if to?.str("notebook") == store.name, let n = from?.str("notebook") { return (n, from?.str("page"), from?.str("section")) }
        return nil
    }

    /// This end of a link: the page (and section) here.
    func nearEnd(of link: JSONObject) -> (page: String?, section: String?) {
        let side = link["from"]?["notebook"]?.string == store.name ? link["from"] : link["to"]
        return (side?["page"]?.string, side?["section"]?.string)
    }

    func setSeparate(_ on: Bool) { try? store.setSeparate(on); changed() }

    func correct(_ recordID: String, text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        try? store.appendLearning(["kind": .string("correction"), "replaces": .string(recordID), "text": .string(t)], by: "person", session: session)
        changed()
    }

    func delete(_ recordID: String) {
        if let removed = try? store.deleteLearning(recordID) { lastDeleted = removed }
        changed()
    }

    func undoDelete() {
        if let r = lastDeleted { try? store.restoreLearning(r) }
        lastDeleted = nil
        changed()
    }
}
