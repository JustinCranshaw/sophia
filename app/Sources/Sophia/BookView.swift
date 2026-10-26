import SwiftUI
import SophiaCore
import SophiaReader

struct BookView: View {
    @ObservedObject var session: NotebookSession

    var body: some View {
        Group {
            switch session.place {
            case .contents: ContentsView(session: session)
            case .goals: GoalsView(session: session)
            case .notes: NotesView(session: session)
            case .about: AboutView(session: session)
            case .page(let file):
                // A different page starts a fresh reader, including the same filename in another notebook.
                PageView(session: session, file: file).id(session.store.url.appendingPathComponent(file))
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
            RoundedRectangle(cornerRadius: 1).fill(Color.accentColor.opacity(0.6)).frame(width: 2)
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

/// "CHAPTER 0 · FOUNDATIONS": the small label above a chapter's pages.
struct ChapterLabel: View {
    let chapter: NotebookStore.Chapter
    var body: some View {
        Text((chapter.number.map { "Chapter \($0) · " } ?? "") + chapter.title)
            .font(.system(size: 11, weight: .semibold)).tracking(1.2).textCase(.uppercase)
            .foregroundStyle(Color.accentColor)
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
                Text(title).font(.system(size: 18, design: .serif)).foregroundStyle(hover ? Color.accentColor : .primary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

struct ContentsView: View {
    @ObservedObject var session: NotebookSession
    @EnvironmentObject private var model: AppModel
    var body: some View {
        let store = session.store
        Sheet {
            Text(store.name).font(.system(size: 32, weight: .semibold, design: .serif))
            if Almanac.isConfigured(url: store.url) {
                Intro("A collection of finished discoveries. Open an entry to read; a response is never required.")
                if let worker = model.almanac.worker, worker.url == store.url {
                    AlmanacHomeControls(worker: worker, almanac: model.almanac)
                }
            } else {
                let goals = NotebookPresentation.confirmedGoals(store)
                if !goals.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("WHAT YOU WANT TO EXPLORE").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        ForEach(Array(goals.prefix(3)), id: \.self.line) { goal in
                            Text(goal.str("text") ?? "").font(.system(size: 18, design: .serif))
                        }
                    }
                }
                HStack {
                    Button("Goals & intentions…") { model.showNotebookSettings(store.url, section: .goals) }
                    let proposals = store.goals.filter { store.isProvisional($0) }.count
                    if proposals > 0 { Text("\(proposals) proposal\(proposals == 1 ? "" : "s") to review").font(.caption).foregroundStyle(.secondary) }
                }.buttonStyle(.borderless)
                if let inquiry = NotebookPresentation.earlyInquiry(store) {
                    DisclosureGroup("An early question from this notebook") {
                        Text(inquiry).textSelection(.enabled).font(.callout)
                        Text("From the saved conversation; this may not describe your current aim.").font(.caption).foregroundStyle(.secondary)
                    }.font(.callout)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text("HOW SOPHIA WORKS HERE · GENERAL APPROACH").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text("Explore through explanations, questions and sources. Keep useful ideas as pages, revisit them, and change direction as your inquiry develops. This is not a prescribed course or an assessment of you.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            Divider()
            HStack {
                Text(Almanac.isConfigured(url: store.url) ? "Entries" : "Contents").font(.system(size: 23, weight: .semibold, design: .serif))
                Spacer()
                Text("\(store.pages.count) page\(store.pages.count == 1 ? "" : "s")").font(.caption).foregroundStyle(.secondary)
            }
            if store.pages.isEmpty {
                Intro("No pages yet. Begin with a question in the notebook conversation; a page is kept when there is something useful to return to.")
            }
            ForEach(store.chapters) { chapter in
                VStack(alignment: .leading, spacing: 12) {
                    ChapterLabel(chapter: chapter)
                    rows(chapter.pages)
                }.padding(.top, 8)
            }
            rows(store.unfiledPages)
        }
    }
}

extension ContentsView {
    func rows(_ pages: [NotebookStore.Page]) -> some View {
        let entries = NotebookPresentation.almanacEntries(session.store)
        return VStack(alignment: .leading, spacing: 12) {
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
        guard session.place == .page(file), let target = session.sectionNavigation.target else { return }
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
                guard session.place == .page(file), session.pendingSectionID == request else { return }
                proxy.scrollTo("section-\(index)", anchor: .top)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                if session.place == .page(file), session.pendingSectionID == request { session.pendingSection = nil }
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
                let chapter = store.chapter(of: file)
                let hidden = NotebookStore.repeatedHeadingLines(in: page.body, title: page.title, chapter: chapter)
                let ranges = NotebookStore.editRanges(in: page.body, hidden: hidden)
                let (number, title) = pageNumber(store, .init(file: file, title: page.title))
                VStack(alignment: .leading, spacing: 8) {
                    if let chapter { ChapterLabel(chapter: chapter) }
                    // The number runs into the title, as the page's own numbered headings do, in a lighter weight.
                    ((number.map { Text($0 + "  ").font(.system(size: 30, weight: .light, design: .serif)).foregroundColor(.secondary) } ?? Text(""))
                        + Text(title).font(.system(size: 30, weight: .semibold, design: .serif)))
                        .tracking(-0.3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack {
                    if let entry = NotebookPresentation.almanacEntries(store)[file] {
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
                    Spacer(minLength: 8)
                    if let write = session.undoableWrite(for: file), let action = store.transcript.first(where: { $0.str("id") == write }) {
                        Button { session.undoWrite(write) } label: { Label("Undo", systemImage: "arrow.uturn.backward") }
                            .buttonStyle(.borderless).controlSize(.small)
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
            Sheet { Text("This page isn't in the book.").foregroundStyle(.secondary) }
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

// MARK: Notes

struct NotesView: View {
    @ObservedObject var session: NotebookSession
    @State private var correcting: String?
    @State private var draft = ""

    var body: some View {
        let store = session.store
        let notes = store.shownNotes
        Sheet {
            Text("Sophia's notes").font(.system(size: 28, weight: .semibold, design: .serif))
            Intro("Sophia keeps these as you talk, and adds to them when you come back after a break or end a session. She uses them to follow up and to pick up where you left off. They aren't pages and they aren't a score. Every note rests on something you said or did. Correct or delete anything.")
            if let problem = session.learningProblem {
                HStack(alignment: .top) {
                    Banner(tone: .problem, text: problem)
                    Button("Dismiss") { session.learningProblem = nil }.controlSize(.small)
                }
            }
            if let removed = session.lastDeleted {
                HStack { Banner(tone: .plain, text: "Deleted \(removed.count) record\(removed.count == 1 ? "" : "s"). Your words are still in the conversation."); Button("Undo") { session.undoDelete() } }
            }
            MemoryCard(session: session)
            if notes.isEmpty {
                Text("No notes yet. Sophia adds them as you talk, when something is worth checking on later.").foregroundStyle(.secondary)
            }
            VStack(spacing: 14) { ForEach(notes.reversed(), id: \.self.line) { r in card(r) } }
        }
    }

    @ViewBuilder
    func card(_ r: JSONObject) -> some View {
        let id = r.str("id") ?? ""
        let kind = r.str("kind") ?? ""
        let correction = session.store.correction(of: id)
        VStack(alignment: .leading, spacing: 8) {
            Text("\(kind.replacingOccurrences(of: "_", with: " ").prefix(1).uppercased() + kind.replacingOccurrences(of: "_", with: " ").dropFirst()) · \(shortDate(r.str("at")))").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
            if let q = r["quote"]?.object {
                PersonQuote(text: q.str("text") ?? "")
            } else if r["paraphrase"] == .bool(true) {
                Text("Sophia's paraphrase — the exact words couldn't be matched to the conversation.").font(.caption).italic().foregroundStyle(.secondary)
            }
            if let c = correction {
                HStack(alignment: .top, spacing: 8) {
                    RoundedRectangle(cornerRadius: 1).fill(Color.accentColor).frame(width: 3)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Your correction · \(shortDate(c.str("at")))").font(.caption2.weight(.bold)).foregroundStyle(Color.accentColor)
                        Text(c.str("text") ?? "").font(.system(size: 15, design: .serif))
                    }
                }
                Text("Was, Sophia's read: “\(r.str("text") ?? "")”").font(.caption).foregroundStyle(.secondary)
            } else {
                SophiaText(label: kind == "attempt" ? "Sophia's read" : "Sophia", text: r.str("text") ?? "")
            }
            let refs = (r["refs"]?.array ?? []).compactMap(\.string)
            EvidenceLinks(session: session, refs: refs)
            if correcting == id {
                TextEditor(text: $draft).font(.system(size: 15, design: .serif)).frame(height: 70)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
                HStack { Button("Save correction") { if session.correct(id, text: draft) { correcting = nil } }.buttonStyle(.borderedProminent); Button("Cancel") { correcting = nil } }
            } else {
                HStack {
                    Button(correction == nil ? "Correct" : "Edit correction") {
                        draft = correction?.str("text") ?? r.str("text") ?? ""
                        correcting = id
                    }
                    Button("Delete", role: .destructive) { session.delete(id) }
                    ShowRecord(record: r)
                }.controlSize(.small)
            }
        }
        .card()
    }
}

struct ShowRecord: View {
    let record: JSONObject
    @State private var shown = false
    var body: some View {
        Button(shown ? "Hide record" : "Show record") { shown.toggle() }
            .popover(isPresented: $shown) {
                ScrollView { Text(JSON.object(record).pretty).font(.caption.monospaced()).textSelection(.enabled).padding(12) }
                    .frame(width: 420, height: 240)
            }
    }
}

// MARK: Goals

struct GoalsView: View {
    @ObservedObject var session: NotebookSession
    @State private var newGoal = ""
    @State private var editing: String?
    @State private var text = ""
    @State private var criterion = ""

    private var hasStaleDraft: Bool {
        guard let editing else { return false }
        return !session.store.goals.contains { $0.str("id") == editing }
    }

    var body: some View {
        let store = session.store
        ScrollViewReader { proxy in
            Sheet {
                Text("Goals").font(.system(size: 28, weight: .semibold, design: .serif))
                Intro("What you want from this notebook. Sophia notes goals as you talk; they stay provisional until you confirm them. Under each goal: what you've done toward it and what Sophia makes of it. There's no score, and only you mark a goal met or drop it.")
                if let problem = session.goalProblem, session.goalReviewID == nil {
                    HStack { Banner(tone: .problem, text: problem); Button("Dismiss") { session.goalProblem = nil } }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("New goal").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    TextField("What do you want from this notebook?", text: $newGoal, axis: .vertical)
                        .font(.system(size: 17, design: .serif)).textFieldStyle(.roundedBorder)
                        .onSubmit { if session.addGoal(newGoal) { newGoal = "" } }
                    Button("Add goal") { if session.addGoal(newGoal) { newGoal = "" } }.disabled(newGoal.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if hasStaleDraft {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Unsaved goal wording").font(.headline)
                        Text("The goal changed before this wording could be saved. Copy it before dismissing if you want to use it later.").font(.caption).foregroundStyle(.secondary)
                        Text(text).textSelection(.enabled)
                        Button("Dismiss unsaved wording") { editing = nil; text = "" }
                    }.card().id("unsaved-goal-wording")
                }
                VStack(spacing: 14) { ForEach(store.goals.reversed(), id: \.self.line) { g in goalCard(g).id(g.str("id") ?? "") } }
                if !store.attemptsWithoutCriterionLinks.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Captured attempts not linked to a criterion").font(.headline)
                        Text("These saved attempts have no current criterion link. They may have a read elsewhere; no relevance or completion is inferred here.").font(.caption).foregroundStyle(.secondary)
                        ForEach(store.attemptsWithoutCriterionLinks, id: \.self.line) { attempt in attemptEvidence(attempt) }
                    }.card()
                }
            }
            .onChange(of: session.goalReviewID, initial: true) { _, id in
                guard let target = hasStaleDraft ? "unsaved-goal-wording" : id else { return }
                DispatchQueue.main.async { proxy.scrollTo(target, anchor: .top) }
            }
        }
    }

    @ViewBuilder
    func goalCard(_ g: JSONObject) -> some View {
        let store = session.store
        let id = g.str("id") ?? ""
        let root = store.rootID(of: id)
        let status = g.str("status") ?? "working"
        VStack(alignment: .leading, spacing: 10) {
            let provisional = store.isProvisional(g)
            HStack(spacing: 6) {
                Text(status == "working" ? "WORKING ON" : status == "met" ? "✓ MET · marked by you" : "DROPPED")
                    .font(.caption2.weight(.bold)).foregroundStyle(status == "met" ? Color.green : Color.accentColor)
                if provisional {
                    Text("· PROVISIONAL · \(g.str("replaces") == nil ? "noted" : "revised") by Sophia").font(.caption2.weight(.bold)).foregroundStyle(.orange)
                }
            }
            if let problem = session.goalProblem, session.goalReviewID == id {
                HStack { Banner(tone: .problem, text: problem); Button("Dismiss") { session.goalProblem = nil } }
            }
            if editing == id {
                TextField("Goal", text: $text, axis: .vertical).font(.system(size: 19, design: .serif)).textFieldStyle(.roundedBorder)
                HStack { Button("Save") { if session.updateGoal(g, text: text) { editing = nil } }.buttonStyle(.borderedProminent); Button("Cancel") { editing = nil } }
            } else {
                Text(MarkdownView.scripts(AttributedString(g.str("text") ?? ""), size: 20, design: .serif)).font(.system(size: 20, weight: .semibold, design: .serif))
            }
            if provisional, let q = g["quote"]?.object?.str("text") { PersonQuote(text: q) }
            if provisional, let prevID = g.str("replaces"), let prev = store.record(prevID) {
                Text("Earlier version: \(prev.str("text") ?? "")").font(.system(size: 12)).foregroundStyle(.secondary)
                Text("\(store.isProvisional(prev) ? "Provisional" : "Confirmed by you") · \(prev["criteria"]?.array?.count ?? 0) criteria").font(.caption).foregroundStyle(.secondary)
            }
            let criteria = (g["criteria"]?.array ?? []).compactMap(\.string)
            ForEach(Array(criteria.enumerated()), id: \.offset) { i, c in
                criterionRow(root: root, index: i + 1, text: c)
            }
            if provisional {
                HStack {
                    Button("Confirm") { session.confirmGoal(g) }.buttonStyle(.borderedProminent)
                    let previous = g.str("replaces").flatMap { store.record($0) }
                    let compatible = previous.map { ($0["criteria"]?.array ?? []) == (g["criteria"]?.array ?? []) } ?? false
                    Button(g.str("replaces") == nil ? "Not my goal" : "Keep the earlier version") { session.discardGoal(g) }
                        .disabled(g.str("replaces") != nil && !compatible)
                    if g.str("replaces") != nil { Button("Drop goal") { session.dropGoalProposal(g) } }
                }.controlSize(.small)
                if let previousID = g.str("replaces"), let previous = store.record(previousID), (previous["criteria"]?.array ?? []) != (g["criteria"]?.array ?? []) {
                    Text("Earlier criteria differ. Keeping that version could reassign saved or undoable evidence; leave this provisional, drop the whole goal, or choose a separate narrower goal.").font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("You can leave this provisional and keep talking without confirming.").font(.caption).foregroundStyle(.secondary)
                }
            } else {
                HStack {
                    TextField("Add what “there” looks like…", text: $criterion).textFieldStyle(.roundedBorder)
                        .onSubmit { if session.updateGoal(g, addCriterion: criterion) { criterion = "" } }
                }
                HStack {
                    if status == "working" {
                        Button("Mark as met") { session.updateGoal(g, status: "met") }
                        Button("Reword") { text = g.str("text") ?? ""; editing = id }.disabled(hasStaleDraft)
                        Button("Drop") { session.updateGoal(g, status: "dropped") }
                    } else {
                        Button("Reopen") { session.updateGoal(g, status: "working") }
                    }
                    Spacer()
                    ShowRecord(record: g)
                }.controlSize(.small)
            }
            if provisional { ShowRecord(record: g).controlSize(.small) }
        }
        .card()
    }

    @ViewBuilder
    func interpretation(_ record: JSONObject, label: String) -> some View {
        if let correction = session.store.correction(of: record.str("id") ?? "") {
            Text("Your correction · \(shortDate(correction.str("at")))").font(.caption.weight(.semibold)).foregroundStyle(Color.accentColor)
            Text(correction.str("text") ?? "").textSelection(.enabled)
            Text("Was, Sophia's read: “\(record.str("text") ?? "")”").font(.caption).foregroundStyle(.secondary)
        } else {
            SophiaText(label: label, text: record.str("text") ?? "", trailing: "· " + shortDate(record.str("at")))
        }
    }

    @ViewBuilder
    func attemptEvidence(_ attempt: JSONObject) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Captured attempt · \(shortDate(attempt.str("at")))").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            let sources = session.store.attemptSourceReferences(attempt)
            if let quote = attempt["quote"]?["text"]?.string {
                PersonQuote(text: quote).textSelection(.enabled)
            } else {
                Text(sources.isEmpty ? "No exact words or exchange were saved with this attempt note." : "No exact quote saved with this attempt note; inspect its cited material.").font(.caption).foregroundStyle(.secondary)
            }
            interpretation(attempt, label: "Sophia's read · tentative")
            EvidenceLinks(session: session, refs: sources)
        }.padding(.vertical, 6)
    }

    @ViewBuilder
    func criterionRow(root: String, index: Int, text: String) -> some View {
        let store = session.store
        let ref = "\(root)#\(index)"
        let evidence = store.evidence(forCriterion: ref)
        VStack(alignment: .leading, spacing: 8) {
            Text(MarkdownView.scripts(AttributedString("\(index). \(text)"), size: 17, design: .serif)).font(.system(size: 17, design: .serif)).lineSpacing(5).fixedSize(horizontal: false, vertical: true)
            if evidence.attempts.isEmpty {
                Text("No saved attempt linked to this criterion.").font(.caption).italic().foregroundStyle(.secondary)
            } else {
                ForEach(evidence.attempts, id: \.self.line) { attempt in attemptEvidence(attempt) }
                if evidence.read == nil { Text("No criterion-level read saved yet.").font(.caption).foregroundStyle(.secondary) }
            }
            if let read = evidence.read {
                interpretation(read, label: "Sophia's criterion read · tentative")
                EvidenceLinks(session: session, refs: (read["refs"]?.array ?? []).compactMap(\.string).filter { $0 != ref })
                if evidence.newerEvidence {
                    Text("Newer attempt or correction since this read.").font(.caption).foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
