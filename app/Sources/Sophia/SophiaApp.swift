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
    private var terminating = false
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !terminating else { return .terminateLater }
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
    @Published var problem: String?
    @Published var notebookSettings: NotebookSettingsSelection?
    @Published var aboutShown = false
    private var bookVisibility: [String: Bool] = [:]

    init() {
        let library = Library(), connection = ConnectionState()
        self.library = library; self.connection = connection
        almanac = MainActor.assumeIsolated { AlmanacModel(root: library.root, connection: connection) }
        notebooks = library.notebooks
        if let first = notebooks.first { openNotebook(first, at: .contents) }
        MainActor.assumeIsolated {
            almanac.ordinaryBusy = { [weak self] in self?.open?.isResponding == true }
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
            // A page/Open action counts as choosing the book; an untouched empty default does not.
            if let current = open, current.bookShown { bookVisibility[current.store.url.path] = true }
            do {
                let next = try NotebookSession(url: url, allowAutomaticReturn: connection.acknowledged && allowAutomaticReturn)
                open?.shutdown()
                next.bookShown = bookVisibility[next.store.url.path] ?? !next.store.pages.isEmpty
                open = next
            } catch { problem = error.localizedDescription; return false }
        }
        if let place { open?.show(place) }
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

    func toggleBook() {
        guard let current = open else { return }
        current.bookShown.toggle()
        bookVisibility[current.store.url.path] = current.bookShown
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
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Notebook…") { NotificationCenter.default.post(name: .newNotebook, object: nil) }
                    .keyboardShortcut("n")
            }
            CommandGroup(after: .appInfo) {
                Button("Connection & Data…") { model.connection.detailsShown = true }
                Button("Sophia’s Almanac…") {
                    if let worker = model.almanac.worker { model.openNotebook(worker.url, allowAutomaticReturn: false) }
                    else { model.almanac.showSettings() }
                }
            }
            CommandGroup(after: .pasteboard) {
                Divider()
                Button("Edit Page") { NotificationCenter.default.post(name: .editPage, object: nil) }
                    .keyboardShortcut("e")
            }
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
                    .navigationSplitViewColumnWidth(min: 200, ideal: 260, max: 420)
            } detail: {
                if let s = model.open { NotebookView(session: s, drafts: $drafts) } else { EmptyLibraryView(naming: $naming) }
            }
        }
        .sheet(isPresented: $connection.detailsShown) {
            ConnectionView(connection: connection).frame(width: 560)
        }
        .sheet(isPresented: $almanac.settingsShown) { AlmanacSettingsView(almanac: almanac) }
        .sheet(isPresented: $model.aboutShown) {
            if let session = model.open {
                SharedAboutView(session: session) { model.aboutShown = false }
            }
        }
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if let worker = almanac.worker {
                    AlmanacReadyControl(worker: worker, read: model.readAlmanacEntry)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Connection & Data") { connection.detailsShown = true }
            }
            ToolbarItem(placement: .navigation) {
                Button { naming = true } label: { Label("New Notebook", systemImage: "plus") }
                    .help("New notebook")
            }
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
                Text("Continue opens your conversation with this text ready to send. Nothing is sent yet.")
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

/// The book sits beside the conversation when both readable columns fit, and below it otherwise.
/// Empty notebooks begin with the conversation; explicit book visibility remains the person's choice.
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

    /// The book takes about 60% of the space, within a comfortable range for a 660pt text column;
    /// the conversation takes the rest and never drops below 360.
    static func bookWidth(_ total: CGFloat) -> CGFloat {
        min(800, max(460, min(total * 0.6, total - 360)))
    }
    private enum Surface: Hashable { case conversation, divider, book }
    private var readingAlmanac: Bool {
        guard model.almanac.worker?.url == session.store.url, session.bookShown,
              case .page = session.place, !session.isPending(session.activeThread),
              session.pendingSource == nil, session.problem == nil, session.editRecovery.edits.isEmpty else { return false }
        return !session.store.threadEntries(for: session.activeThread).contains(where: NotebookStore.isMessage)
    }
    var body: some View {
        GeometryReader { geo in
            let key = Self.draftKey(session)
            let draft = Binding(get: { drafts[key] ?? "" }, set: { drafts[key] = $0 })
            let narrow = geo.size.width < 821
            let reading = (session.place == .contents && session.bookShown) || readingAlmanac
            let surfaces: [Surface] = reading ? [.book, .divider, .conversation] : [.conversation, .divider, .book]
            let layout = reading || narrow ? AnyLayout(VStackLayout(spacing: 0)) : AnyLayout(HStackLayout(spacing: 0))
            layout {
                // Stable surface IDs retain the reader/editor when the first question opens discussion.
                ForEach(surfaces, id: \.self) { surface in
                    switch surface {
                    case .conversation:
                        ConversationView(session: session, draft: draft, compact: reading)
                            .frame(maxWidth: .infinity, maxHeight: reading ? nil : .infinity)
                            .fixedSize(horizontal: false, vertical: reading)
                    case .divider:
                        if session.bookShown { Divider() }
                    case .book:
                        if session.bookShown {
                            BookView(session: session)
                                .frame(width: reading || narrow ? nil : Self.bookWidth(geo.size.width),
                                       height: !reading && narrow ? max(0, min(geo.size.height * 0.55, geo.size.height - 300)) : nil)
                        }
                    }
                }
            }
        }
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { withAnimation { model.toggleBook() } } label: {
                    Label(session.bookShown ? "Hide Book" : "Show Book", systemImage: "sidebar.right")
                }
                .help(session.bookShown ? "Hide the book" : "Show the book")
                .keyboardShortcut("b", modifiers: [.command, .option])
            }
        }
    }
}

struct EmptyLibraryView: View {
    @Binding var naming: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What do you want to understand?").font(.system(size: 30, weight: .semibold, design: .serif))
            Text("Start a notebook for a question, an idea to test, or something to look into. A book forms only as you keep things.")
                .foregroundStyle(.secondary)
            Button("New Notebook…") { naming = true }.buttonStyle(.borderedProminent)
        }
        .padding(48).frame(maxWidth: 560, maxHeight: .infinity, alignment: .center)
    }
}
