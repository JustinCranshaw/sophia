import SwiftUI
import SophiaCore

enum NotebookSettingsSection { case notebook, goals, notes, memory }
struct NotebookSettingsSelection: Identifiable {
    let id = UUID()
    let url: URL
}
struct NotebookSettingsView: View {
    @ObservedObject var session: NotebookSession
    let close: () -> Void
    @State private var copying = false
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(session.store.name).font(.headline).lineLimit(1)
                Spacer()
                Button("Done", action: close).keyboardShortcut(.cancelAction)
            }.padding(18)
            Divider()
            Sheet {
                Text("Notebook settings").font(.title2)
                Toggle("Keep this notebook separate", isOn: Binding(get: { session.store.isSeparate }, set: { session.setSeparate($0) }))
                Intro("A separate notebook shares no themes or links with other notebooks.")
                let links = session.library.links(touching: session.store.name)
                if !links.isEmpty {
                    Text("Connections").font(.headline)
                    LinksList(session: session, links: links)
                }
                HStack {
                    Button("Goals") { session.show(.goals); close() }
                    Button("Sophia’s notes") { session.show(.notes); close() }
                    Button("Working memory") { session.show(.memory); close() }
                }
                Button("Copy & restore…") { copying = true }
                Button("Show notebook in Finder") { NSWorkspace.shared.activateFileViewerSelecting([session.store.url]) }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 740, height: 540)
        .sheet(isPresented: $copying) { NotebookCopyView(url: session.store.url, close: { copying = false }) }
        // An explicit evidence Open action returns to the reader, including a same-page section.
        .onChange(of: session.pendingSectionID) { _, _ in close() }
    }
}
