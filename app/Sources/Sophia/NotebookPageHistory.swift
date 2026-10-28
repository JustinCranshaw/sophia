import SwiftUI
import SophiaCore

/// Audit evidence stays inspectable without becoming a second editable version of a page.
struct NotebookPageHistory: View {
    @ObservedObject var session: NotebookSession
    var body: some View {
        let records = session.store.learning + session.store.pageProposalHistory
            + session.store.transcript.filter { $0.str("purpose") == "notebook_page_evidence" }
        DisclosureGroup("Notebook history and evidence") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Earlier records retain their original identities and wording. The Markdown pages above are current; historical goal criteria and interpretations do not describe later edits.")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(records.reversed(), id: \.self.line) { record in
                    DisclosureGroup((record.str("id") ?? "Record") + " · " + (record.str("kind") ?? record.str("purpose") ?? "evidence")) {
                        Text(verbatim: JSON.object(record).pretty).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                        EvidenceLinks(session: session, refs: (record["refs"]?.array ?? []).compactMap(\.string))
                    }.font(.caption)
                }
            }.padding(.top, 8)
        }.font(.caption).padding(.top, 16)
    }
}
