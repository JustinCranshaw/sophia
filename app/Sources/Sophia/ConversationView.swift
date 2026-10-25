import SwiftUI
import SophiaCore

struct ConversationView: View {
    @ObservedObject var session: NotebookSession
    @Binding private var message: String
    @FocusState private var focused: Bool

    init(session: NotebookSession, draft: Binding<String> = .constant("")) {
        self.session = session
        _message = draft
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Text(session.conversationName).font(.caption).foregroundStyle(.secondary)
                Button("Finish for now") { session.endSession() }
                    .disabled(session.isResponding || !session.hasUncheckpointedMessages)
                    .help("Finish for now")
            }
            .padding(.horizontal, 14).padding(.vertical, 9)
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        let retryQuestion = session.store.unansweredQuestion(in: session.activeThread, pending: session.isPending(session.activeThread))
                        ForEach(items, id: \.id) { item in
                            EntryView(session: session, entry: item.entry, retryQuestion: retryQuestion).id(item.id)
                        }
                        if !session.visibleStreaming.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Who(text: "Sophia", sophia: true)
                                MarkdownView(text: session.visibleStreaming, style: .chat) {
                                    proxy.scrollTo("bottom", anchor: .bottom)
                                }
                            }.id("streaming")
                        }
                        if let a = session.visibleActivity {
                            HStack(spacing: 8) { ProgressView().controlSize(.small); Text(a).font(.caption).foregroundStyle(.secondary) }.id("activity")
                        } else if session.visibleThinking && session.visibleStreaming.isEmpty {
                            HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Sophia is thinking…").font(.caption).foregroundStyle(.secondary) }.id("activity")
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .frame(maxWidth: Self.measure, alignment: .leading)
                    .padding(.horizontal, 24).padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                }
                .onChange(of: items.map(\.id)) { _, _ in withAnimation { proxy.scrollTo("bottom") } }
                .onChange(of: session.visibleStreaming) { _, _ in proxy.scrollTo("bottom") }
                .onAppear { DispatchQueue.main.async { proxy.scrollTo("bottom", anchor: .bottom) } }
                .onReceive(NotificationCenter.default.publisher(for: .scrollConversationToEnd)) { _ in
                    DispatchQueue.main.async { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }
            if let p = session.problem {
                HStack(alignment: .top) {
                    Image(systemName: "exclamationmark.triangle").foregroundStyle(.red)
                    Text(p).font(.caption).textSelection(.enabled)
                    Spacer()
                    Button { session.problem = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain)
                }
                .padding(10).background(Color.red.opacity(0.08))
            }
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .bottom, spacing: 8) {
                    TextField("Ask, answer, or push back…", text: $message, axis: .vertical)
                        .font(.system(size: 14))
                        .lineLimit(1...8)
                        .textFieldStyle(.plain)
                        .focused($focused)
                        .onChange(of: focused) { _, f in session.composerFocused = f }
                        .onSubmit(send)
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.secondary.opacity(0.3)))
                    if session.isReplying {
                        Button { session.stop() } label: { Label("Stop", systemImage: "stop.fill") }
                    } else {
                        Button(action: send) { Image(systemName: "arrow.up").fontWeight(.semibold) }
                            .buttonStyle(.borderedProminent)
                            .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !session.canSend)
                    }
                }
            }
            .frame(maxWidth: Self.measure)
            .padding(.horizontal, 24).padding(.vertical, 14)
            .frame(maxWidth: .infinity)
        }
        .onAppear { focused = Snapshot.outDir == nil }
        .disabled(Snapshot.outDir != nil)
    }

    /// Line length for the conversation: about 75 characters of 14pt SF Pro.
    static let measure: CGFloat = 620

    struct Item { let id: String; let entry: JSONObject }

    var items: [Item] {
        session.store.threadEntries(for: session.activeThread).compactMap { e in
            if e["recovered"] == .bool(true) { return nil }
            guard let id = e.str("id") else { return nil }
            let role = e.str("role") ?? ""
            if role == "client", e["decision"] == nil, !["stopped", "undo_page", "goal_noted", "filed_draft"].contains(e.str("purpose") ?? "") { return nil }
            // A release shows on the card it answers.
            if role == "person", e.str("purpose") == "release_edit" { return nil }
            return Item(id: id, entry: e)
        }
    }

    func send() {
        let t = message
        guard !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, session.canSend else { return }
        message = ""
        session.send(t)
    }
}

struct Who: View {
    let text: String
    var sophia = false
    var body: some View {
        Text(text.uppercased()).font(.caption2.weight(.bold)).tracking(0.6).foregroundStyle(sophia ? Color.accentColor : .secondary)
    }
}

struct EntryView: View {
    @ObservedObject var session: NotebookSession
    let entry: JSONObject
    let retryQuestion: JSONObject?

    var body: some View {
        let role = entry.str("role") ?? ""
        switch role {
        case "person" where entry.str("purpose") == "edit_page":
            EditLine(session: session, entry: entry)
        case "person":
            VStack(alignment: .leading, spacing: 6) {
                Who(text: "You")
                Text(MarkdownView.scripts(AttributedString(entry.str("text") ?? ""), size: 14, design: .default))
                    .font(.system(size: 14)).lineSpacing(5).textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                if let question = retryQuestion,
                   question["id"] == entry["id"], let id = entry.str("id") {
                    HStack(spacing: 10) {
                        Text(session.store.hasPartialReply(to: question) ? "Reply interrupted." : "Not answered yet.")
                            .foregroundStyle(.secondary)
                        Button("Retry") { session.retry(id) }
                        Link("Claude Code setup", destination: NotebookSession.setupURL)
                    }
                    .font(.caption).buttonStyle(.link)
                }
            }
        case "sophia":
            VStack(alignment: .leading, spacing: 6) {
                Who(text: entry.str("purpose") == "briefing" ? "Sophia · welcome back" : "Sophia", sophia: true)
                MarkdownView(text: entry.str("text") ?? "", style: .chat) {
                    NotificationCenter.default.post(name: .scrollConversationToEnd, object: nil)
                }
                if entry.str("purpose") == "briefing" {
                    let refs = (entry["refs"]?.array ?? []).compactMap(\.string)
                    if !refs.isEmpty {
                        Text("Based on " + refs.joined(separator: ", ")).font(.caption2).foregroundStyle(.tertiary)
                    }
                }
            }
        case "tool":
            if entry.str("tool") == "write_page", entry["refused"] == .bool(true) {
                RefusalCard(session: session, entry: entry)
            } else if entry.str("tool") == "write_page" {
                PageWriteCard(session: session, entry: entry)
            } else if let pid = entry.str("proposal") {
                // Notebooks from before pages were saved directly.
                Label("Sophia proposed “\((entry["payload"]?["title"]?.string) ?? pid)”", systemImage: "doc.text")
                    .font(.caption).foregroundStyle(.secondary)
            } else if entry.str("tool") == "memory" {
                MemoryChangedLine(session: session, entry: entry)
            } else if ["about_you", "link"].contains(entry.str("tool") ?? "") {
                LibraryProposalCard(session: session, entry: entry)
            } else if entry.str("tool") == "note", let rid = entry.str("record") {
                NoteLine(session: session, recordID: rid, revised: entry["revised"] == .bool(true))
            } else if entry.str("tool") == "set_chapter" {
                let n = entry["files"]?.array?.count ?? 0
                Label("Put \(n) page\(n == 1 ? "" : "s") in \(entry.str("chapter") ?? "a chapter")", systemImage: "books.vertical")
                    .font(.caption).foregroundStyle(.secondary)
            } else if entry.str("tool") == "WebSearch" {
                Label("Searched: \(entry.str("query") ?? "")", systemImage: "magnifyingglass").font(.caption).foregroundStyle(.secondary)
            }
        case "client":
            clientLine
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    var clientLine: some View {
        if let d = entry.str("decision") {
            let verb = ["accept": "You accepted", "defer": "You set aside", "reject": "You discarded", "undo": "You undid accepting"][d] ?? d
            Text("\(verb) a draft").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .center)
        } else if entry.str("purpose") == "undo_page",
                  let w = session.store.transcript.first(where: { $0.str("id") == entry.str("entry") }), w.str("purpose") == "edit_page" {
            Text("You undid your edit to \(editLabel(w)) of “\(w.str("title") ?? "")”")
                .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .center)
        } else if entry.str("purpose") == "undo_page" {
            let w = session.store.transcript.first { $0.str("id") == entry.str("entry") }
            Text("You undid \(w?["revised"] == .bool(true) ? "the change to" : "adding") “\(w?.str("title") ?? entry.str("file") ?? "")”")
                .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .center)
        } else if entry.str("purpose") == "filed_draft" {
            Text("An earlier draft was saved to the book as a page.").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .center)
        } else if entry.str("purpose") == "goal_noted", let rid = entry.str("record") {
            GoalNotedCard(session: session, recordID: rid)
        } else if entry.str("purpose") == "checkpoint" {
            let kept = (entry["kept"]?.array ?? []).compactMap(\.string)
            let notKept = (entry["not_kept"]?.array ?? []).compactMap(\.string)
            let catchUp = entry["catch_up"] == .bool(true)
            let noted = "Sophia noted \(kept.count) thing\(kept.count == 1 ? "" : "s")"
            if !(catchUp && kept.isEmpty && notKept.isEmpty) {
                VStack(spacing: 6) {
                    if !catchUp { Divider() }
                    HStack(spacing: 4) {
                        Text(catchUp ? "\(noted) from your last session ·" : "Session ended · \(noted) ·").font(.caption).foregroundStyle(.secondary)
                        Button("Review") { session.show(.notes) }.buttonStyle(.link).font(.caption)
                    }
                    if !notKept.isEmpty {
                        DisclosureGroup("\(notKept.count) not kept") {
                            VStack(alignment: .leading, spacing: 4) { ForEach(notKept, id: \.self) { Text($0).font(.caption) } }
                        }.font(.caption).foregroundStyle(.orange).frame(maxWidth: 340)
                    }
                }.frame(maxWidth: .infinity)
            }
        } else if entry.str("purpose") == "briefing_failed" {
            Text("Sophia's briefing couldn't be checked against your notes, so it wasn't shown. " + ((entry["not_kept"]?.array ?? []).compactMap(\.string).joined(separator: " ")))
                .font(.caption).foregroundStyle(.orange)
        } else if entry.str("purpose") == "stopped" {
            Text("You stopped this response.").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

/// A note Sophia wrote during the conversation: one quiet line, so the person can see what she keeps.
struct NoteLine: View {
    @ObservedObject var session: NotebookSession
    let recordID: String
    let revised: Bool
    var body: some View {
        let r = session.store.record(recordID)
        let kind = ["follow_up": "to follow up", "background": "about you and this topic", "attempt": "your attempt", "question": "open question"][r?.str("kind") ?? ""] ?? "note"
        if let r {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "note.text").foregroundStyle(.tertiary)
                (Text(revised ? "Updated a note, \(kind): " : "Noted, \(kind): ").foregroundColor(.secondary) + Text(r.str("text") ?? ""))
                    .lineLimit(2)
                Spacer(minLength: 4)
                Button("Notes") { session.show(.notes) }.buttonStyle(.link)
            }
            .font(.caption)
        }
    }
}

/// A page Sophia saved, with Open and durable latest-action Undo.
struct PageWriteCard: View {
    @ObservedObject var session: NotebookSession
    let entry: JSONObject
    var body: some View {
        let store = session.store
        let id = entry.str("id") ?? ""
        let file = entry.str("file") ?? ""
        let undone = store.isUndone(id)
        let revised = entry["revised"] == .bool(true)
        let exists = store.pageFiles.contains(file)
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: revised ? "doc.text.magnifyingglass" : "doc.text").foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry["unchanged"] == .bool(true) ? "PAGE UNCHANGED" : undone ? (revised ? "CHANGE UNDONE" : "PAGE REMOVED") : (revised ? "REVISED A PAGE" : "ADDED A PAGE"))
                    .font(.system(size: 10, weight: .bold)).tracking(0.6).foregroundStyle(.secondary)
                Text(entry.str("title") ?? file).font(.system(size: 15, design: .serif))
                    .strikethrough(undone && !revised).foregroundStyle(undone ? .secondary : .primary)
            }
            Spacer(minLength: 8)
            if !undone && exists {
                Button("Open") { session.show(.page(file)) }
                if store.isUndoable(entry) { Button("Undo") { session.undoWrite(id) } }
            }
        }
        .controlSize(.small)
        .padding(.horizontal, 12).padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.1)))
    }
}

/// A goal Sophia recorded from the conversation, with Confirm while it is still provisional.
struct GoalNotedCard: View {
    @ObservedObject var session: NotebookSession
    let recordID: String
    var body: some View {
        let store = session.store
        let root = store.rootID(of: recordID)
        let current = store.goals.first { store.rootID(of: $0.str("id") ?? "") == root }
        let noted = store.record(recordID)
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "scope").foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(noted?.str("replaces") == nil ? "NOTED A GOAL" : "REVISED A GOAL")
                    .font(.system(size: 10, weight: .bold)).tracking(0.6).foregroundStyle(.secondary)
                Text(noted?.str("text") ?? "").font(.system(size: 14)).fixedSize(horizontal: false, vertical: true)
                if current == nil {
                    Text("Removed").font(.caption).foregroundStyle(.secondary)
                } else if let c = current, !store.isProvisional(c) {
                    Text("Confirmed").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if let c = current, store.isProvisional(c), c.str("id") == recordID {
                Button("Confirm") { session.confirmGoal(c) }
            }
            Button("Goals") { session.show(.goals) }
        }
        .controlSize(.small)
        .padding(.horizontal, 12).padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.1)))
    }
}

/// "§2", "the opening", or "the page": where an edit was, as the person saw it labelled.
func editLabel(_ edit: JSONObject?) -> String {
    if case .number(let i)? = edit?["index"] { return "§\(Int(i) + 1)" }
    return edit?.str("section") == "(opening)" ? "the opening" : "the page"
}

/// The person's edit to a page, with the same latest-action Undo as a page write.
struct EditLine: View {
    @ObservedObject var session: NotebookSession
    let entry: JSONObject
    var body: some View {
        let id = entry.str("id") ?? ""
        let store = session.store
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "pencil").foregroundStyle(.tertiary)
            (Text("You edited \(editLabel(entry)) of ").foregroundColor(.secondary) + Text(verbatim: entry.str("title") ?? "").italic())
            Spacer(minLength: 4)
            if let file = entry.str("file"), store.pageFiles.contains(file) { Button("Open") { session.show(.page(file)) }.buttonStyle(.link) }
            if store.isUndoable(entry) {
                Button("Undo") { session.undoWrite(id) }.buttonStyle(.link)
            }
        }
        .font(.caption)
    }
}

/// A revision of Sophia's that was refused. When it ran into lines the person wrote, this is the
/// release marker: their text, her reason, and a button that lets her change it (nothing is
/// applied for them; she is told and may try again).
struct RefusalCard: View {
    @ObservedObject var session: NotebookSession
    let entry: JSONObject
    var body: some View {
        let store = session.store
        let place = ["(opening)": "the opening of", "(page)": ""][entry.str("section") ?? ""] ?? "“\(entry.str("section") ?? "")” in"
        let title = entry.str("title") ?? ""
        switch entry.str("reason") {
        case "open":
            Label { Text(verbatim: "Sophia tried to change \(place) “\(title)” while you were editing it. Nothing changed.") } icon: { Image(systemName: "pencil.slash") }
                .font(.caption).foregroundStyle(.secondary)
        case "quote":
            Label { Text(verbatim: "Sophia's change to \(place) “\(title)” would have altered a quotation of your words, so it wasn't saved.") } icon: { Image(systemName: "quote.opening") }
                .font(.caption).foregroundStyle(.secondary)
        default:
            let ids = (entry["edits"]?.array ?? []).compactMap(\.string)
            let edits = ids.compactMap { id in store.transcript.first { $0.str("id") == id } }
            let file = entry.str("file") ?? ""
            let protected = Set(store.protectedLines(of: file).compactMap { $0.edit.str("id") })
            VStack(alignment: .leading, spacing: 6) {
                Text("SOPHIA WANTS TO CHANGE YOUR TEXT").font(.system(size: 10, weight: .bold)).tracking(0.6).foregroundStyle(.secondary)
                ForEach(edits, id: \.self.line) { e in
                    let editID = e.str("id") ?? ""
                    let mine = (e["hunks"]?.array ?? []).compactMap { $0["after"]?.string }.filter { !$0.isEmpty }.joined(separator: " … ")
                    VStack(alignment: .leading, spacing: 6) {
                        (Text("Your edit in \(editLabel(e)): ").foregroundColor(.secondary) + Text(verbatim: "“\(mine.count > 200 ? String(mine.prefix(200)) + "…" : mine)”"))
                            .font(.system(size: 14)).fixedSize(horizontal: false, vertical: true)
                        HStack {
                            if store.isReleased(editID) {
                                Text("Sophia may change this edit on your next message.").font(.caption).foregroundStyle(.secondary)
                                if let release = store.transcript.last(where: { $0.str("entry") == editID && store.isReleaseUndoable($0) }), let id = release.str("id") {
                                    Button("Undo permission to change this edit") { session.undoRelease(id) }
                                }
                            } else if protected.contains(editID) {
                                Button("Let Sophia change this edit") { session.release(editID) }
                            } else {
                                Text("Your text there has changed since.").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                if let why = entry.str("why") {
                    Text(verbatim: "Sophia: \(why)").font(.system(size: 13)).fixedSize(horizontal: false, vertical: true)
                }
            }
            .controlSize(.small)
            .padding(.horizontal, 12).padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.accentColor.opacity(0.35)))
        }
    }
}
