import SwiftUI
import SophiaCore

struct RemovalTarget: Identifiable {
    let notebook: URL
    let file: String?
    let title: String
    var id: String { notebook.path + "/" + (file ?? "") }
}

struct RemovalConfirmation: View {
    @EnvironmentObject private var model: AppModel
    let target: RemovalTarget
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(target.file == nil ? "Delete notebook?" : "Delete page?").font(.headline)
            Text(target.title).font(.title3).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
            if target.file != nil {
                Text("From “\(target.notebook.lastPathComponent)”. The page stays recoverable in this notebook. Restore it from Contents (select the notebook’s name in the sidebar). Conversations and source history are kept. This does not erase earlier copies of its content. Links to and from this page stop working and will need to be added and confirmed again after Restore.")
            } else {
                Text("Its pages, conversations and history move together to macOS Trash. Use Finder’s Put Back to recover the notebook. Links to and from it stop working and will need to be added and confirmed again.")
                if !Almanac.isConfigured(url: target.notebook), model.library.notebooks.contains(where: { $0 != target.notebook && Almanac.isConfigured(url: $0) }) {
                    Text("Saved entries in the Almanac stay in the Almanac.")
                }
                if Almanac.isConfigured(url: target.notebook) {
                    Text("Daily preparation stops. After restoring, enable the Almanac again if you want preparation to resume.")
                }
            }
            Text("Any reply or preparation in this notebook will stop before removal.").foregroundStyle(.secondary)
            HStack {
                Button("Cancel") { model.removalTarget = nil }.keyboardShortcut(.cancelAction)
                Spacer()
                Button(target.file == nil ? "Delete Notebook" : "Delete Page", role: .destructive) { model.performRemoval(target) }
                    .accessibilityLabel(target.file == nil ? "Confirm Delete Notebook" : "Confirm Delete Page")
            }
        }.font(.callout).padding(24).frame(width: 480)
    }
}

struct DeletedPagesView: View {
    @EnvironmentObject private var model: AppModel
    let notebook: URL
    @State private var pages: [NotebookStore.DeletedPage] = []
    @State private var restoreProblem: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Deleted Pages").font(.headline)
            Text(notebook.lastPathComponent).font(.title3)
            Text("Restore the original page and previous version. Its conversation and source history were kept. Links to and from the page will need to be added and confirmed again after Restore.").font(.callout).foregroundStyle(.secondary)
            if pages.isEmpty { Text("No deleted pages.").foregroundStyle(.secondary) }
            else {
                List(pages) { page in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(page.title).lineLimit(2)
                            Text(deletedDate(page.deletedAt)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Restore") {
                            restoreProblem = model.restorePage(page.id, notebook: notebook)
                            load()
                        }.accessibilityLabel("Restore “\(page.title)”")
                    }.padding(.vertical, 5)
                }.frame(minHeight: 140, maxHeight: 320)
            }
            if let restoreProblem {
                Label(restoreProblem, systemImage: "exclamationmark.triangle").font(.callout).foregroundStyle(.red).textSelection(.enabled)
            }
            HStack {
                Button("Show Notebook in Finder") { NSWorkspace.shared.activateFileViewerSelecting([notebook]) }
                Spacer()
                Button("Done") { model.deletedPagesNotebook = nil }.keyboardShortcut(.cancelAction)
            }
        }.padding(24).frame(width: 520).onAppear(perform: load)
    }
    private func deletedDate(_ text: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: text) else { return "Deletion date unavailable" }
        return "Deleted " + date.formatted(date: .abbreviated, time: .shortened)
    }
    private func load() {
        guard FileManager.default.fileExists(atPath: notebook.appendingPathComponent("notebook.json").path),
              let store = try? NotebookStore(url: notebook, existingOnly: true) else { pages = []; return }
        pages = store.deletedPages
    }
}

struct PageRemovalActions: View {
    @EnvironmentObject private var model: AppModel
    let store: NotebookStore
    let file: String
    var body: some View {
        if store.canDeletePage(file) {
            Button("Delete Page…", role: .destructive) { model.requestPageRemoval(file, notebook: store.url) }
        } else {
            Button("Delete Page…") {}.disabled(true)
            Text("Required page. Use Edit to clear its content.")
        }
    }
}
