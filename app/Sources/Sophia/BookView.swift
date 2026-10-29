import SwiftUI
import SophiaCore
import SophiaReader

struct BookView: View {
    @ObservedObject var session: NotebookSession
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
        if model.conversationCollapsed && !session.editRecovery.edits.isEmpty { PageRecoveryView(session: session).padding(12) }
        Group {
            switch session.place {
            case .contents:
                if let page = session.store.overviewPage { PageView(session: session, file: page.file).id(session.store.url.appendingPathComponent(page.file)) }
                else { Sheet { ReadingTitle(title: session.store.name); Banner(tone: .problem, text: "The introduction is unavailable. Existing pages are still readable."); ContentsOutline(session: session) } }
            case .goals, .notes, .memory:
                if let page = session.visiblePage { PageView(session: session, file: page.file).id(session.store.url.appendingPathComponent(page.file)) }
                else { Sheet { Intro("This notebook page is unavailable. Your existing pages and history remain available.") } }
            case .about:
                if session.isSharedAbout, let page = session.visiblePage { PageView(session: session, file: page.file).id(session.store.url.appendingPathComponent(page.file)) }
                else { Sheet { Text("Choose About you in the Library to open its shared page and conversation.") } }
            case .chapter(let id):
                if let page = session.store.chapters.first(where: { $0.id == id })?.intro {
                    PageView(session: session, file: page.file).id(session.store.url.appendingPathComponent(page.file))
                } else { Sheet { Intro("This chapter is no longer available."); Button("Open notebook contents") { session.show(.contents) } } }
            case .page(let file):
                // A different page starts a fresh reader, including the same filename in another notebook.
                PageView(session: session, file: file).id(session.store.url.appendingPathComponent(file))
            }
        }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .textBackgroundColor))
    }
}

/// Shared column for book content.
struct Sheet<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) { content }
                .frame(maxWidth: 660, alignment: .leading)
                .padding(.horizontal, 36).padding(.vertical, 32)
                .frame(maxWidth: .infinity)
        }
    }
}

/// Shared title treatment for notebook overviews and Library reading surfaces.
struct ReadingTitle: View {
    let title: String
    var scope: String? = nil
    var number: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let scope {
                Text(scope).font(.system(size: 11, weight: .semibold)).tracking(1.2)
                    .textCase(.uppercase).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.tail).help(scope)
            }
            ((number.map { Text($0 + "  ").font(.system(size: 28, weight: .regular, design: .serif)).foregroundColor(.secondary) } ?? Text(""))
                + Text(title).font(.system(size: 28, weight: .semibold, design: .serif)))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct Banner: View {
    enum Tone { case draft, saved, plain, problem }
    let tone: Tone
    let text: String
    var body: some View {
        Text(text).font(.callout)
            .padding(.horizontal, 12).padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(color.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: tone == .draft ? [4, 3] : [])))
    }
    var color: Color { switch tone { case .draft: .orange; case .saved: .green; case .plain: .gray; case .problem: .red } }
}

/// Sophia's words in the book-side views: system face, own label line, behind a quiet rule.
struct SophiaText: View {
    let label: String
    let text: String
    var trailing: String? = nil
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 1).fill(Color.secondary.opacity(0.35)).frame(width: 2)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(label.uppercased()).font(.system(size: 10, weight: .bold)).tracking(0.6).foregroundStyle(.secondary)
                    if let trailing { Text(trailing).font(.system(size: 10)).foregroundStyle(.secondary) }
                }
                MarkdownView(text: text, style: .chat)
                    .frame(maxWidth: 560, alignment: .leading)
            }
        }
        .padding(.leading, 2)
    }
}

/// The person's own words, set as the page renderer sets a quotation.
struct PersonQuote: View {
    let text: String
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 1).fill(Color.primary.opacity(0.5)).frame(width: 2)
            Text(MarkdownView.scripts(AttributedString(text), size: 17, design: .serif))
                .font(.system(size: 17, design: .serif).italic()).lineSpacing(6).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Intro text under a book-side title.
struct Intro: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(.system(size: 14)).lineSpacing(3).foregroundStyle(.secondary)
            .frame(maxWidth: 620, alignment: .leading).fixedSize(horizontal: false, vertical: true)
    }
}

extension View {
    func card() -> some View {
        padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.08)))
    }
}

func shortDate(_ iso: String?) -> String {
    guard let iso, let d = ISO8601DateFormatter().date(from: iso) else { return "" }
    return d.formatted(.dateTime.month(.abbreviated).day())
}

// MARK: Contents

/// A page's section number, set apart from its title. Titles carry their own numbers
/// ("0.1 Surprise…"); a bare number counts only inside a numbered chapter, so "2024 Elections" stays a title.
func pageNumber(_ store: NotebookStore, _ page: NotebookStore.Page) -> (number: String?, title: String) {
    let (n, rest) = NotebookStore.splitNumber(page.title)
    guard let n, n.contains(".") || store.chapter(of: page.file)?.number != nil else { return (nil, page.title) }
    return (n, rest)
}

/// A chapter is a heading in the outline, not a breadcrumb above a page.
struct ChapterOutlineHeading: View {
    let chapter: NotebookStore.Chapter
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(chapter.number ?? "").foregroundStyle(.secondary).frame(width: 34, alignment: .leading)
            Text(chapter.title)
        }
        .font(.system(size: 21, weight: .semibold, design: .serif))
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct ContentsRow: View {
    let number: String
    let title: String
    let action: () -> Void
    @State private var hover = false
    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(number).font(.system(size: 17, design: .serif)).monospacedDigit().foregroundStyle(.secondary).frame(width: 34, alignment: .leading)
                Text(title).font(.system(size: 17, design: .serif)).foregroundStyle(.primary).underline(hover)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

/// The outline is attached to an ordinary editable overview page; it is never stored as authored prose.
struct ContentsOutline: View {
    @ObservedObject var session: NotebookSession
    @EnvironmentObject private var model: AppModel
    var chapterID: String? = nil
    var body: some View {
        let store = session.store
        let intro = chapterID.flatMap { id in store.chapters.first(where: { $0.id == id })?.intro } ?? store.overviewPage
        let hasIntroduction = intro.flatMap { store.readPage($0.file)?.body }.map { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? false
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            if chapterID == nil, Almanac.isConfigured(url: store.url),
               let worker = model.almanac.worker, worker.url == store.url {
                AlmanacHomeControls(worker: worker, almanac: model.almanac)
            }
            if hasIntroduction || chapterID == nil {
                HStack(alignment: .firstTextBaseline) {
                    Text("Contents").font(.system(size: 11, weight: .semibold)).tracking(1.2)
                        .textCase(.uppercase).foregroundStyle(.secondary)
                    Spacer()
                    if chapterID == nil, !store.deletedPages.isEmpty {
                        HStack(spacing: 6) {
                            Text("\(store.deletedPages.count) deleted page\(store.deletedPages.count == 1 ? "" : "s")").foregroundStyle(.secondary)
                            Button("Restore…") { model.deletedPagesNotebook = store.url }.buttonStyle(.link)
                        }.font(.callout)
                    }
                }
            }
            if let chapterID, let chapter = store.chapters.first(where: { $0.id == chapterID }) {
                rows(chapter.pages)
                if chapter.pages.isEmpty { Intro("No pages in this chapter yet.") }
            } else {
                if store.contentPages.isEmpty { Intro("No pages yet. Start with a question; keep a page when there is something useful to return to.") }
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(store.chapters) { chapter in
                        VStack(alignment: .leading, spacing: 8) {
                            Button { session.show(.chapter(chapter.id)) } label: { ChapterOutlineHeading(chapter: chapter) }
                                .buttonStyle(.plain).help("Open " + chapter.heading)
                            rows(chapter.pages)
                        }
                    }
                    if !store.unfiledPages.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            if !store.chapters.isEmpty {
                                Text("Not in a chapter").font(.system(size: 11, weight: .semibold)).tracking(1.2)
                                    .textCase(.uppercase).foregroundStyle(.secondary)
                            }
                            rows(store.unfiledPages)
                        }
                    }
                }
                Button("Goals & intentions…") { model.showNotebookSettings(store.url, section: .goals) }.buttonStyle(.borderless)
            }
        }
    }

    func rows(_ pages: [NotebookStore.Page]) -> some View {
        let entries = NotebookPresentation.almanacEntries(session.store)
        return VStack(alignment: .leading, spacing: 10) {
            ForEach(pages) { p in
                let (n, t) = pageNumber(session.store, p)
                VStack(alignment: .leading, spacing: 3) {
                    if let entry = entries[p.file] {
                        Text(NotebookPresentation.publicationDate(entry)).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }
                    ContentsRow(number: n ?? "", title: t) { session.show(.page(p.file)) }
                }
            }
        }
    }
}

// MARK: Pages and drafts

struct PageView: View {
    @ObservedObject var session: NotebookSession
    let file: String
    private struct PreviousVersion: Identifiable {
        let id = UUID()
        let title: String
        let body: String
    }
    @State private var previous: PreviousVersion?
    @State private var headingCount = 0
    private func navigate(_ proxy: ScrollViewProxy) {
        guard session.visiblePage?.file == file, let target = session.sectionNavigation.target else { return }
        let request = session.pendingSectionID
        guard session.editing?.file != file else {
            session.navigationProblem = .init(file: file, text: "Finish editing, then choose the section again.")
            session.pendingSection = nil
            return
        }
        switch target.resolve(in: session.store) {
        case .failure(let error):
            session.navigationProblem = .init(file: file, text: error.localizedDescription)
            session.pendingSection = nil
        case .success(let index):
            guard headingCount > 0 else { return } // wait for the actual renderer's anchors
            guard headingCount == session.store.editRanges(of: file).filter({ $0.index != nil }).count,
                  index < headingCount else {
                session.navigationProblem = .init(file: file, text: "This section could not be located in the rendered page. You can still read the page.")
                session.pendingSection = nil
                return
            }
            DispatchQueue.main.async {
                guard session.visiblePage?.file == file, session.pendingSectionID == request else { return }
                proxy.scrollTo("section-\(index)", anchor: .top)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                if session.visiblePage?.file == file, session.pendingSectionID == request { session.pendingSection = nil }
            }
        }
    }
    var body: some View {
        if let page = session.store.readPage(file) {
            ScrollViewReader { proxy in
            Sheet {
                let store = session.store
                // Permission records and unchanged requests do not establish content provenance.
                let provenance = store.transcript.last { entry in
                    entry.str("file") == file && entry["unchanged"] != .bool(true)
                        && ((entry.str("tool") == "write_page" && entry["refused"] != .bool(true))
                            || ["edit_page", "undo_page"].contains(entry.str("purpose") ?? ""))
                }
                if provenance?["recovered"] == .bool(true) {
                    VStack(alignment: .leading, spacing: 8) {
                        Banner(tone: .plain, text: "An unrecorded page change was found. Its author is unknown; it has no Undo.")
                        if store.hasPreviousVersion(file) {
                            Button("Previous version") {
                                if let value = store.readPreviousVersion(file) {
                                    previous = PreviousVersion(title: value.title, body: value.body)
                                }
                            }
                        }
                    }
                }
                let chapter = store.chapter(of: file) ?? store.chapters.first(where: { $0.intro?.file == file })
                let hidden = NotebookStore.repeatedHeadingLines(in: page.body, title: page.title, chapter: chapter)
                let ranges = NotebookStore.editRanges(in: page.body, hidden: hidden)
                let (number, title) = pageNumber(store, .init(file: file, title: page.title))
                let rootChapter = store.chapters.first(where: { $0.intro?.file == file })
                let publication = NotebookPresentation.almanacEntries(store)[file]
                ReadingTitle(title: title,
                             scope: store.page(file)?.role == .about ? "Shared across your Library" : [.goals, .notes, .memory].contains(store.page(file)?.role) || rootChapter != nil || publication != nil ? store.name : chapter?.heading,
                             number: rootChapter?.number ?? number)
                if [.about, .goals].contains(store.page(file)?.role) {
                    Text("Sophia proposes changes for you to review.").font(.callout).foregroundStyle(.secondary)
                }
                HStack {
                    if let entry = publication {
                        Text(NotebookPresentation.publicationDate(entry)).font(.system(size: 14, weight: .semibold)).foregroundStyle(.secondary)
                    }
                    if ranges.contains(where: { $0.index != nil }) {
                        Menu("Sections") {
                            ForEach(ranges.filter { $0.index != nil }, id: \.key) { range in
                                Button(range.label + " · " + range.section) {
                                    session.openSection(.exact(notebook: store.url, file: file, range: range))
                                }
                            }
                        }.controlSize(.small).disabled(session.editing?.file == file)
                    }
                    if !session.visiblePageProposals.isEmpty {
                        Text("\(session.visiblePageProposals.count) proposed change\(session.visiblePageProposals.count == 1 ? "" : "s")").font(.callout).foregroundStyle(.secondary)
                        Button("Review changes") { session.reviewProposalID = session.visiblePageProposals.first?.str("id") }
                            .buttonStyle(.bordered).controlSize(.small)
                    }
                    Spacer(minLength: 8)
                    Button("Edit") { session.beginEdit(file: file, key: "(page)", atVisibleTop: true) }
                        .buttonStyle(.bordered).controlSize(.small).disabled(session.editing != nil)
                        .accessibilityLabel("Edit page")
                    Menu { PageRemovalActions(store: store, file: file) } label: { Image(systemName: "ellipsis") }
                        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().accessibilityLabel("Page actions")
                    if let write = session.undoableWrite(for: file), let action = store.transcript.first(where: { $0.str("id") == write }) {
                        Button { session.undoWrite(write) } label: {
                            Label(action.str("purpose") == "edit_page" ? "Undo edit" : action.str("purpose") == "release_edit" ? "Undo permission" : "Undo change", systemImage: "arrow.uturn.backward")
                        }
                            .buttonStyle(.bordered).controlSize(.small)
                            .accessibilityLabel(undoLabel(action) + " on “" + page.title + "”")
                            .help(undoLabel(action) + ". Available until the next action on this page.")
                    }
                }
                if let write = session.undoableWrite(for: file), let action = store.transcript.first(where: { $0.str("id") == write }), action.str("purpose") == "release_edit" {
                    Text("Sophia may change your released edit on your next message.").font(.caption).foregroundStyle(.secondary)
                }
                if let notice = session.navigationProblem, notice.file == file {
                    Text(notice.text).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                }

                MarkdownView(text: page.body.components(separatedBy: "\n").dropFirst(hidden).joined(separator: "\n"), anchors: true,
                             sections: ranges.filter { $0.key != "(page)" }.map { reader($0, hidden) },
                             editor: editor(ranges, hidden), onEdit: { session.handle($0, file: file) }, onHeadings: { headings in
                    headingCount = headings.count
                    navigate(proxy)
                }, onMusic: { tunes in
                    // Name each tune's section: the innermost one holding the line its fence starts on.
                    session.noteMusic(file: file, warnings: tunes.filter { !$0.warnings.isEmpty }.map { t in
                        let section = t.line.flatMap { NotebookStore.sectionTitle(containing: $0 + hidden, in: ranges) }
                        return MusicWarnings(file: file, page: page.title, section: section, tune: t.title, warnings: t.warnings)
                    })
                })
                .frame(height: page.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && session.editing?.file != file ? 0 : nil)
                .clipped()
                if store.page(file)?.role == .notebook {
                    ContentsOutline(session: session)
                } else if store.page(file)?.role == .chapter,
                          let chapter = store.chapters.first(where: { $0.intro?.file == file }) {
                    ContentsOutline(session: session, chapterID: chapter.id)
                }
                if [.goals, .notes, .memory].contains(store.page(file)?.role) {
                    NotebookPageHistory(session: session)
                }
                let links = session.library.links(touching: store.name).filter { l in
                    (l["from"]?["notebook"]?.string == store.name && l["from"]?["page"]?.string == file)
                        || (l["to"]?["notebook"]?.string == store.name && l["to"]?["page"]?.string == file)
                }
                if !links.isEmpty {
                    Divider().padding(.top, 12)
                    Text("CONNECTED PAGES").font(.system(size: 10, weight: .bold)).tracking(0.6).foregroundStyle(.secondary)
                    LinksList(session: session, links: links)
                }
            }
            .onChange(of: session.pendingSectionID) { _, _ in navigate(proxy) }
            }
            .sheet(isPresented: Binding(get: { session.reviewProposalID != nil }, set: { if !$0 { session.reviewProposalID = nil } })) {
                if let id = session.reviewProposalID { PageProposalReview(session: session, proposalID: id) }
            }
            .sheet(item: $previous) { snapshot in
                VStack(alignment: .leading, spacing: 12) {
                    Text("Previous version: \(snapshot.title)").font(.headline)
                    Text("Nothing is applied here. To restore wording, copy it into the page editor.")
                        .font(.callout).foregroundStyle(.secondary)
                    ScrollView {
                        Text(verbatim: snapshot.body).font(.system(.body, design: .monospaced))
                            .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(12)
                    }
                    HStack {
                        Button("Copy Markdown") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(snapshot.body, forType: .string)
                        }
                        Spacer()
                        Button("Done") { previous = nil }.keyboardShortcut(.cancelAction)
                    }
                }.padding(20).frame(width: 620, height: 460)
            }
        } else {
            Sheet {
                Text("This page file is unavailable.").foregroundStyle(.secondary)
                if session.store.page(file)?.role == .notebook { ContentsOutline(session: session) }
                else if let chapter = session.store.chapters.first(where: { $0.intro?.file == file }) {
                    ReadingTitle(title: chapter.title)
                    ContentsOutline(session: session, chapterID: chapter.id)
                }
            }
        }
    }

    /// A range of the body in the lines the reader shows, which leave out a repeated title.
    func reader(_ r: NotebookStore.EditRange, _ hidden: Int) -> ReaderSection {
        ReaderSection(key: r.key, label: r.label, start: r.lines.lowerBound - hidden, end: r.lines.upperBound - hidden)
    }

    /// The open editor on this page, placed where its range is now: found by its text (Sophia may
    /// have revised other sections, moving it), else by its key when it changed underneath.
    func editor(_ ranges: [NotebookStore.EditRange], _ hidden: Int) -> ReaderEditor? {
        guard let e = session.editing, e.file == file else { return nil }
        let base = e.conflict ?? e.range
        guard let here = ranges.first(where: { $0.hash == base.hash && $0.key == base.key }) ?? ranges.first(where: { $0.hash == base.hash })
                ?? ranges.first(where: { $0.key == base.key }) else { return nil }
        let r = reader(here, hidden)
        var editor = ReaderEditor(id: e.id, label: here.label, start: r.start, end: r.end, text: e.range.text, hash: e.range.hash)
        editor.dimmed = session.composerFocused
        editor.conflict = e.conflict?.text
        editor.atVisibleTop = e.atVisibleTop
        return editor
    }

    private func undoLabel(_ action: JSONObject) -> String {
        if action.str("purpose") == "edit_page" { return "Undo your edit" }
        if action.str("purpose") == "release_edit" { return "Undo permission to change your edit" }
        return "Undo Sophia's change"
    }


}
