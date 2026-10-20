import SwiftUI
import SophiaCore

/// Library, then the open notebook expanded in place, in a fixed order:
/// Goals and Sophia's notes, then the book's pages. Every row is one line: titles truncate, with the full title on hover.
struct SidebarView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        List {
            Section("Library") {
                ForEach(model.notebooks, id: \.self) { url in
                    NotebookRows(url: url)
                }
            }
            if let s = model.open { Section { AboutRow(session: s) } }
        }
        .listStyle(.sidebar)
    }
}

struct NotebookRows: View {
    @EnvironmentObject var model: AppModel
    let url: URL

    var body: some View {
        if let s = model.open, s.store.url == url {
            OpenNotebookRows(session: s)
        } else {
            Button { model.openNotebook(url) } label: {
                Label(url.lastPathComponent, systemImage: "book.closed").lineLimit(1).truncationMode(.tail)
            }
            .buttonStyle(.plain)
            .help(url.lastPathComponent)
        }
    }
}

struct OpenNotebookRows: View {
    @ObservedObject var session: NotebookSession

    var body: some View {
        let store = session.store
        let provisional = store.goals.filter { store.isProvisional($0) }.count
        row(.contents, store.name, "book", bold: true)
        row(.goals, "Goals", "scope", indent: true,
            trailing: provisional > 0 ? "\(provisional) to confirm" : store.goals.isEmpty ? nil : "\(store.goals.filter { $0.str("status") == "working" }.count)")
        row(.notes, "Sophia's notes", "note.text", indent: true, trailing: noteCount == 0 ? nil : "\(noteCount)")
        if store.pages.isEmpty {
            Text("No pages yet.").font(.caption).lineLimit(1).foregroundStyle(.secondary).padding(.leading, 22)
        } else {
            Text("Book").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                .padding(.leading, 20).padding(.top, 8)
            ForEach(store.chapters) { c in
                chapterRow(c)
                if !collapsed.contains(c.id) { ForEach(c.pages) { p in pageRow(p, indent: 32) } }
            }
            ForEach(store.unfiledPages) { p in pageRow(p, indent: 14) }
        }
    }

    @State private var collapsed: Set<String> = []

    /// A chapter: its number and title, with a chevron that folds its pages away.
    func chapterRow(_ c: NotebookStore.Chapter) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) {
                if collapsed.contains(c.id) { collapsed.remove(c.id) } else { collapsed.insert(c.id) }
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold)).foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(collapsed.contains(c.id) ? 0 : 90)).frame(width: 16)
                if let n = c.number { Text(n).monospacedDigit().foregroundStyle(.secondary).fixedSize() }
                Text(c.title).fontWeight(.semibold).lineLimit(1).truncationMode(.tail)
                Spacer(minLength: 0)
            }
            .padding(.leading, 14).padding(.vertical, 3).padding(.horizontal, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(c.heading)
    }

    /// A page: its section number in a fixed column (or a page icon), then its title on one line.
    func pageRow(_ p: NotebookStore.Page, indent: CGFloat) -> some View {
        let (n, t) = pageNumber(session.store, p)
        let selected = session.place == .page(p.file)
        return Button { session.show(.page(p.file)) } label: {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if let n {
                    Text(n).monospacedDigit().foregroundStyle(.secondary).fixedSize().frame(minWidth: 24, alignment: .leading)
                } else {
                    Image(systemName: "doc.text").foregroundStyle(.secondary).frame(width: 16)
                }
                Text(t).lineLimit(1).truncationMode(.tail)
                Spacer(minLength: 0)
            }
            .padding(.leading, indent).padding(.vertical, 3).padding(.horizontal, 6)
            .background(selected ? Color.accentColor.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(p.title)
    }

    var noteCount: Int { session.store.shownNotes.count }

    @ViewBuilder
    func row(_ place: NotebookSession.Place, _ title: String, _ icon: String, bold: Bool = false, indent: Bool = false,
             indentBy: CGFloat? = nil, number: String? = nil, trailing: String? = nil, subtitle: String? = nil) -> some View {
        Button { session.show(place) } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundStyle(.secondary).frame(width: 16)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        if let number { Text(number).monospacedDigit().foregroundStyle(.secondary).fixedSize() }
                        Text(title).fontWeight(bold ? .semibold : .regular).lineLimit(1).truncationMode(.tail)
                    }
                    if let subtitle { Text(subtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
                }
                Spacer(minLength: 4)
                if let trailing { Text(trailing).font(.caption).foregroundStyle(.secondary).fixedSize() }
            }
            .padding(.leading, indentBy ?? (indent ? 14 : 0))
            .padding(.vertical, 3).padding(.horizontal, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(session.place == place ? Color.accentColor.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
    }
}

/// "About you", shared by every notebook.
struct AboutRow: View {
    @ObservedObject var session: NotebookSession
    var body: some View {
        let proposed = session.library.aboutLines(visibleIn: session.store.name).filter(LibraryStore.isProvisional).count
        Button { session.show(.about) } label: {
            HStack(spacing: 6) {
                Image(systemName: "person.crop.circle").foregroundStyle(.secondary).frame(width: 16)
                Text("About you").lineLimit(1)
                Spacer(minLength: 4)
                if proposed > 0 { Text("\(proposed) to confirm").font(.caption).foregroundStyle(.secondary).fixedSize() }
            }
            .padding(.vertical, 3).padding(.horizontal, 6)
            .background(session.place == .about ? Color.accentColor.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
