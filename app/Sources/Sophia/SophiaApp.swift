import SwiftUI
import AppKit
import SophiaCore

final class AppDelegate: NSObject, NSApplicationDelegate {
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
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

final class AppModel: ObservableObject {
    let library = Library()
    @Published var notebooks: [URL] = []
    @Published var open: NotebookSession?
    @Published var problem: String?
    private var bookVisibility: [String: Bool] = [:]

    init() {
        notebooks = library.notebooks
        if let first = notebooks.first { openNotebook(first) }
        Snapshot.run(model: self)
    }

    func openNotebook(_ url: URL, at place: NotebookSession.Place? = nil) {
        if open?.store.url != url {
            // A page/Open action counts as choosing the book; an untouched empty default does not.
            if let current = open, current.bookShown { bookVisibility[current.store.url.path] = true }
            open?.shutdown()
            do {
                let next = try NotebookSession(url: url)
                next.bookShown = bookVisibility[next.store.url.path] ?? !next.store.pages.isEmpty
                open = next
            } catch { problem = error.localizedDescription; return }
        }
        if let place { open?.show(place) }
    }

    /// Follows a link to a page in another notebook.
    func follow(notebook name: String, page: String?, section: String? = nil) {
        openNotebook(library.root.appendingPathComponent(name), at: page.map { .page($0) } ?? .contents)
        open?.pendingSection = section
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
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Notebook…") { NotificationCenter.default.post(name: .newNotebook, object: nil) }
                    .keyboardShortcut("n")
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
    static let newNotebook = Notification.Name("SophiaNewNotebook")
    static let editPage = Notification.Name("SophiaEditPage")
    static let scrollConversationToEnd = Notification.Name("SophiaScrollConversationToEnd")
}

struct RootView: View {
    @EnvironmentObject var model: AppModel
    @State private var naming = false
    @State private var newName = ""
    @State private var startingText = ""
    @State private var drafts: [String: String] = [:]

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 260, max: 420)
        } detail: {
            if let s = model.open { NotebookView(session: s, drafts: $drafts) } else { EmptyLibraryView(naming: $naming) }
        }
        .toolbar {
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
    var body: some View {
        GeometryReader { geo in
            let key = Self.draftKey(session)
            let draft = Binding(get: { drafts[key] ?? "" }, set: { drafts[key] = $0 })
            let narrow = geo.size.width < 821
            let layout = narrow ? AnyLayout(VStackLayout(spacing: 0)) : AnyLayout(HStackLayout(spacing: 0))
            layout {
                ConversationView(session: session, draft: draft)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if session.bookShown {
                    Divider()
                    BookView(session: session)
                        .frame(width: narrow ? nil : Self.bookWidth(geo.size.width),
                               height: narrow ? max(0, min(geo.size.height * 0.55, geo.size.height - 300)) : nil)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .editPage)) { _ in session.editWholePage() }
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
