import SwiftUI
import AppKit
import SophiaCore
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        if Bundle.main.bundleIdentifier != nil, Snapshot.outDir == nil { UNUserNotificationCenter.current().delegate = self }
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == UNNotificationDefaultActionIdentifier,
           let id = response.notification.request.content.userInfo["almanacEntryID"] as? String {
            DispatchQueue.main.async { NotificationCenter.default.post(name: .openAlmanacEntry, object: id) }
        }
        completionHandler()
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Needed when run from `swift run` without an app bundle.
        // A snapshot run must not take keyboard focus from whatever the person is doing.
        if Snapshot.outDir == nil {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
        #if DEBUG
        UXHarness.startIfRequested()
        #endif
    }
    weak var model: AppModel?
    weak var workspaceWindow: NSWindow?
    private var terminating = false
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !terminating else { return .terminateLater }
        guard model?.prepareForClosing() != false else {
            workspaceWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return .terminateCancel
        }
        terminating = true
        NotificationCenter.default.post(name: .prepareToTerminate, object: nil)
        OwnedClaudeProcess.finishForApplicationTermination { sender.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

final class AppModel: ObservableObject {
    let library: Library
    let connection: ConnectionState
    let almanac: AlmanacModel
    @Published var notebooks: [URL] = []
    @Published var open: NotebookSession?
    private var aboutSession: NotebookSession?
    @Published private(set) var sharedAboutStore: NotebookStore?
    @Published var problem: String?
    @Published var notebookSettings: NotebookSettingsSelection?
    private let preferences: UserDefaults
    @Published var conversationCollapsed: Bool {
        didSet { preferences.set(conversationCollapsed, forKey: "conversationCollapsed") }
    }

    init() {
        #if DEBUG
        if let fixture = ProcessInfo.processInfo.environment["SOPHIA_UX_HARNESS"] {
            preferences = UserDefaults(suiteName: "Sophia.WorkspaceFixture." + Data(fixture.utf8).base64EncodedString())!
        } else { preferences = .standard }
        #else
        preferences = .standard
        #endif
        conversationCollapsed = preferences.bool(forKey: "conversationCollapsed")
        let library = Library(), connection = ConnectionState()
        self.library = library; self.connection = connection
        sharedAboutStore = try? LibraryStore(root: library.root).ensureSharedAboutPage(session: "library-open").store
        almanac = MainActor.assumeIsolated { AlmanacModel(root: library.root, connection: connection) }
        notebooks = library.notebooks
        if let first = notebooks.first { openNotebook(first, at: .contents) }
        MainActor.assumeIsolated {
            almanac.ordinaryBusy = { [weak self] in self?.open?.isResponding == true || self?.aboutSession?.isResponding == true }
            almanac.onSaved = { [weak self] _ in
                guard let self else { return }
                notebooks = library.notebooks
                if let current = open, current.store.url == almanac.worker?.url {
                    current.objectWillChange.send()
                    current.store.reload()
                }
            }
        }
        Snapshot.run(model: self)
    }

    @discardableResult
    func openNotebook(_ url: URL, at place: NotebookSession.Place? = nil, allowAutomaticReturn: Bool = true) -> Bool {
        guard library.notebooks.contains(url) else { problem = "This notebook is no longer available."; return false }
        if open?.store.url != url {
            guard prepareCurrentForSwitch() else { return false }
            do {
                let next = try NotebookSession(url: url, allowAutomaticReturn: connection.acknowledged && allowAutomaticReturn)
                if open?.isSharedAbout == true { open?.deactivateSourceAccess() } else { open?.shutdown() }
                notebookSettings = nil
                open = next
            } catch { problem = error.localizedDescription; return false }
        }
        if let place { open?.show(place) }
        return true
    }

    @discardableResult
    func openAbout() -> Bool {
        if open?.isSharedAbout != true, !prepareCurrentForSwitch() { return false }
        do {
            if aboutSession == nil {
                let shared = try LibraryStore(root: library.root).ensureSharedAboutPage(session: "about-open")
                sharedAboutStore = shared.store
                aboutSession = try NotebookSession(url: shared.store.url, allowAutomaticReturn: false, conversationScope: .sharedAbout, libraryRoot: library.root)
            }
            guard let aboutSession else { return false }
            if open !== aboutSession { open?.shutdown(); notebookSettings = nil; open = aboutSession }
            aboutSession.store.reload(); aboutSession.show(.about); aboutSession.changed()
            return true
        } catch { problem = "About you could not be opened: " + error.localizedDescription; return false }
    }

    private func prepareCurrentForSwitch() -> Bool {
        guard let current = open else { return true }
        guard current.prepareForNavigationAway() else {
            problem = "Your page edit needs attention. Resolve the editor or review your kept text before switching conversations."
            return false
        }
        return true
    }
    /// Both Quit and the main workspace's close button use this before any cleanup.
    func prepareForClosing() -> Bool {
        var sessions: [NotebookSession] = []
        if let open { sessions.append(open) }
        if let aboutSession, !sessions.contains(where: { $0 === aboutSession }) { sessions.append(aboutSession) }
        for session in sessions where !session.prepareForNavigationAway() {
            if open !== session {
                if open?.isSharedAbout == true { open?.deactivateSourceAccess() } else { open?.shutdown() }
                open = session
            }
            problem = "Your page edit needs attention. Resolve the editor or review your kept text before closing Sophia."
            return false
        }
        return true
    }

    func readAlmanacEntry(_ entry: AlmanacEntry) {
        MainActor.assumeIsolated {
            guard let worker = almanac.worker,
                  let checked = Almanac.entry(id: entry.id, url: worker.url), checked.file == entry.file else {
                problem = "This Almanac entry is no longer available. Saved pages remain in the notebook."; return
            }
            guard openNotebook(worker.url, at: .page(checked.file), allowAutomaticReturn: false) else { return }
            open?.store.reload()
            worker.acknowledgeOpening(file: checked.file)
        }
    }

    /// Follows a link to a page in another notebook.
    func follow(notebook name: String, page: String?, section: String? = nil) {
        guard let url = library.notebooks.first(where: { $0.lastPathComponent == name }) else {
            problem = "This notebook is no longer available."; return
        }
        if let page {
            // Inspect metadata without constructing a store (which can create missing files).
            guard let data = try? Data(contentsOf: url.appendingPathComponent("notebook.json")),
                  let meta = (try? JSONDecoder().decode(JSON.self, from: data))?.object else {
                problem = "This notebook is no longer available."; return
            }
            let files = (meta["unfiled"]?.array ?? []) + (meta["chapters"]?.array ?? []).flatMap { $0["pages"]?.array ?? [] }
                + [meta["overview"]].compactMap { $0 } + (meta["chapters"]?.array ?? []).compactMap { $0["intro"] }
            let pages = url.appendingPathComponent("pages", isDirectory: true).resolvingSymlinksInPath()
            let destination = pages.appendingPathComponent(page).resolvingSymlinksInPath()
            guard files.compactMap(\.string).contains(page), destination.deletingLastPathComponent() == pages,
                  FileManager.default.fileExists(atPath: destination.path) else {
                problem = "This page is no longer available."; return
            }
        }
        guard openNotebook(url, at: page.map { .page($0) } ?? .contents), open?.store.url == url else { return }
        open?.pendingSection = section
    }

    func showNotebookSettings(_ url: URL, section: NotebookSettingsSection = .notebook) {
        if open?.store.url != url, !openNotebook(url, allowAutomaticReturn: false) { return }
        guard open?.store.url == url else { return }
        notebookSettings = NotebookSettingsSelection(url: url, section: section)
    }

    @discardableResult
    func create(_ name: String) -> Bool {
        do {
            let url = try library.create(named: name)
            notebooks = library.notebooks
            openNotebook(url)
            return open?.store.url.path == url.path
        } catch { problem = error.localizedDescription; return false }
    }
}

@main
struct SophiaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject var model = AppModel()

    var body: some Scene {
        WindowGroup("Sophia") {
            RootView()
                .environmentObject(model)
                .environmentObject(model.connection)
                .environmentObject(model.almanac)
                .frame(minWidth: 1140, minHeight: 600)
                .background(WorkspaceWindowCloseGuard(shouldClose: { model.prepareForClosing() }, attached: { delegate.workspaceWindow = $0 }))
                .onAppear { delegate.model = model }
        }
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Notebook…") { NotificationCenter.default.post(name: .newNotebook, object: nil) }
                    .keyboardShortcut("n")
            }
            CommandGroup(after: .appInfo) {
                Button("Sophia’s Almanac…") {
                    if let worker = model.almanac.worker { model.openNotebook(worker.url, at: .contents, allowAutomaticReturn: false) }
                    else { model.almanac.showSettings() }
                }
            }
            CommandGroup(after: .pasteboard) {
                Divider()
                Button("Edit Page") { NotificationCenter.default.post(name: .editPage, object: nil) }
                    .keyboardShortcut("e")
            }
        }
        Settings {
            ConnectionView(connection: model.connection, inSettings: true)
                .frame(width: 560)
        }

    }
}

extension Notification.Name {
    static let prepareToTerminate = Notification.Name("SophiaPrepareToTerminate")
    static let newNotebook = Notification.Name("SophiaNewNotebook")
    static let editPage = Notification.Name("SophiaEditPage")
    static let scrollConversationToEnd = Notification.Name("SophiaScrollConversationToEnd")
    static let openAlmanacEntry = Notification.Name("SophiaOpenAlmanacEntry")
}

struct RootView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject private var connection: ConnectionState
    @EnvironmentObject private var almanac: AlmanacModel
    @State private var naming = false
    @State private var newName = ""
    @State private var startingText = ""
    @State private var drafts: [String: String] = [:]

    var body: some View {
        VStack(spacing: 0) {
            if !connection.acknowledged {
                ConnectionView(connection: connection, compact: true)
                Divider()
            }
            NavigationSplitView {
                SidebarView()
                    .navigationSplitViewColumnWidth(min: 200, ideal: 260, max: 340)
            } detail: {
                Group {
                    if let s = model.open { NotebookView(session: s, drafts: $drafts) }
                    else { EmptyLibraryView(naming: $naming) }
                }
            }
            .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if let worker = almanac.worker {
                    AlmanacReadyControl(worker: worker, read: model.readAlmanacEntry)
                }
            }
            if #available(macOS 26, *) {
                ToolbarItem(placement: .principal) { BrandLockup() }
                    .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .principal) { BrandLockup() }
        }
            }
        }
        .sheet(isPresented: $connection.detailsShown) {
            ConnectionView(connection: connection).frame(width: 560)
        }
        .sheet(isPresented: $almanac.settingsShown) { AlmanacSettingsView(almanac: almanac) }
        .sheet(item: $model.notebookSettings) { selection in
            if let session = model.open, session.store.url == selection.url {
                NotebookSettingsView(session: session, section: selection.section) { model.notebookSettings = nil }
            }
        }
        .onChange(of: almanac.worker?.url) { _, _ in model.notebooks = model.library.notebooks }
        .onReceive(NotificationCenter.default.publisher(for: .openAlmanacEntry)) { notification in
            guard let id = notification.object as? String,
                  let worker = almanac.worker,
                  let entry = Almanac.entry(id: id, url: worker.url) else {
                model.problem = "This Almanac entry is no longer available."; return
            }
            model.readAlmanacEntry(entry)
        }
        .sheet(isPresented: $naming) {
            VStack(alignment: .leading, spacing: 12) {
                Text("What would you like to explore?").font(.headline)
                Text("Bring a question, an interest, a passage, or something you tried.")
                    .font(.callout).foregroundStyle(.secondary)
                TextEditor(text: $startingText)
                    .font(.body).frame(minHeight: 110, maxHeight: 180)
                    .padding(6).overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
                    .accessibilityLabel("Starting question or material")
                TextField("Notebook name (optional)", text: $newName)
                Text("Notebook: “\(suggestedName)”").font(.caption).foregroundStyle(.secondary)
                Text("Continue opens the notebook. Your text stays in the conversation draft; nothing is sent.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Spacer()
                    Button("Cancel") { naming = false }
                    Button("Continue", action: createNotebook).keyboardShortcut(.defaultAction)
                        .disabled(startingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(20).frame(width: 480)
        }
        .onReceive(NotificationCenter.default.publisher(for: .newNotebook)) { _ in naming = true }
        .alert("Sophia", isPresented: Binding(get: { model.problem != nil }, set: { if !$0 { model.problem = nil } })) {
            Button("OK") { model.problem = nil }
        } message: { Text(model.problem ?? "") }
    }

    var suggestedName: String {
        let supplied = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = startingText.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        var title = supplied
        if title.isEmpty {
            title = firstLine
            if let end = title.firstIndex(where: { "?!.".contains($0) }) {
                title = String(title[...end])
            }
        }
        var base = String(title.prefix(64))
        if title.count > 64, let boundary = base.lastIndex(where: \.isWhitespace) {
            base = String(base[..<boundary])
        }
        for separator in ["/", "\\", ":", "\n", "\r"] { base = base.replacingOccurrences(of: separator, with: " ") }
        while base.utf8.count > 240 { base.removeLast() }
        base = base.trimmingCharacters(in: .whitespacesAndNewlines)
        if base.isEmpty || base == "." || base == ".." { base = "New inquiry" }
        var candidate = base, number = 2
        while FileManager.default.fileExists(atPath: model.library.root.appendingPathComponent(candidate, isDirectory: true).path)
            || (try? FileManager.default.destinationOfSymbolicLink(atPath: model.library.root.appendingPathComponent(candidate, isDirectory: true).path)) != nil {
            candidate = "\(base) (\(number))"; number += 1
        }
        return candidate
    }

    func createNotebook() {
        guard model.create(suggestedName) else { return }
        if let session = model.open { drafts[NotebookView.draftKey(session)] = startingText }
        naming = false
        startingText = ""
        newName = ""
    }
}

/// One workspace layout: conversation in the middle, main page on the right.
/// Empty notebooks show the same editable introduction page and conversation.
struct NotebookView: View {
    @ObservedObject var session: NotebookSession
    @EnvironmentObject private var model: AppModel
    @Binding var drafts: [String: String]

    init(session: NotebookSession, drafts: Binding<[String: String]> = .constant([:])) {
        self.session = session
        _drafts = drafts
    }

    static func draftKey(_ session: NotebookSession) -> String {
        session.store.url.path + "/" + session.activeThread
    }

    private enum Surface: Hashable { case conversation, divider, book }
    var body: some View {
        let key = Self.draftKey(session)
        let draft = Binding(get: { drafts[key] ?? "" }, set: { drafts[key] = $0 })
        let surfaces: [Surface] = [.conversation, .divider, .book]
        HStack(spacing: 0) {
            // One layout: Library, conversation, then the main page. Visibility is always explicit.
            ForEach(surfaces, id: \.self) { surface in
                switch surface {
                case .conversation:
                    ConversationView(session: session, draft: draft)
                        .frame(width: model.conversationCollapsed ? 44 : 360)
                        .frame(maxHeight: .infinity)
                case .divider:
                    Divider()
                case .book:
                    BookView(session: session).frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .onReceive(NotificationCenter.default.publisher(for: .editPage)) { _ in session.editWholePage() }
        .onChange(of: session.place) { _, place in
            if case .page(let file) = place, let worker = model.almanac.worker, worker.url == session.store.url {
                worker.acknowledgeOpening(file: file)
            }
        }
        .onChange(of: Self.draftKey(session)) { old, new in
            let prefix = session.store.url.path + "/"
            guard old.hasPrefix(prefix), !old.hasSuffix("/"),
                  !session.store.pageFiles.contains(String(old.dropFirst(prefix.count))),
                  let orphaned = drafts.removeValue(forKey: old), !orphaned.isEmpty else { return }
            let destination = drafts[new] ?? ""
            drafts[new] = destination.isEmpty ? orphaned : destination + "\n\n" + orphaned
        }

    }
}

struct EmptyLibraryView: View {
    @Environment(\.controlActiveState) private var controlActiveState
    @Binding var naming: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            BrandMark().fill(Brand.plum).frame(width: 40, height: 40)
                .padding(.bottom, 2).accessibilityHidden(true)
            Text("What do you want to understand?").font(.system(size: 30, weight: .semibold, design: .serif))
            Text("Start a notebook for a question, an idea to test, or something to look into. A book forms only as you keep things.")
                .foregroundStyle(.secondary)
            Button { naming = true } label: {
                Text("New Notebook…").foregroundStyle(controlActiveState == .inactive ? Color.primary : Brand.onPlum)
            }
                .buttonStyle(.borderedProminent).tint(Brand.plum)
        }
        .padding(48).frame(maxWidth: 560, maxHeight: .infinity, alignment: .center)
    }
}
