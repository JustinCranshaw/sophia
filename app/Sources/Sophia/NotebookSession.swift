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
    @Published var place: Place = .contents { didSet {
        switch place { case .contents: activeThread = ""; case .page(let file): activeThread = file; default: break }
        if case .page(let f) = place, f == editing?.file { return }; commitEdit()
    } }
    @Published private(set) var activeThread = ""
    var conversationName: String { activeThread.isEmpty ? "Contents" : store.readPage(activeThread)?.title ?? activeThread }
    var visibleActivity: String? { running?.thread == activeThread && request == nil ? activity : nil }
    var visibleThinking: Bool { isResponding && running?.thread == activeThread && request == nil }
    var visibleStreaming: String { running?.thread == activeThread && request == nil ? streaming : "" }
    @Published var bookShown = true { didSet { if !bookShown { commitEdit() } } }
    @Published var streaming = ""
    @Published var isResponding = false
    @Published var activity: String?
    @Published var problem: String?
    @Published var editing: PageEditing?             // the range of a page open in the editor
    @Published var composerFocused = false           // the conversation's composer has focus; an open editor's strip dims
    @Published var lastDeleted: [JSONObject]?        // records; Undo lasts until the next message
    @Published var pendingSection: String?           // a section to scroll to once its page is laid out

    private var engine: ClaudeEngine?
    private var engines: [String: ClaudeEngine] = [:]
    private struct Turn { let id: String; let thread: String; let text: String }
    private var running: Turn?
    private var queue: [Turn] = []
    private var checkpointEngine: ClaudeEngine?
    func isPending(_ thread: String) -> Bool { NotebookStore.isPending(thread: thread, running: running?.thread, queued: queue.map(\.thread)) }
    private var request: Request?
    private var requestText = ""
    private var pendingTools: [String: String] = [:]
    private var turnTexts: [String] = []                // Sophia's text blocks in the current reply
    private var briefAfterNotes = false
    private var dropBriefing = false
    private var musicWarnings: [String: [MusicWarnings]] = [:]   // each page's current notation warnings, as last rendered
    private var toldMusic: Set<MusicWarnings> = []                // those Sophia has been told about this session
    private var editDraft: String?          // the editor's live text; not published, so typing doesn't redraw the window
    private var terminating: Any?

    init(url: URL) throws {
        store = try NotebookStore.open(url: url)
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
        engines.values.forEach { $0.stop() }; checkpointEngine?.stop()
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

    private func ensureEngine(thread: String, before: String? = nil, internalRequest: Bool = false) -> Bool {
        if !internalRequest, let e = engines[thread], e.isRunning { engine = e; return true }
        guard let claude = ClaudeEngine.locateClaude() else { if !internalRequest { problem = "Install Claude Code and sign in to continue." }; return false }
        guard let prompt = Self.sophiaPrompt() else { if !internalRequest { problem = "SOPHIA.md is missing from the app." }; return false }
        let tools = Bundle.main.executableURL!.deletingLastPathComponent().appendingPathComponent("sophia-mcp").path
        let e = ClaudeEngine(config: .init(claudePath: claude, toolServerPath: tools, notebookURL: store.url,
                                           systemPrompt: prompt, context: Prompts.context(store, thread: thread, before: before),
                                           session: session, page: thread, readOnly: internalRequest))
        let identity = ObjectIdentifier(e)
        e.onEvent = { [weak self] event in self?.handle(event, identity: identity, thread: thread, internalRequest: internalRequest) }
        do { try e.start() } catch { if !internalRequest { problem = "Couldn't start Claude Code: \(error.localizedDescription)" }; return false }
        if internalRequest { checkpointEngine = e } else { engines[thread] = e }
        engine = e
        return true
    }

    func shutdown() { commitEdit(); engines.values.forEach { $0.stop() }; checkpointEngine?.stop(); engines = [:]; engine = nil }

    private func handle(_ event: ClaudeEngine.Event, identity: ObjectIdentifier, thread: String, internalRequest: Bool) {
        // A terminating process may report its exit after a replacement has started.
        let source = internalRequest ? checkpointEngine : engines[thread]
        guard let source, ObjectIdentifier(source) == identity else { return }
        let current = engine.map { ObjectIdentifier($0) == identity } == true
        switch event {
        case .started(_, let source, _, _):
            if source != "none" {
                engine?.cancel()
                if internalRequest { checkpointEngine = nil } else { engines[thread] = nil }
                engine = nil; running = nil; request = nil; isResponding = false; streaming = ""; activity = nil
                queue = []; pendingTools = [:]; turnTexts = []; requestText = ""; briefAfterNotes = false; dropBriefing = false
                problem = "Claude Code is set to use an API key (\(source)), which bills separately. Sophia won't continue on it."
                changed()
            }
        case .textDelta(let t):
            if current && !internalRequest { streaming += t }
        case .assistantText(let t):
            guard current else { return }
            if internalRequest { requestText += t; return }
            // Suppress only verbatim repeats; a similar block may answer an outstanding question.
            defer { turnTexts.append(t) }
            if Prompts.isRestatement(t, of: turnTexts) { streaming = ""; changed(); return }
            try? store.appendTranscript(["role": .string("sophia"), "page": .string(thread), "session": .string(session), "text": .string(t)])
            streaming = ""; changed()
        case .toolUse(let id, let name, let input):
            guard current else { return }
            pendingTools[id] = name
            if name == "WebSearch" {
                let q = input["query"]?.string ?? ""
                activity = "Searching: \(q)"
                try? store.appendTranscript(["role": .string("tool"), "page": .string(thread), "session": .string(session), "tool": .string("WebSearch"), "query": .string(q)])
            } else if name == "mcp__sophia__write_page" { activity = "Sophia is writing…" }
            changed()
        case .toolResult(let id):
            guard current, let name = pendingTools.removeValue(forKey: id), name.hasPrefix("mcp__sophia__") else { return }
            store.reload(); library.reload()
            // A saved page has an Open action in the conversation. Keep the person's book visibility choice.
            changed()
        case .turnDone(let isError, let message, _):
            guard current else { return }
            turnTexts = []; pendingTools = [:]; isResponding = false; activity = nil; streaming = ""
            if isError && !internalRequest { problem = "Sophia stopped with an error: \(message ?? "Unknown error")" }
            if internalRequest { finishRequest(failed: isError) }
            else {
                if !isError && !source.stopRequested, running != nil {
                    try? store.appendTranscript(["role": .string("client"), "page": .string(thread), "session": .string(session), "purpose": .string("replied")])
                }
                running = nil
                dispatchNext()
            }
            changed()
        case .exited(let code, let stderr, let stopRequested):
            if internalRequest { checkpointEngine = nil } else { engines[thread] = nil }
            guard current else { return }
            engine = nil
            if !stopRequested && isResponding {
                if !internalRequest { problem = "The connection to Claude Code closed (exit \(code)). \(stderr.split(separator: "\n").last.map(String.init) ?? "")" }
                isResponding = false; streaming = ""; activity = nil
                if internalRequest { finishRequest(failed: true) } else { running = nil; dispatchNext() }
            }
            changed()
        }
    }

    var canSend: Bool { !isPending(activeThread) }
    var isReplying: Bool { isResponding && request == nil && running?.thread == activeThread }

    func send(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, canSend else { return }
        problem = nil; lastDeleted = nil
        do {
            let entry = try store.appendTranscript(["role": .string("person"), "page": .string(activeThread), "session": .string(session), "text": .string(t)])
            queue.append(Turn(id: entry.str("id")!, thread: activeThread, text: t))
        } catch { problem = error.localizedDescription; return }
        briefAfterNotes = false
        if request == .briefing { dropBriefing = true }
        dispatchNext(); changed()
    }

    private func dispatchNext() {
        while !queue.isEmpty, NotebookStore.nextStep(thread: queue[0].thread, pending: isResponding || request != nil) == .reply {
            let turn = queue.removeFirst()
            // A failed startup leaves its saved message incomplete; it cannot block other threads.
            guard ensureEngine(thread: turn.thread, before: turn.id) else { changed(); continue }
            running = turn; turnTexts = []; isResponding = true
            let music = musicWarnings.keys.sorted().flatMap { musicWarnings[$0]! }.filter { !toldMusic.contains($0) }
            toldMusic.formUnion(music)
            engine?.send(Prompts.turnPrefix(store, thread: turn.thread, before: turn.id) + Prompts.musicWarnings(music) + turn.text)
            return
        }
    }

    func stop() {
        guard let turn = running else { return }
        // Detach first: late output from this process cannot complete or corrupt a replacement.
        engines[turn.thread] = nil; engine?.cancel(); engine = nil
        isResponding = false; running = nil; streaming = ""; activity = nil; turnTexts = []; pendingTools = [:]
        try? store.appendTranscript(["role": .string("client"), "page": .string(turn.thread), "session": .string(session), "purpose": .string("stopped")])
        dispatchNext(); changed()
    }

    var hasUncheckpointedMessages: Bool { !store.unnotedMessages.isEmpty }
    private func pickUp() {
        if !store.unnotedMessages.isEmpty, writeNotes(catchUp: true) { briefAfterNotes = true } else { requestBriefing() }
    }
    func endSession() { writeNotes(catchUp: false) }

    @discardableResult
    private func writeNotes(catchUp: Bool) -> Bool {
        let messages = store.unnotedMessages
        guard !isResponding, let last = messages.last?.str("id"), ensureEngine(thread: "", internalRequest: true) else { return false }
        request = .checkpoint(through: last, entries: Set(messages.compactMap { $0.str("id") }), catchUp: catchUp)
        requestText = ""; isResponding = true; activity = nil
        engine?.send(Prompts.checkpoint(store, messages: messages, catchUp: catchUp))
        return true
    }

    func requestBriefing() {
        guard !isResponding, ensureEngine(thread: "", internalRequest: true) else { return }
        request = .briefing; requestText = ""; dropBriefing = false; isResponding = true; activity = nil
        engine?.send(Prompts.briefing(store))
    }

    private func finishRequest(failed: Bool) {
        guard let r = request else { return }
        request = nil
        let text = requestText; requestText = ""
        // Detach before stopping: its expected exit cannot clear the next conversation process.
        let finished = checkpointEngine; checkpointEngine = nil; engine = nil; finished?.stop()
        switch r {
        case .checkpoint(let through, let entries, let catchUp):
            let result = try? store.finishCheckpoint(text, failed: failed, through: through, entries: entries, session: session, catchUp: catchUp)
            if result == .saved { engines.values.forEach { $0.stop() }; engines = [:] }
            else { briefAfterNotes = false }
        case .briefing:
            if !failed && !dropBriefing, var obj = RecordChecks.extractJSON(text)?.object {
                obj["kind"] = .string("briefing")
                let out = RecordChecks(store: store).check([.object(obj)], allowedKinds: RecordChecks.briefingKinds, session: session)
                if let rec = out.kept.first, let saved = try? store.appendLearning(rec, by: "sophia", session: session) {
                    try? store.appendTranscript(["role": .string("sophia"), "page": .string(""), "session": .string(session), "purpose": .string("briefing"), "record": saved["id"]!, "text": saved["text"]!, "refs": saved["refs"] ?? .array([])])
                }
            }
            dropBriefing = false
        }
        if briefAfterNotes { briefAfterNotes = false; requestBriefing() } else { dispatchNext() }
        changed()
    }

    // MARK: Pages Sophia writes

    /// Shows a place in the book, opening the book if it is hidden.
    func show(_ p: Place) { place = p; bookShown = true }

    /// Undo the latest eligible action, rechecked under the notebook lock.
    func undoWrite(_ entryID: String) {
        do {
            if let e = store.transcript.first(where: { $0.str("id") == entryID }), store.isReleaseUndoable(e) { try store.undoRelease(entryID, session: session) }
            else { try store.undoPageWrite(entryID, session: session) }
            if case .page(let f) = place, !store.pageFiles.contains(f) { place = .contents }
        } catch { problem = error.localizedDescription }
        changed()
    }

    /// The most recent write to a page, by either author, if the person can still undo it.
    func undoableWrite(for file: String) -> String? {
        guard let e = store.latestPageAction(for: file), store.isUndoable(e) || store.isReleaseUndoable(e) else { return nil }
        return e.str("id")
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
            case .saved:
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

    /// Permission applies on the next message; it remains undoable until the next page action.
    func release(_ editID: String) {
        do { _ = try store.releaseEdits([editID], session: session) }
        catch { problem = error.localizedDescription }
        changed()
    }

    func undoRelease(_ releaseID: String) {
        do { try store.undoRelease(releaseID, session: session) }
        catch { problem = error.localizedDescription }
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
