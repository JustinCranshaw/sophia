import SwiftUI
import AppKit
import SophiaCore

struct ConversationView: View {
    @ObservedObject var session: NotebookSession
    @Binding private var message: String
    @FocusState private var focused: Bool
    @EnvironmentObject private var model: AppModel
    private var expanded: Bool { !model.conversationCollapsed }
    @State private var seenSophiaID: String?
    @State private var followsLatest = true
    @State private var hasNewActivity = false
    @State private var scrollPosition: ConversationScrollPosition?
    @State private var settlingViewport = false

    init(session: NotebookSession, draft: Binding<String> = .constant("")) {
        self.session = session
        _message = draft
    }

    var body: some View {
        Group {
            if expanded { expandedConversation }
            else { collapsedRail }
        }
        .onAppear { seenSophiaID = latestSophiaMessage?.str("id") }
        .onChange(of: conversationKey) { _, _ in seenSophiaID = latestSophiaMessage?.str("id") }
        .onChange(of: expanded) { _, value in
            if value { seenSophiaID = latestSophiaMessage?.str("id") }
            else { focused = false; session.composerFocused = false }
        }
        .onChange(of: latestSophiaMessage?.str("id")) { _, id in if expanded { seenSophiaID = id } }
    }

    private var collapsedRail: some View {
        VStack(spacing: 16) {
            Button { model.conversationCollapsed = false } label: {
                Label("Show conversation", systemImage: "sidebar.left").labelStyle(.iconOnly).frame(width: 28, height: 28)
            }
            .accessibilityLabel(conversationToggleTitle)
            .help(conversationToggleTitle + " · " + session.conversationName)
            if session.pendingSource != nil {
                Button { model.conversationCollapsed = false } label: { Label("Source approval pending", systemImage: "hand.raised").labelStyle(.iconOnly) }
                    .accessibilityLabel("Source approval pending · Show conversation")
                    .help("A source needs your decision")
            }
            if session.problem != nil || !session.editRecovery.edits.isEmpty
                || session.store.unansweredQuestion(in: session.activeThread, pending: session.isPending(session.activeThread)) != nil {
                Button { model.conversationCollapsed = false } label: { Label("Conversation needs attention", systemImage: "exclamationmark.triangle").labelStyle(.iconOnly).foregroundStyle(.orange) }
                    .accessibilityLabel("Conversation needs attention · Show conversation")
                    .help("Open the conversation to review the error or kept edit")
            }
            if session.isReplying {
                ProgressView().controlSize(.small).help("Sophia is replying")
            } else if latestSophiaMessage?.str("id") != seenSophiaID, latestSophiaMessage != nil {
                Image(systemName: "circle.fill").font(.system(size: 7)).foregroundStyle(Brand.plum)
                    .accessibilityLabel("New reply").help("New reply · Show conversation")
            }
            if !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button { model.conversationCollapsed = false } label: { Label("Draft ready", systemImage: "square.and.pencil").labelStyle(.iconOnly) }
                    .accessibilityLabel("Draft ready · Show conversation")
                    .help("Your unsent draft is ready in this conversation")
            }
            Spacer(minLength: 0)
        }
        .buttonStyle(.borderless).padding(.top, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var expandedConversation: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(session.activeThread.isEmpty ? "Notebook conversation" : "Conversation · " + session.conversationName)
                    .font(.subheadline.weight(.semibold)).lineLimit(2).help(session.conversationName)
                Spacer(minLength: 8)
                Button { model.conversationCollapsed.toggle() } label: {
                    if expanded { Image(systemName: "sidebar.left") }
                    else { Text(conversationToggleTitle) }
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(conversationToggleTitle)
                .help(expanded ? "Collapse the conversation" : "Show the conversation")
                if expanded && !session.isSharedAbout {
                    Button("Finish for now") { session.endSession() }
                        .disabled(session.isResponding || !session.hasUncheckpointedMessages)
                        .help("Finish for now")
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 9)
            Divider()
            if expanded {
            ScrollViewReader { proxy in
                GeometryReader { viewport in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            if items.isEmpty && !session.isReplying {
                                Text(session.activeThread.isEmpty ? "Ask about this notebook." : "Ask about this page.")
                                    .font(.callout).foregroundStyle(.secondary)
                            }
                            let retryQuestion = session.store.unansweredQuestion(in: session.activeThread, pending: session.isPending(session.activeThread))
                            ForEach(items, id: \.id) { item in
                                Group {
                                    if item.entries.count > 1 {
                                        NotebookUpdatesView(session: session, entries: item.entries)
                                    } else {
                                        EntryView(session: session, entry: item.entry, retryQuestion: retryQuestion)
                                    }
                                }
                                .background(alignment: .top) {
                                    // Every original anchor remains at the group, including while collapsed.
                                    VStack(spacing: 0) {
                                        ForEach(item.anchors, id: \.self) { anchor in
                                            Color.clear.frame(height: 1).id(anchor)
                                        }
                                    }
                                }
                            }
                            if let a = session.visibleActivity {
                                HStack(spacing: 8) { ProgressView().controlSize(.small); Text(a).font(.caption).foregroundStyle(.secondary) }.id("activity")
                            } else if session.visibleThinking && session.visibleStreaming.isEmpty {
                                HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Sophia is thinking…").font(.caption).foregroundStyle(.secondary) }.id("activity")
                            }
                        }
                        .frame(maxWidth: Self.measure, alignment: .leading)
                        .padding(.horizontal, 24).padding(.vertical, 20)
                        .frame(maxWidth: .infinity)
                        .id("bottom")
                        .background {
                            GeometryReader { content in
                                Color.clear.preference(key: ConversationScrollPositionKey.self,
                                    value: ConversationScrollPosition(frame: content.frame(in: .named("conversationViewport")), viewport: viewport.size.height))
                            }
                        }
                    }
                    .coordinateSpace(name: "conversationViewport")
                    .onPreferenceChange(ConversationScrollPositionKey.self) { position in
                        guard let position else { return }
                        let previous = scrollPosition
                        scrollPosition = position
                        if let previous, followsLatest,
                           abs(position.frame.width - previous.frame.width) > 0.5 || abs(position.viewport - previous.viewport) > 0.5 {
                            settlingViewport = true
                        }
                        // The native clip view can adjust a frame after SwiftUI reports the
                        // new viewport. Keep the existing follow choice through that reflow.
                        if settlingViewport {
                            let shortContent = position.frame.height <= position.viewport + 1 && abs(position.frame.minY) <= 1
                            if shortContent || abs(position.frame.maxY - position.viewport) <= 1 { settlingViewport = false }
                            followIfNeeded(proxy)
                            return
                        }
                        // Appended content changes the bottom, not the origin. A resize alone
                        // also must not turn following off or manufacture unread activity.
                        if let previous, abs(position.frame.minY - previous.frame.minY) > 0.5,
                           abs(position.viewport - previous.viewport) < 0.5,
                           abs(position.frame.width - previous.frame.width) < 0.5 {
                            let upward = position.frame.minY - previous.frame.minY
                            let shrink = max(0, previous.frame.height - position.frame.height)
                            // Even a small deliberate upward move stops following. A shorter
                            // document can also clamp the origin upward without a scroll.
                            if upward > shrink + 0.5, position.frame.maxY > position.viewport + 0.5 {
                                followsLatest = false
                            } else if upward < -0.5 {
                                followsLatest = position.frame.maxY <= position.viewport + 32
                                if followsLatest { hasNewActivity = false }
                            } else {
                                // An automatic clamp keeps the person's existing follow choice.
                                followIfNeeded(proxy)
                            }
                        } else {
                            followIfNeeded(proxy)
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if hasNewActivity && !followsLatest {
                            Button { jumpToLatest(proxy) } label: { Label("New activity", systemImage: "arrow.down") }
                                .buttonStyle(.borderedProminent).controlSize(.small)
                                .help("Jump to the latest conversation activity")
                                .padding(12)
                        }
                    }
                }
                .onChange(of: items.flatMap(\.anchors)) { _, _ in receivedActivity(proxy) }
                .onChange(of: session.visibleStreaming) { _, _ in receivedActivity(proxy) }
                .onChange(of: conversationKey) { _, _ in
                    scrollPosition = nil
                    jumpToLatest(proxy)
                }
                .onAppear { jumpToLatest(proxy) }
                .onReceive(NotificationCenter.default.publisher(for: .scrollConversationToEnd)) { _ in
                    // Existing Markdown height notifications are automatic reflow, not intent.
                    followIfNeeded(proxy)
                }
            }

            }
            if let request = session.pendingSource {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Open this source?").font(.callout.weight(.semibold))
                    HStack(alignment: .top, spacing: 8) {
                        Text(request.url).font(.caption).textSelection(.enabled).lineLimit(2).truncationMode(.middle).help(request.url)
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(request.url, forType: .string)
                        } label: { Image(systemName: "doc.on.doc") }
                        .buttonStyle(.plain).help("Copy full source URL").accessibilityLabel("Copy full source URL")
                    }
                    Text("Claude will read it and return an extracted passage, which may omit details.").font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button("Allow once") { session.decideSource(request, allow: true) }.buttonStyle(.borderedProminent)
                        Button("Don't open") { session.decideSource(request, allow: false) }
                    }
                }
                .padding(12).frame(maxWidth: .infinity, alignment: .leading).background(Color.accentColor.opacity(0.08))
            }
            if !session.editRecovery.edits.isEmpty { PageRecoveryView(session: session) }
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
                    TextField(session.activeThread.isEmpty ? "Ask about this notebook…" : "Ask about this page…", text: $message, axis: .vertical)
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

    var items: [ConversationRow] {
        conversationRows(session.store.transcript, streaming: session.visibleStreaming, scope: conversationKey, thread: session.activeThread)
    }

    private var conversationKey: String { session.store.url.path + "/" + session.activeThread }
    private var latestSophiaMessage: JSONObject? {
        session.store.transcript.last {
            $0.str("role") == "sophia" && NotebookStore.thread(of: $0) == session.activeThread && $0["recovered"] != .bool(true)
                && ($0.str("purpose") == nil || $0.str("purpose") == "briefing")
        }
    }
    private var conversationToggleTitle: String {
        if !expanded && session.isReplying { return "Sophia is replying… · Show conversation" }
        if expanded { return "Hide conversation" }
        guard let entry = latestSophiaMessage, let id = entry.str("id"), id != seenSophiaID else { return "Show conversation" }
        return entry.str("purpose") == "briefing" ? "Welcome back · Show conversation" : "New reply · Show conversation"
    }


    private func followIfNeeded(_ proxy: ScrollViewProxy) {
        // Never animate automatic following: intermediate offsets can look like scrolling away.
        guard followsLatest else { return }
        DispatchQueue.main.async {
            if followsLatest { proxy.scrollTo("bottom", anchor: .bottom) }
        }
    }

    private func receivedActivity(_ proxy: ScrollViewProxy) {
        if followsLatest { followIfNeeded(proxy) } else { hasNewActivity = true }
    }

    private func jumpToLatest(_ proxy: ScrollViewProxy) {
        followsLatest = true
        hasNewActivity = false
        settlingViewport = false
        followIfNeeded(proxy)
    }

    func send() {
        let t = message
        guard !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, session.canSend else { return }
        followsLatest = true
        hasNewActivity = false
        settlingViewport = false
        message = ""
        session.send(t)
    }
}

private struct ConversationScrollPosition: Equatable {
    let frame: CGRect
    let viewport: CGFloat
}

private struct ConversationScrollPositionKey: PreferenceKey {
    static var defaultValue: ConversationScrollPosition? = nil
    static func reduce(value: inout ConversationScrollPosition?, nextValue: () -> ConversationScrollPosition?) {
        value = nextValue() ?? value
    }
}

struct Who: View {
    let text: String
    var sophia = false
    var body: some View {
        Text(text.uppercased()).font(.caption2.weight(.bold)).tracking(0.6).foregroundStyle(sophia ? Brand.plum : .secondary)
    }
}

struct EntryView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var session: NotebookSession
    let entry: JSONObject
    let retryQuestion: JSONObject?

    var body: some View {
        let role = entry.str("role") ?? ""
        switch role {
        case "person" where ["delete_page", "restore_page"].contains(entry.str("purpose") ?? ""):
            HStack {
                Label(entry.str("purpose") == "delete_page" ? "You deleted this page." : "You restored this page.", systemImage: entry.str("purpose") == "delete_page" ? "trash" : "arrow.uturn.backward")

            }.font(.caption).foregroundStyle(.secondary)
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
                        ConnectionDetailsButton()
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
                        EvidenceLinks(session: session, refs: refs)
                    }
                }
            }
        case "tool":
            if entry.str("tool") == "write_page", entry["refused"] == .bool(true) {
                RefusalCard(session: session, entry: entry)
            } else if entry.str("tool") == "write_page" {
                PageWriteCard(session: session, entry: entry)
            } else if ["note", "memory"].contains(entry.str("tool") ?? ""), failedNotebookUpdate(entry) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("\(entry.str("tool") == "note" ? "Note" : "Memory") update reported an error.", systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(.orange)
                    if let reason = entry.str("error") ?? entry.str("reason"), !reason.isEmpty {
                        Text(reason).font(.caption).textSelection(.enabled)
                    }
                    if entry.str("tool") == "note", let record = entry.str("record") {
                        NoteLine(session: session, recordID: record, revised: entry["revised"] == .bool(true))
                    } else {
                        Button(entry.str("tool") == "memory" ? "Working memory" : "Notes") { model.showNotebookSettings(session.store.url, section: entry.str("tool") == "memory" ? .memory : .notes) }.buttonStyle(.link).font(.caption)
                    }
                }
            } else if let pid = entry.str("proposal") {
                // Notebooks from before pages were saved directly.
                Label("Sophia proposed “\((entry["payload"]?["title"]?.string) ?? pid)”", systemImage: "doc.text")
                    .font(.caption).foregroundStyle(.secondary)
            } else if entry.str("tool") == "memory" {
                MemoryChangedLine(session: session, entry: entry)
            } else if ["about_you", "link"].contains(entry.str("tool") ?? "") {
                LibraryProposalCard(session: session, entry: entry)
            } else if entry.str("tool") == "note" {
                if let rid = entry.str("record") {
                    NoteLine(session: session, recordID: rid, revised: entry["revised"] == .bool(true))
                } else {
                    Label("Note update record unavailable.", systemImage: "note.text").font(.caption).foregroundStyle(.secondary)
                }
            } else if entry.str("tool") == "set_goal", let record = entry.str("record") {
                GoalNotedCard(session: session, recordID: record)
            } else if entry.str("tool") == "set_chapter" {
                let n = entry["files"]?.array?.count ?? 0
                Label("Put \(n) page\(n == 1 ? "" : "s") in \(entry.str("chapter") ?? "a chapter")", systemImage: "books.vertical")
                    .font(.caption).foregroundStyle(.secondary)
            } else if entry.str("tool") == "WebFetch" {
                SourceEvidence(entry: entry)
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
            let noted = entry.str("page_format") == "markdown" ? "Notebook pages reviewed" : "Sophia noted \(kept.count) thing\(kept.count == 1 ? "" : "s")"
            if entry.str("page_format") == "markdown" || !(catchUp && kept.isEmpty && notKept.isEmpty) {
                VStack(spacing: 6) {
                    if !catchUp { Divider() }
                    HStack(spacing: 4) {
                        Text(catchUp ? "\(noted) from your last session ·" : "Session ended · \(noted) ·").font(.caption).foregroundStyle(.secondary)
                        Button("Review") { model.showNotebookSettings(session.store.url, section: .notes) }.buttonStyle(.link).font(.caption)
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

/// Adjacent successful bookkeeping stays quiet; every original detail/action remains available.
private struct NotebookUpdatesView: View {
    @ObservedObject var session: NotebookSession
    let entries: [JSONObject]
    @State private var expanded = false

    private var title: String {
        let notes = entries.filter { $0.str("tool") == "note" }.count
        let kind = notes == entries.count ? "note" : notes == 0 ? "memory" : "note and memory"
        return "\(entries.count) \(kind) updates"
    }

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(entries, id: \.self.line) { entry in
                    EntryView(session: session, entry: entry, retryQuestion: nil)
                }
            }.padding(.top, 6)
        } label: {
            Label(title, systemImage: "note.text").font(.caption).foregroundStyle(.secondary)
        }
        .help("Show each note or memory update and its actions")
    }
}

/// A note Sophia wrote during the conversation: one quiet line, so the person can see what Sophia keeps.
struct NoteLine: View {
    @EnvironmentObject private var model: AppModel
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
                Button("Notes") { model.showNotebookSettings(session.store.url, section: .notes) }.buttonStyle(.link)
            }
            .font(.caption)
        } else {
            HStack {
                Label("Note no longer available.", systemImage: "note.text").foregroundStyle(.secondary)
                Spacer(minLength: 4)
                Button("Notes") { model.showNotebookSettings(session.store.url, section: .notes) }.buttonStyle(.link)
            }.font(.caption).help(recordID)
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

/// A proposal points to the canonical Goals page; old goal IDs remain audit evidence.
struct GoalNotedCard: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var session: NotebookSession
    let recordID: String
    var body: some View {
        let history = session.store.pageProposalHistory
        let proposal = history.first { $0.str("id") == recordID || $0.str("legacyID") == recordID }
        let pending = session.store.pendingPageProposals().first { $0.str("id") == proposal?.str("id") }
        let decision = history.last { $0.str("proposal") == proposal?.str("id") }?.str("decision")
        HStack {
            Label(pending != nil ? "Goals change proposed" : decision == "accepted" ? "You accepted this Goals proposal" : decision == "rejected" ? "You rejected this Goals proposal" : "Earlier Goals record", systemImage: "scope").font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Button(pending == nil ? "Goals" : "Review") {
                model.showNotebookSettings(session.store.url, section: .goals)
                session.reviewProposalID = pending?.str("id")
            }.buttonStyle(.link)
        }
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
/// release marker: their text, Sophia's reason, and a button that lets Sophia change it (nothing is
/// applied for them; Sophia is told and may try again).
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


/// Provider output is evidence, displayed as selectable text rather than rendered HTML.
struct SourceEvidence: View {
    let entry: JSONObject
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry["is_error"] == .bool(true) ? "Source request did not complete" : "Source response received").font(.caption.weight(.semibold))
            Text(entry["is_error"] == .bool(true) ? "Source access outcome" : "Provider extraction response").font(.caption2).foregroundStyle(.secondary)
            Text(entry.str("url") ?? "").font(.caption).textSelection(.enabled)
            if let returned = entry.str("returned_url"), returned != entry.str("url") {
                Text("Returned URL: " + returned).font(.caption).textSelection(.enabled)
            }
            if let location = entry.str("location") { Text("Reported location: " + location).font(.caption).textSelection(.enabled) }
            DisclosureGroup("Extracted content and outcome") {
                if let status = entry["http_status"] { Text("HTTP status: " + status.line).font(.caption2).foregroundStyle(.secondary) }
                Text(SourceEvidenceText.plain(entry["content"] ?? .null)).font(.callout).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                Text("Provider extraction may omit details. It is not raw full text or an independently verified quotation.").font(.caption).foregroundStyle(.secondary)
            }.font(.caption)
        }
        .padding(10).background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }
}

/// Contextual access remains available beside a failed request after setup is dismissed.
private struct ConnectionDetailsButton: View {
    @EnvironmentObject private var connection: ConnectionState
    var body: some View {
        Button("Connection & data…") { connection.detailsShown = true }
    }
}
