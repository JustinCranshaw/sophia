import SwiftUI
import SophiaCore

/// Audit evidence stays inspectable without becoming a second editable version of a page.
struct NotebookPageHistory: View {
    @ObservedObject var session: NotebookSession
    var body: some View {
        DisclosureGroup("Notebook history and evidence") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Earlier records retain their original identities and wording. The Markdown pages above are current; historical goal criteria and interpretations do not describe later edits.")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(session.store.learning.reversed(), id: \.self.line) { record in
                    DisclosureGroup((record.str("id") ?? "Record") + " · " + (record.str("kind") ?? "evidence")) {
                        Text(verbatim: JSON.object(record).pretty).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                        EvidenceLinks(session: session, refs: (record["refs"]?.array ?? []).compactMap(\.string))
                    }.font(.caption)
                }
            }.padding(.top, 8)
        }.font(.caption).padding(.top, 16)
    }
}
