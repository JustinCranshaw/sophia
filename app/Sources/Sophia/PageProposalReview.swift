import SwiftUI
import SophiaCore

/// Review is outside the editable body. Acceptance uses the existing page edit and Undo path.
struct PageProposalReview: View {
    @ObservedObject var session: NotebookSession
    let proposalID: String
    @State private var problem: String?
    private var proposal: JSONObject? { session.store.pendingPageProposals().first { $0.str("id") == proposalID } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Review proposed change").font(.title2.weight(.semibold))
                Spacer()
                let pending = session.visiblePageProposals
                if let index = pending.firstIndex(where: { $0.str("id") == proposalID }), pending.count > 1 {
                    Text("Change \(index + 1) of \(pending.count)").font(.caption).foregroundStyle(.secondary)
                    Button("Previous") { problem = nil; session.reviewProposalID = pending[index - 1].str("id") }.disabled(index == 0)
                    Button("Next") { problem = nil; session.reviewProposalID = pending[index + 1].str("id") }.disabled(index + 1 == pending.count)
                }
            }
            if let proposal, let file = proposal.str("file") {
                let stale = session.store.pageHash(file) != proposal.str("basehash")
                let editing = session.store.editMarker != nil
                let evidence = proposal["evidence"]
                let quote = evidence?["quote"]?.string ?? evidence?["quote"]?["text"]?.string
                if let quote { Text("Based on your words: “" + quote + "”").font(.callout).textSelection(.enabled) }
                if let origin = proposal.str("originNotebook") {
                    Text(origin == ClaudeEngine.sharedAboutOrigin ? "From this About you conversation" : "From “" + origin + "”")
                        .font(.caption).foregroundStyle(.secondary)
                }
                let current = session.store.readPage(file)?.body ?? ""
                let proposed = proposal.str("content") ?? ""
                let counts = changeCounts(current: current, proposed: proposed)
                HStack(alignment: .top, spacing: 18) {
                    source("Current saved page", current)
                    source("Proposed page", proposed)
                }
                DisclosureGroup("Show Markdown source") {
                    HStack(alignment: .top, spacing: 18) {
                        rawSource(current)
                        rawSource(proposed)
                    }.frame(height: 120)
                }.font(.caption)
                DisclosureGroup("Source record") {
                    ScrollView { Text(verbatim: evidence?.line ?? "No source record").font(.system(.caption, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                        .frame(maxHeight: 90)
                }.font(.caption)
                if stale { Text("This page changed after the proposal. Ask for a new proposal based on the current page.").foregroundStyle(.secondary) }
                else if editing { Text("Finish editing the page before accepting this change.").foregroundStyle(.secondary) }
                if let problem { Text(problem).foregroundStyle(.red).textSelection(.enabled) }
                Text("Accepting replaces the whole page · \(counts.added) \(counts.added == 1 ? "line" : "lines") added, \(counts.removed) removed")
                    .font(.callout).foregroundStyle(.secondary)
                HStack {
                    Button("Reject change") { decide { try session.rejectProposal(proposalID) } }
                    Spacer()
                    Button("Close") { session.reviewProposalID = nil }.keyboardShortcut(.cancelAction)
                    Button("Accept change") { decide { try session.acceptProposal(proposalID) } }
                        .buttonStyle(.borderedProminent).disabled(stale || editing).keyboardShortcut(.defaultAction)
                }
            } else {
                Text("This proposal is no longer pending. The saved page remains available.")
                Button("Close") { session.reviewProposalID = nil }.keyboardShortcut(.cancelAction)
            }
        }.padding(22).frame(width: 960, height: 660)
        .onAppear { session.store.reload() }
    }
    private func source(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            ScrollView {
                MarkdownView(text: text, style: .page)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(12)
            }.background(Color(nsColor: .textBackgroundColor)).overlay(Rectangle().stroke(.quaternary))
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private func rawSource(_ text: String) -> some View {
        ScrollView { Text(verbatim: text).font(.system(.caption, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
            .frame(maxWidth: .infinity)
    }
    private func changeCounts(current: String, proposed: String) -> (added: Int, removed: Int) {
        func lines(_ text: String) -> [String] {
            var result = text.components(separatedBy: "\n")
            if result.last == "" { result.removeLast() }
            return result
        }
        var added = 0, removed = 0
        for change in lines(proposed).difference(from: lines(current)) {
            switch change { case .insert: added += 1; case .remove: removed += 1 }
        }
        return (added, removed)
    }
    private func decide(_ action: () throws -> Void) {
        do { try action() }
        catch NotebookStore.PageProposalError.stale { problem = "The page changed. Ask for a new proposal."; session.changed() }
        catch NotebookStore.PageProposalError.editing { problem = "Finish editing the page before accepting." }
        catch { problem = "The decision could not be saved: " + error.localizedDescription }
    }
}
