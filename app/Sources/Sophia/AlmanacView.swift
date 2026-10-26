import SwiftUI
import AppKit
import SophiaCore

/// App-lifetime UI coordination. Preparation never replaces the visible NotebookSession.
@MainActor
final class AlmanacModel: ObservableObject {
    let root: URL
    let connection: ConnectionState
    let notifications: AlmanacNotifications
    @Published private(set) var worker: AlmanacPreparation?
    @Published private(set) var configured: [URL] = []
    @Published var settingsShown = false
    @Published var problem: String?
    var ordinaryBusy: () -> Bool = { false }
    var onSaved: ((AlmanacEntry) -> Void)?
    private let preferences: UserDefaults
    private let targetKey: String
    private var timer: Timer?
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var awake = true
    private var stopped = false

    init(root: URL, connection: ConnectionState) {
        self.root = root; self.connection = connection
        #if DEBUG
        if let fixture = ProcessInfo.processInfo.environment["SOPHIA_UX_HARNESS"] {
            preferences = UserDefaults(suiteName: "Sophia.AlmanacFixture." + Data(fixture.utf8).base64EncodedString())!
        } else { preferences = .standard }
        #else
        preferences = .standard
        #endif
        let key = "Sophia.Almanac." + Data(root.path.utf8).base64EncodedString()
        targetKey = key + ".notebook"
        notifications = AlmanacNotifications(preferences: preferences, key: key)
        discover()
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common); self.timer = timer
        observe(NSWorkspace.shared.notificationCenter, NSWorkspace.didWakeNotification) { $0.awake = true; $0.tick() }
        observe(NSWorkspace.shared.notificationCenter, NSWorkspace.willSleepNotification) { $0.awake = false }
        observe(.default, NSApplication.didBecomeActiveNotification) { $0.notifications.refresh(); $0.tick() }
        observe(.default, .prepareToTerminate) { $0.shutdown() }
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name, action: @escaping (AlmanacModel) -> Void) {
        let observer = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { if let self { action(self) } }
        }
        observers.append((center, observer))
    }

    func discover() {
        guard !stopped else { return }
        configured = Library(root: root).notebooks.filter { Almanac.isConfigured(url: $0) }
        if let worker {
            guard configured.contains(worker.url) else {
                worker.shutdown(); self.worker = nil
                problem = "The Almanac notebook is no longer available. Its existing pages have not been replaced."
                return
            }
            worker.refresh(); return
        }
        let remembered = preferences.string(forKey: targetKey)
        if let url = configured.first(where: { $0.lastPathComponent == remembered }) ?? (configured.count == 1 ? configured.first : nil) {
            attach(url)
        }
    }

    func attach(_ url: URL) {
        guard !stopped, configured.contains(url), Almanac.isConfigured(url: url) else { return }
        do {
            let next = try AlmanacPreparation(url: url)
            worker?.shutdown(); install(next)
        } catch { problem = error.localizedDescription }
    }

    private func install(_ next: AlmanacPreparation) {
        worker = next
        preferences.set(next.url.lastPathComponent, forKey: targetKey)
        next.onReady = { [weak self] entry in
            self?.problem = nil
            self?.onSaved?(entry)
            self?.notifications.entrySaved(id: entry.id)
        }
    }

    var proposedName: String {
        let base = "Sophia’s Almanac"
        var candidate = base, suffix = 2
        while FileManager.default.fileExists(atPath: root.appendingPathComponent(candidate).path)
            || (try? FileManager.default.destinationOfSymbolicLink(atPath: root.appendingPathComponent(candidate).path)) != nil {
            candidate = "\(base) (\(suffix))"; suffix += 1
        }
        return candidate
    }

    func save(_ settings: AlmanacSettings) {
        guard !stopped else { return }
        do {
            if let worker {
                try worker.configure(settings)
            } else {
                guard configured.isEmpty else { problem = "Choose an existing Almanac notebook first."; return }
                // Name alone never identifies an Almanac. The explicit Enable action creates
                // a fresh unique notebook, then writes its opt-in configuration.
                let url = try Library(root: root).create(named: proposedName)
                let next = try AlmanacPreparation(url: url)
                try next.configure(settings)
                install(next); configured = [url]
            }
            if !settings.enabled { notifications.disable() }
            problem = nil; settingsShown = false
            tick()
        } catch { problem = error.localizedDescription }
    }

    func tick() {
        guard !stopped, awake, Snapshot.outDir == nil else { return }
        discover()
        guard !ordinaryBusy() else { return }
        worker?.tick(acknowledged: connection.acknowledged)
    }

    func prepare() {
        guard !stopped else { return }
        guard connection.acknowledged else {
            problem = "Review Connection & Data before preparing an entry. Closing that information does not start preparation."
            connection.detailsShown = true; return
        }
        problem = nil; worker?.prepare(acknowledged: true)
    }

    func showSettings() { settingsShown = true }

    func disable() {
        guard var settings = worker?.snapshot.settings else { return }
        settings.enabled = false; save(settings)
    }

    func shutdown() {
        guard !stopped else { return }
        stopped = true; timer?.invalidate(); timer = nil
        worker?.shutdown()
        for (center, observer) in observers { center.removeObserver(observer) }
        observers = []
    }
}

struct AlmanacSettingsView: View {
    @ObservedObject var almanac: AlmanacModel
    @State private var selected: Set<String> = []
    @State private var topics = ""
    @State private var automatic = false
    @State private var paused = false
    @State private var minute = 540

    private var targetSeparate: Bool {
        guard let url = almanac.worker?.url else { return false }
        return ExistingNotebook(root: almanac.root, name: url.lastPathComponent)?.isSeparate ?? true
    }
    private var eligible: [String] {
        targetSeparate ? [] : Almanac.eligibleNotebookNames(root: almanac.root, excluding: almanac.worker?.url.lastPathComponent ?? almanac.proposedName)
    }
    private var unavailable: [String] { targetSeparate ? [] : selected.filter { !eligible.contains($0) }.sorted() }
    private var time: Binding<Date> {
        Binding(get: {
            Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: minute / 60, minute: minute % 60)) ?? Date()
        }, set: { minute = Calendar.current.component(.hour, from: $0) * 60 + Calendar.current.component(.minute, from: $0) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Sophia’s Almanac").font(.system(size: 26, weight: .semibold, design: .serif))
            Text("A small, finished discovery to read. No quiz, streak, or required reply.").foregroundStyle(.secondary)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if almanac.configured.count > 1 {
                        Text("Choose the Almanac notebook to use.").font(.headline)
                        ForEach(almanac.configured, id: \.self) { url in
                            Button(url.lastPathComponent) { almanac.attach(url); load() }
                        }
                    }
                    Text(targetSeparate ? "Choose a topic" : "Draw themes from these notebook titles").font(.headline)
                    Text(targetSeparate
                         ? "This Almanac is kept separate. Your typed topics guide it; earlier Almanac entry titles help avoid repetition. Other notebooks are not included. Change that choice in its Contents if you want notebook-title themes."
                         : "The selected notebook names, your topics and earlier Almanac entry titles go to Claude for curation—not the source notebooks’ pages, conversations, goals or personal assessments. Notebooks kept separate are excluded.")
                        .font(.callout).foregroundStyle(.secondary)
                    if eligible.isEmpty && !targetSeparate { Text("No eligible notebooks. You can start with a topic below.").font(.callout) }
                    ForEach(eligible, id: \.self) { name in
                        Toggle(name, isOn: Binding(get: { selected.contains(name) }, set: { if $0 { selected.insert(name) } else { selected.remove(name) } }))
                    }
                    ForEach(unavailable, id: \.self) { name in
                        HStack { Text("No longer available: \(name)").foregroundStyle(.secondary); Spacer(); Button("Remove") { selected.remove(name) } }
                    }
                    TextField("Topics or directions (optional)", text: $topics, axis: .vertical).lineLimit(2...4)
                    Toggle("Prepare daily while Sophia stays open", isOn: $automatic)
                    if automatic {
                        Toggle("Pause daily preparation", isOn: $paused)
                        DatePicker("Prepare around", selection: time, displayedComponents: .hourAndMinute)
                        Text("When this Mac is awake. Missed days make no backlog; one waiting entry pauses automatic accumulation. Manual preparation stays available.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Text("Enabling authorizes Sophia to write entries only in this Almanac notebook, using your existing Claude connection and usage. Entries may use web-search summaries or general explanation; this is not verified source text. Ordinary notebooks remain yours to direct.")
                        .font(.callout).fixedSize(horizontal: false, vertical: true)
                    if almanac.worker == nil {
                        Text("Creates a new notebook: “\(almanac.proposedName)”. Existing notebooks with that name are kept.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if almanac.worker != nil {
                        Divider()
                        AlmanacNotificationControls(notifications: almanac.notifications)
                    }
                    if let problem = almanac.problem { Text(problem).foregroundStyle(.red).font(.callout) }
                }
            }
            if almanac.worker != nil {
                Text("Saving changes cancels any preparation in progress. Saved entries stay available.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Button("Cancel") { almanac.settingsShown = false }.keyboardShortcut(.cancelAction)
                if almanac.worker?.snapshot.settings?.enabled == true {
                    Button("Disable preparation") { almanac.disable(); almanac.settingsShown = false }
                }
                Spacer()
                Button(almanac.worker?.snapshot.settings?.enabled == true ? "Save changes" : "Enable Almanac") {
                    almanac.save(AlmanacSettings(enabled: true, automatic: automatic, paused: paused,
                        selectedNotebooks: targetSeparate ? [] : selected.sorted(), topics: topics, automaticMinute: minute))
                }
                .keyboardShortcut(.defaultAction)
                .disabled(((targetSeparate || selected.isEmpty) && topics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) || !unavailable.isEmpty)
            }
        }
        .padding(20).frame(width: 550, height: 550)
        .onAppear { almanac.discover(); load() }
        .onChange(of: almanac.worker?.url) { _, _ in load() }
    }

    private func load() {
        let settings = almanac.worker?.snapshot.settings
        selected = Set(settings?.selectedNotebooks ?? [])
        topics = settings?.topics ?? ""; automatic = settings?.automatic ?? false; paused = settings?.paused ?? false
        minute = settings?.automaticMinute ?? 540
    }
}

struct AlmanacHomeControls: View {
    @ObservedObject var worker: AlmanacPreparation
    @ObservedObject var almanac: AlmanacModel
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button("Prepare a new entry") { almanac.prepare() }
                    .disabled(worker.snapshot.phase == .preparing || worker.snapshot.settings?.enabled != true)
                Button("Preparation & notifications…") { almanac.showSettings() }
                if worker.snapshot.phase == .preparing { Button("Cancel preparation") { worker.cancel() } }
            }.buttonStyle(.borderless)
            if worker.snapshot.phase == .preparing {
                Text(worker.activity ?? "Preparing a new entry…").font(.caption).foregroundStyle(.secondary)
            } else if worker.snapshot.settings?.enabled != true {
                Text("Preparation is disabled. Your saved entries remain here.").font(.caption).foregroundStyle(.secondary)
            } else if worker.snapshot.settings?.automatic == true {
                Text(worker.snapshot.settings?.paused == true ? "Daily preparation is paused." : "Daily preparation is enabled while Sophia is open and this Mac is awake.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let problem = almanac.problem ?? worker.problem ?? worker.snapshot.problem {
                Text(problem).font(.callout).foregroundStyle(.red).textSelection(.enabled)
            }
        }
    }
}

struct AlmanacReadyControl: View {
    @ObservedObject var worker: AlmanacPreparation
    let read: (AlmanacEntry) -> Void
    var body: some View {
        if let entry = worker.snapshot.waitingEntry {
            Button("New Almanac entry") { read(entry) }.help(entry.title)
        }
    }
}

struct AlmanacNotificationControls: View {
    @ObservedObject var notifications: AlmanacNotifications
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if notifications.enabled && notifications.permission == .allowed {
                Button("Turn off Almanac notifications") { notifications.disable() }
            } else {
                Button("Enable notifications…") { notifications.enable() }.disabled(notifications.requesting)
            }
            Text("Optional generic alert after an entry is saved. No topic appears in the notification.").font(.caption).foregroundStyle(.secondary)
            if let problem = notifications.problem { Text(problem).font(.caption).foregroundStyle(.secondary) }
        }
    }
}
