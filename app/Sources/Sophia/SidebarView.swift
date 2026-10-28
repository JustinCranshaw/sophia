import SwiftUI
import SophiaCore

/// Library, then the open notebook expanded in place, in a fixed order:
/// Goals and Sophia's notes, then the book's pages. Every row is one line: titles truncate, with the full title on hover.
struct SidebarView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject private var almanac: AlmanacModel

    var body: some View {
        VStack(spacing: 0) {
        List {
            Section("Library") {
                if let worker = almanac.worker {
                    NotebookRows(url: worker.url)
                } else {
                    Button("Sophia’s Almanac…") { almanac.settingsShown = true }
                }
                ForEach(model.notebooks.filter { $0 != almanac.worker?.url }, id: \.self) { url in
                    NotebookRows(url: url)
                }
            }
            if let s = model.open { Section("Shared across your Library") { AboutRow(session: s) } }
        }
        .listStyle(.sidebar)
        Divider()
        Button { NotificationCenter.default.post(name: .newNotebook, object: nil) } label: {
            Label("New Notebook…", systemImage: "plus")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16).padding(.vertical, 12).contentShape(Rectangle())
        }
        .buttonStyle(.plain).help("New notebook · ⌘N")
        .accessibilityLabel("New Notebook")
        }
    }
}

struct NotebookRows: View {
    @EnvironmentObject var model: AppModel
    let url: URL

    var body: some View {
        if let s = model.open, s.store.url == url {
            OpenNotebookRows(session: s)
        } else {
            Button { if model.openNotebook(url) { model.open?.show(.contents) } } label: {
                Label(url.lastPathComponent, systemImage: Almanac.isConfigured(url: url) ? "sun.max" : "book.closed").lineLimit(1).truncationMode(.tail)
            }
            .buttonStyle(.plain)
            .help(url.lastPathComponent)
            .modifier(NotebookCopyActions(url: url))
        }
    }
}

struct OpenNotebookRows: View {
    @ObservedObject var session: NotebookSession

    var body: some View {
        let store = session.store
        let entries = NotebookPresentation.almanacEntries(store)
        row(.contents, store.name, Almanac.isConfigured(url: store.url) ? "sun.max" : "book", bold: true)
            .modifier(NotebookCopyActions(url: store.url))
        if store.contentPages.isEmpty {
            Text("No pages yet.").font(.caption).lineLimit(1).foregroundStyle(.secondary).padding(.leading, 22)
        } else {
            ForEach(store.chapters) { c in
                chapterRow(c)
                if !collapsed.contains(c.id) { ForEach(c.pages) { p in pageRow(p, indent: 32, entry: entries[p.file]) } }
            }
            ForEach(store.unfiledPages) { p in pageRow(p, indent: 14, entry: entries[p.file]) }
        }
    }

    @State private var collapsed: Set<String> = []

    /// A chapter: its number and title, with a chevron that folds its pages away.
    func chapterRow(_ c: NotebookStore.Chapter) -> some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(.easeOut(duration: 0.15)) {
                    if collapsed.contains(c.id) { collapsed.remove(c.id) } else { collapsed.insert(c.id) }
                }
            } label: {
                Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(collapsed.contains(c.id) ? 0 : 90))
                    .frame(width: 24, height: 26).contentShape(Rectangle())
            }
            .accessibilityLabel((collapsed.contains(c.id) ? "Expand " : "Collapse ") + c.heading)
            Button { session.show(.chapter(c.id)) } label: {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if let n = c.number { Text(n).monospacedDigit().foregroundStyle(.secondary).fixedSize() }
                    Text(c.title).fontWeight(.semibold).lineLimit(1).truncationMode(.tail)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 5).padding(.trailing, 6).contentShape(Rectangle())
            }
            .help(c.heading)
        }
        .padding(.leading, 14)
        .background(session.place == .chapter(c.id) ? Brand.selectionFill : .clear, in: RoundedRectangle(cornerRadius: 6))
        .buttonStyle(.plain)
    }

    /// A page: its section number in a fixed column (or a page icon), then its title on one line.
    func pageRow(_ p: NotebookStore.Page, indent: CGFloat, entry: NotebookPresentation.Publication?) -> some View {
        let (n, t) = pageNumber(session.store, p)
        let selected = session.place == .page(p.file)
        return Button { session.show(.page(p.file)) } label: {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if let n {
                    Text(n).monospacedDigit().foregroundStyle(.secondary).fixedSize().frame(minWidth: 24, alignment: .leading)
                } else {
                    Image(systemName: "doc.text").foregroundStyle(.secondary).frame(width: 16)
                }
                VStack(alignment: .leading, spacing: 3) {
                    if let entry {
                        Text(NotebookPresentation.publicationDate(entry, abbreviated: true)).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }
                    Text(t).lineLimit(1).truncationMode(.tail)
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, indent).padding(.vertical, 3).padding(.horizontal, 6)
            .background(selected ? Brand.selectionFill : .clear, in: RoundedRectangle(cornerRadius: 6))
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
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
    }
}

/// "About you", shared by every notebook.
struct AboutRow: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var session: NotebookSession
    var body: some View {
        let proposed = session.library.aboutLines.filter(LibraryStore.isProvisional).count
        Button { session.show(.about) } label: {
            HStack(spacing: 6) {
                Image(systemName: "person.crop.circle").foregroundStyle(.secondary).frame(width: 16)
                Text("About you").lineLimit(1)
                Spacer(minLength: 4)
                if proposed > 0 { Text("\(proposed) to confirm").font(.caption).foregroundStyle(.secondary).fixedSize() }
            }
            .padding(.vertical, 3).padding(.horizontal, 6)
            .background(session.place == .about ? Brand.selectionFill : .clear, in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
