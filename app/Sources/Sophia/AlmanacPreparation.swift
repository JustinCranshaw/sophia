import Foundation
import SwiftUI
import SophiaCore

/// One app-owned preparation, independent of the person's conversation queue.
@MainActor
final class AlmanacPreparation: ObservableObject {
    let url: URL
    @Published private(set) var snapshot: AlmanacSnapshot
    @Published private(set) var activity: String?
    @Published private(set) var problem: String?
    var onReady: ((AlmanacEntry) -> Void)?
    private let store: NotebookStore
    private var engine: ClaudeEngine?
    private var run: AlmanacReservation?
    private var text = ""
    private var evidence: [AlmanacSearchEvidence] = []
    private var terminating: Any?
    private var closed = false
    private static let reopenAfterStorageFailure = "Preparation stopped, but its state could not be saved. After resolving the storage problem, quit and reopen Sophia before preparing again."
    private let session: String

    init(url: URL) throws {
        guard let existing = ExistingNotebook(root: url.deletingLastPathComponent(), name: url.lastPathComponent) else { throw AlmanacError.notConfigured }
        let configured = Almanac.isConfigured(url: url)
        guard configured || existing.pageFiles.isEmpty else { throw AlmanacError.notConfigured }
        let store = try configured ? NotebookStore.open(url: url) : NotebookStore(url: url)
        guard configured || (store.pageFiles.isEmpty && store.transcript.isEmpty && store.learning.isEmpty) else { throw AlmanacError.notConfigured }
        self.url = url; self.store = store; self.session = store.newSessionID()
        try store.reconcileAlmanac(interrupted: true)
        snapshot = store.almanacSnapshot
        terminating = NotificationCenter.default.addObserver(forName: .prepareToTerminate, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.shutdown() }
        }
    }
    deinit {
        engine?.stop()
        if let terminating { NotificationCenter.default.removeObserver(terminating) }
    }
    func configure(_ settings: AlmanacSettings) throws {
        cancel()
        try store.configureAlmanac(settings)
        problem = nil; refresh()
    }
    func refresh() {
        guard !closed else { return }
        store.reload()
        if let run, !store.almanacRunIsCurrent(run) { cancel() }
        do {
            try store.reconcileAlmanac(); snapshot = store.almanacSnapshot
            problem = snapshot.phase == .preparing && engine == nil && run == nil ? Self.reopenAfterStorageFailure : nil
        }
        catch { problem = "Could not refresh Almanac preparation state." }
    }
    func tick(acknowledged: Bool, now: Date = Date(), calendar: Calendar = .current) {
        begin(manual: false, acknowledged: acknowledged, now: now, calendar: calendar)
    }
    func prepare(acknowledged: Bool, now: Date = Date(), calendar: Calendar = .current) {
        begin(manual: true, acknowledged: acknowledged, now: now, calendar: calendar)
    }
    private func begin(manual: Bool, acknowledged: Bool, now: Date, calendar: Calendar) {
        guard !closed else { return }
        let previousEntry = snapshot.latestEntry?.id
        refresh()
        guard problem != Self.reopenAfterStorageFailure else { return }
        // A Retry that discovers its already-recorded page only exposes that page.
        if snapshot.latestEntry?.id != previousEntry, snapshot.waitingEntry != nil { return }
        guard engine == nil else { return }
        do {
            guard let reservation = try store.reserveAlmanac(manual: manual, acknowledged: acknowledged, now: now, calendar: calendar) else {
                snapshot = store.almanacSnapshot; return
            }
            run = reservation; text = ""; evidence = []; problem = nil
            snapshot = store.almanacSnapshot
            guard let claude = ClaudeEngine.locateClaude(), let executable = Bundle.main.executableURL else {
                fail("Claude Code is unavailable. Check Connection & Data, then choose Retry."); return
            }
            let tools = executable.deletingLastPathComponent().appendingPathComponent("sophia-mcp").path
            let e = ClaudeEngine(config: .init(claudePath: claude, toolServerPath: tools, notebookURL: url,
                systemPrompt: AlmanacPrompt.system, context: AlmanacPrompt.context(reservation), session: session, almanac: true))
            engine = e
            e.onEvent = { [weak self, weak e] event in
                guard let self, let e, self.engine === e, self.run?.id == reservation.id else { return }
                self.handle(event)
            }
            try e.start()
            // No content is sent until the existing per-request intended-route check passes.
            e.send(AlmanacPrompt.request)
            activity = "Preparing an Almanac entry…"
        } catch {
            if run != nil { fail(error.localizedDescription) }
            else { problem = error.localizedDescription; snapshot = store.almanacSnapshot }
        }
    }
    private func handle(_ event: ClaudeEngine.Event) {
        switch event {
        case .started(_, let source, _, _):
            if source != "none" { fail("The intended claude.ai connection could not be verified. Check Connection & Data, then Retry.") }
        case .assistantText(let block): text += block
        case .toolUse(_, let name, _):
            if name == "WebSearch" { activity = "Finding search summaries…" }
            else { fail("Preparation requested an unavailable tool. No entry was marked ready.") }
        case .searchResult(let result):
            guard let run else { return }
            do {
                try store.recordAlmanacSearch(result, run: run, session: session)
                evidence.append(result)
            } catch { fail("Search evidence could not be saved. No entry was marked ready.") }
        case .turnDone(let isError, _, _):
            guard !isError, let run else { fail("Preparation stopped without a complete entry. Choose Retry when ready."); return }
            do {
                let draft = try AlmanacDraft.parse(text)
                let entry = try store.saveAlmanac(draft, evidence: evidence, run: run, session: session)
                self.run = nil; engine?.stop(); engine = nil; activity = nil; text = ""; evidence = []
                snapshot = store.almanacSnapshot; problem = nil
                onReady?(entry)
            } catch { fail((error as? AlmanacError)?.localizedDescription ?? AlmanacError.uncertainSave.localizedDescription) }
        case .routeBlocked:
            fail("The intended claude.ai connection could not be verified. Check Connection & Data, then choose Retry. This preparation was not sent.")
        case .exited:
            fail("The connection closed before a complete entry was saved. Choose Retry when ready.")
        case .textDelta, .toolResult, .sourcePermission, .sourceResult: break
        }
    }
    private func fail(_ message: String, cancelled: Bool = false) {
        let pending = run
        run = nil; engine?.cancel(); engine = nil; activity = nil; text = ""; evidence = []
        if let pending {
            do { try store.failAlmanac(pending, message: message, cancelled: cancelled) }
            catch { problem = Self.reopenAfterStorageFailure }
        }
        snapshot = store.almanacSnapshot
        if problem == nil { problem = message }
    }
    func cancel() {
        guard run != nil || engine != nil else { return }
        fail("Preparation was cancelled. Choose Retry when ready.", cancelled: true)
    }
    func acknowledgeOpening(file: String) {
        do { try store.acknowledgeAlmanacOpening(file: file); snapshot = store.almanacSnapshot }
        catch { problem = "Could not record opening this entry. Earlier pages remain available." }
    }
    func quiesceForRemoval(_ completion: @escaping () -> Void) {
        let active = engine
        shutdown()
        if let active { active.whenStopped(completion) } else { DispatchQueue.main.async(execute: completion) }
    }
    func shutdown() { cancel(); closed = true }
}
