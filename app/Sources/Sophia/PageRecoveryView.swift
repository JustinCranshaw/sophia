import SwiftUI
import AppKit

/// A compact reminder keeps the composer/source decisions reachable; full text is read-only.
struct PageRecoveryView: View {
    @ObservedObject var session: NotebookSession
    @State private var reviewing = false
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.badge.exclamationmark").foregroundStyle(.orange)
            Text(session.editRecovery.edits.count == 1 ? "1 unsaved edit kept temporarily." : "\(session.editRecovery.edits.count) unsaved edits kept temporarily.")
            Spacer(minLength: 4)
            Button("Review kept edits") { reviewing = true }
        }
        .font(.caption).padding(12).background(Color.orange.opacity(0.08))
        .sheet(isPresented: $reviewing) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Unsaved page edits").font(.title2.bold())
                    Spacer()
                    Button("Close") { reviewing = false }.keyboardShortcut(.cancelAction)
                }
                Text("Copy what you need, then dismiss each kept edit before closing or switching conversations. These edits are temporary, not a saved revision.")
                    .font(.callout).foregroundStyle(.secondary)
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if session.editRecovery.edits.isEmpty { Text("No kept edits.").foregroundStyle(.secondary) }
                        ForEach(session.editRecovery.edits) { edit in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(edit.title).font(.headline)
                                Text(edit.section == "(page)" ? "Whole page" : edit.section == "(opening)" ? "Opening" : edit.section)
                                    .font(.caption).foregroundStyle(.secondary)
                                Text(edit.text).font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                                HStack {
                                    Button("Copy text") {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(edit.text, forType: .string)
                                    }
                                    Button("Dismiss this edit") { session.editRecovery.dismiss(edit.id) }
                                }
                                Divider()
                            }
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(20).frame(width: 600, height: 440)
        }
    }
}
