import SwiftUI
import SophiaCore

enum NotebookSettingsSection: String, CaseIterable, Identifiable {
    case notebook = "Notebook", goals = "Goals", notes = "Sophia’s notes"
    var id: String { rawValue }
}
struct NotebookSettingsSelection: Identifiable {
    let id = UUID()
    let url: URL
    let section: NotebookSettingsSection
}
struct NotebookSettingsView: View {
    @ObservedObject var session: NotebookSession
    @State var section: NotebookSettingsSection
    let close: () -> Void
    @State private var copying = false
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(session.store.name).font(.headline).lineLimit(1)
                Spacer()
                Button("Done", action: close).keyboardShortcut(.cancelAction)
            }.padding(18)
            Picker("Notebook settings", selection: $section) {
                ForEach(NotebookSettingsSection.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented).padding(.horizontal, 18).padding(.bottom, 12)
            Divider()
            Group {
                switch section {
                case .goals: GoalsView(session: session)
                case .notes: NotesView(session: session)
                case .notebook:
                    Sheet {
                        Text("Notebook settings").font(.title2)
                        Toggle("Keep this notebook separate", isOn: Binding(get: { session.store.isSeparate }, set: { session.setSeparate($0) }))
                        Intro("A separate notebook shares no themes or links with other notebooks.")
                        let links = session.library.links(touching: session.store.name)
                        if !links.isEmpty {
                            Text("Connections").font(.headline)
                            LinksList(session: session, links: links)
                        }
                        Button("Copy & restore…") { copying = true }
                        Button("Show notebook in Finder") { NSWorkspace.shared.activateFileViewerSelecting([session.store.url]) }
                    }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 740, height: 540)
        .sheet(isPresented: $copying) { NotebookCopyView(url: session.store.url, close: { copying = false }) }
        // An explicit evidence Open action returns to the reader, including a same-page section.
        .onChange(of: session.pendingSectionID) { _, _ in close() }
    }
}
