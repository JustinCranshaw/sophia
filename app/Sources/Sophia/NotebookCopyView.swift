import SwiftUI
import AppKit

/// Finder copies the ordinary folder; Sophia adds no archive or sync format.
struct NotebookCopyActions: ViewModifier {
    let url: URL
    @EnvironmentObject private var model: AppModel
    @State private var helpShown = false
    func body(content: Content) -> some View {
        HStack(spacing: 4) {
            content.frame(maxWidth: .infinity, alignment: .leading)
            Menu { actions } label: {
                Text("…").font(.system(size: 16, weight: .semibold)).frame(width: 20, height: 20)
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            .accessibilityLabel("Notebook actions")
            .help("Notebook actions for “\(url.lastPathComponent)”")
        }
        .background(model.open?.store.url == url && model.open?.place == .contents ? Brand.selectionFill : .clear,
                    in: RoundedRectangle(cornerRadius: 6))
        .contextMenu { actions }
        .sheet(isPresented: $helpShown) {
            NotebookCopyView(url: url, close: { helpShown = false })
        }
    }
    private var actions: some View {
        Group {
            Button("Notebook settings…") { model.showNotebookSettings(url) }
            Button("Goals…") { model.showNotebookSettings(url, section: .goals) }
            Button("Sophia’s notes…") { model.showNotebookSettings(url, section: .notes) }
            Button("Working memory…") { model.showNotebookSettings(url, section: .memory) }
            Divider()
            Button("Show Notebook in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            Button("Copy & Restore…") { helpShown = true }
            Button("Deleted Pages…") { model.deletedPagesNotebook = url }
            Divider()
            Button("Move Notebook to Trash…", role: .destructive) { model.requestNotebookRemoval(url) }
        }
    }
}

struct NotebookCopyView: View {
    let url: URL
    let close: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Copy & restore a notebook").font(.headline)
            Text(url.lastPathComponent).font(.title3)
            Text(url.path).font(.caption).textSelection(.enabled)
            Text("1. Let any reply finish, finish your edits, close this help, and quit Sophia. In Finder, copy this entire notebook folder to your backup location. Copying while Sophia is writing can leave an incomplete backup.")
            Text("2. To restore, quit Sophia and copy the complete folder into your Library. Use its original folder name and an empty destination; do not merge with or replace an existing notebook. Reopen Sophia and select the restored notebook.")
            Text("The whole folder keeps pages, the single previous page versions, ordering, conversations, goals, notes, corrections and record identities. Provider credentials are not stored in it. Unsaved composer drafts and pending in-memory Undo for deleted notes are not backups; save what you need before quitting.")
            Text("About you and links between notebooks live separately in the Library’s hidden .sophia folder. To move everything, copy the whole Library, including .sophia, while Sophia is quit. Keep notebook names together so links still resolve.")
            Text("A copied folder is a snapshot, not supported concurrent sync. Do not open the same Library in multiple running copies of Sophia, including through a cloud folder.")
                .foregroundStyle(.secondary)
            Text("An Almanac copy keeps its automatic-preparation settings. Pause or disable preparation before copying if you want an archive only. Notification choices stay local to each Library; macOS permission does not travel with the folder.")
                .foregroundStyle(.secondary)
            HStack {
                Button("Show Notebook in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                Button("Show Library in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url.deletingLastPathComponent()]) }
                Spacer()
                Button("Close", action: close).keyboardShortcut(.cancelAction)
            }
        }
        .font(.callout).fixedSize(horizontal: false, vertical: true)
        .padding(20).frame(width: 580)
    }
}
