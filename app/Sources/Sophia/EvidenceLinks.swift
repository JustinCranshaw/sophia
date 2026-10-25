import SwiftUI
import SophiaCore

/// Inspect one supporting item in place without moving the conversation or changing threads.
struct EvidenceLinks: View {
    @ObservedObject var session: NotebookSession
    let refs: [String]
    @State private var expanded: Int?

    var body: some View {
        if !refs.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Based on").font(.caption2).foregroundStyle(.secondary)
                ForEach(Array(refs.enumerated()), id: \.offset) { index, ref in
                    let evidence = EvidenceReference.resolve(ref, in: session.store)
                    Button { expanded = expanded == index ? nil : index } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Image(systemName: expanded == index ? "chevron.down" : "chevron.right").font(.caption2)
                            Text(evidence.label).font(.caption).multilineTextAlignment(.leading).lineLimit(2)
                        }
                    }.buttonStyle(.link)
                    if expanded == index {
                        EvidenceDetail(session: session, reference: ref) { expanded = nil }
                    }
                }
            }
            .onChange(of: refs) { _, _ in expanded = nil }
        }
    }
}

private struct EvidenceDetail: View {
    @ObservedObject var session: NotebookSession
    let reference: String
    let close: () -> Void
    var body: some View {
        let evidence = EvidenceReference.resolve(reference, in: session.store)
        VStack(alignment: .leading, spacing: 10) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text(evidence.heading).font(.headline)
                    if let date = evidence.date { Text(shortDate(date)).font(.caption).foregroundStyle(.secondary) }
                    if let quote = evidence.quote { Text("Your exact words").font(.caption.weight(.bold)); PersonQuote(text: quote).textSelection(.enabled) }
                    if let correction = evidence.correction {
                        Text("Your correction").font(.caption.weight(.bold))
                        Text(correction).textSelection(.enabled)
                        Text("Original · " + evidence.heading).font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    }
                    Text(evidence.text).textSelection(.enabled)
                    Text("Record: " + reference).font(.caption2).foregroundStyle(.secondary).textSelection(.enabled)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.frame(maxHeight: 300)
            if let notice = session.navigationProblem { Text(notice).font(.callout).foregroundStyle(.secondary) }
            HStack {
                if let file = evidence.page {
                    Button("Open page") {
                        if EvidenceReference.resolve(reference, in: session.store).page == file {
                            session.show(.page(file)); close()
                        } else { session.navigationProblem = "This page is no longer available." }
                    }
                    let sections = session.store.editRanges(of: file).filter { $0.index != nil }
                    if !sections.isEmpty {
                        Menu("Open section") {
                            ForEach(sections, id: \.key) { range in
                                let target = SectionTarget.exact(notebook: session.store.url, file: file, range: range)
                                Button(range.label + " · " + range.section) { if session.openSection(target) { close() } }
                            }
                        }
                    }
                }
                Button("Close evidence", action: close)
            }.controlSize(.small)
        }.padding(12)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
    }
}
