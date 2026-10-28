import SwiftUI
import SophiaCore

// What Sophia keeps beyond a single note: Sophia's working memory for the notebook, "About you"
// (shared by every notebook), and links between notebooks. The person can see and change all of it.

/// Links from this notebook (or one of its pages) to pages in other notebooks.
struct LinksList: View {
    @ObservedObject var session: NotebookSession
    @EnvironmentObject var model: AppModel
    let links: [JSONObject]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(links, id: \.self.line) { l in
                if let end = session.otherEnd(of: l) {
                    let provisional = LibraryStore.isProvisional(l)
                    VStack(alignment: .leading, spacing: 4) {
                        Button { model.follow(notebook: end.notebook, page: end.page, section: end.section) } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Image(systemName: "arrow.up.right.square").foregroundStyle(.secondary)
                                Text(end.notebook).foregroundStyle(.secondary)
                                if let p = end.page { Text("›").foregroundStyle(.tertiary); Text(pageTitle(end.notebook, p)) }
                                if let s = end.section { Text("›").foregroundStyle(.tertiary); Text("§ " + s) }
                            }
                            .font(.system(size: 15, design: .serif))
                        }
                        .buttonStyle(.plain)
                        .disabled(provisional)
                        let near = session.nearEnd(of: l)
                        Text((near.section.map { "From § \($0): " } ?? "") + (l.str("reason") ?? "")).font(.callout).foregroundStyle(.secondary)
                        HStack {
                            if provisional {
                                Text("Proposed by Sophia").font(.caption).foregroundStyle(.orange)
                                Button("Confirm") { session.confirmLink(l.str("id") ?? "") }
                            }
                            Button(provisional ? "Not a link" : "Remove", role: .destructive) { session.removeLink(l.str("id") ?? "") }
                        }.controlSize(.small)
                    }
                }
            }
        }
    }

    func pageTitle(_ notebook: String, _ file: String) -> String {
        ExistingNotebook(root: session.library.root, name: notebook)?.readPage(file)?.title ?? file
    }
}

/// A conversation line when Sophia rewrites Sophia's memory.
struct MemoryChangedLine: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var session: NotebookSession
    let entry: JSONObject
    var body: some View {
        let parts = [("added", "added"), ("changed", "reworded"), ("dropped", "let go of")].compactMap { key, verb -> String? in
            let n: Int = { if case .number(let v)? = entry[key] { return Int(v) }; return 0 }()
            return n > 0 ? "\(verb) \(n)" : nil
        }
        HStack(spacing: 6) {
            Image(systemName: "brain").foregroundStyle(.tertiary)
            Text("Updated what Sophia is keeping in mind" + (parts.isEmpty ? "" : ": " + parts.joined(separator: ", ")))
                .foregroundStyle(.secondary)
            Button("See") { model.showNotebookSettings(session.store.url, section: .notes) }.buttonStyle(.link)
        }
        .font(.caption)
    }
}

/// A conversation card when Sophia proposes a line about the person, or a link.
struct LibraryProposalCard: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var session: NotebookSession
    let entry: JSONObject
    var body: some View {
        let isLink = entry.str("tool") == "link"
        let id = entry.str("record") ?? ""
        if !isLink {
            let history = model.sharedAboutStore?.pageProposalHistory ?? []
            let proposal = history.first { $0.str("id") == id || $0.str("legacyID") == id }
            let pending = model.sharedAboutStore?.pendingPageProposals().first { $0.str("id") == proposal?.str("id") }
            let decision = history.last { $0.str("proposal") == proposal?.str("id") }?.str("decision")
            let legacy = session.library.about.first { $0.str("id") == id }
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "person.crop.circle").foregroundStyle(.secondary)
                    Text(pending != nil ? "About you change proposed" : decision == "accepted" ? "You accepted this About you proposal" : decision == "rejected" ? "You rejected this About you proposal" : "Earlier About you record").font(.callout)
                    Spacer(minLength: 8)
                    Button(pending == nil ? "About you" : "Review") {
                        if model.openAbout() { model.open?.reviewProposalID = pending?.str("id") }
                    }.buttonStyle(.bordered).controlSize(.small)
                }
                if let source = proposal ?? legacy {
                    DisclosureGroup("Source record") { Text(verbatim: source.line).font(.system(.caption, design: .monospaced)).textSelection(.enabled) }.font(.caption)
                }
            }.padding(12).background(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.1)))
        } else {
        let rec = session.library.currentLinks.first { $0.str("id") == id }
        let confirmed = session.library.currentLinks.contains { $0.str("replaces") == id }
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: isLink ? "link" : "person.crop.circle").foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(isLink ? "PROPOSED A LINK" : "PROPOSED A LINE ABOUT YOU")
                    .font(.system(size: 10, weight: .bold)).tracking(0.6).foregroundStyle(.secondary)
                if isLink, let r = rec ?? session.library.links.first(where: { $0.str("id") == id }), let end = session.otherEnd(of: r) {
                    Text("\(end.notebook)\(end.page.map { " › " + $0 } ?? "")\(end.section.map { " › § " + $0 } ?? ""): \(r.str("reason") ?? "")").font(.system(size: 14))
                } else {
                    Text((rec ?? session.library.about.first { $0.str("id") == id })?.str("text") ?? "").font(.system(size: 14))
                }
                if confirmed { Text("Confirmed").font(.caption).foregroundStyle(.secondary) }
                else if rec == nil { Text("Removed").font(.caption).foregroundStyle(.secondary) }
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            if rec != nil {
                Button("Confirm") { session.confirmLink(id) }
            }
            Button(isLink ? "Notebook connections…" : "About you…") {
                if isLink { model.showNotebookSettings(session.store.url) }
                else { session.show(.about) }
            }
        }
        .controlSize(.small)
        .padding(.horizontal, 12).padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.1)))
        }
    }
}
