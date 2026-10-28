import Foundation

/// Text the app adds to Sophia's instructions. SOPHIA.md is the companion prompt;
/// these supply the current notebook and the record formats the app accepts.
/// The renderer's warnings about one tune on a page (MUSIC.md), as the reader reported them.
public struct MusicWarnings: Hashable {
    public let file: String, page: String, section: String?, tune: String, warnings: [String]
    public init(file: String, page: String, section: String?, tune: String, warnings: [String]) {
        self.file = file; self.page = page; self.section = section; self.tune = tune; self.warnings = warnings
    }
}

public enum Prompts {
    /// Current route: WebSearch is discovery, not a tool for opening external pages.
    static let researchAccess = """
    Research access for this request: WebSearch discovers links and search summaries in ordinary conversation, but this request has no tool for opening external web pages or inspecting their full text. You can read passages the person supplies here and available notebook pages with read_page. Before offering an inspected-passage comparison, state the external-page limit and offer a concrete handoff: find openable links and ask the person to bring back the relevant passages. A search result, summary or remembered quotation is not verified source text. Keep those distinct from the person's supplied passages and your interpretation. Label pasted passages as person-provided, not independently checked against their source URL. Search links are unverified candidates: do not call a document or chapter readable, complete or suitable for a particular passage based only on its search snippet. Repeated searches cannot provide the missing page-reading capability. If the person asks for no page changes, continue in conversation without offering a page write.
    """

    static let approvedResearchAccess = """
    Research access in this conversation: WebSearch discovers candidate links. WebFetch can request opening one HTTP(S) source through the person's native Allow once / Don't open decision. Never invoke the permission callback yourself or retry a denied source without their request. WebFetch returns provider-extracted content, which may be lossy; it is not raw full text or an independently verified verbatim quotation. Cite the requested URL and only a returned URL or location actually supplied by the tool. Distinguish the extracted passage from search summaries, recollection, person-provided text and your interpretation. Do not claim you inspected a source before its actual tool result. If access fails or is declined, explain the limit and offer links or a pasted-passage continuation. Respect requests for no page changes, including no page-writing offer.
    """

    static func goalsText(_ store: NotebookStore) -> String {
        do {
            try store.ensureNotebookPages(session: "context")
            let page = store.notebookPage(role: .goals)!
            let body = store.readPage(page.file)?.body ?? ""
            let pending = store.pendingPageProposals(originNotebook: store.name).filter { $0.str("file") == page.file }
            return body + (pending.isEmpty ? "" : "\nPending whole-page changes (not accepted):\n" + pending.map { $0.line }.joined(separator: "\n"))
        } catch { return "Goals page unavailable; do not infer its content." }
    }

    /// The book's pages by chapter, with file names, for Sophia. With `sections`, each page's
    /// section titles follow it (used for other notebooks, so Sophia can link into a section).
    public static func pageList(_ store: NotebookStore, sections: Bool = false) -> String {
        let overview = store.overviewPage.map { "Notebook introduction: \($0.file) — \($0.title)\n" } ?? ""
        return overview + pageList(chapters: store.chapters, loose: store.unfiledPages) { file in
            sections ? store.sections(of: file).map(\.title) : []
        }
    }

    static func pageList(chapters: [NotebookStore.Chapter], loose: [NotebookStore.Page], sectionTitles: (String) -> [String]) -> String {
        var lines: [String] = []
        func page(_ p: NotebookStore.Page, indent: String) -> [String] {
            ["\(indent)- \(p.file) — \(p.title)"] + sectionTitles(p.file).prefix(15).map { "\(indent)    § \($0)" }
        }
        for c in chapters {
            lines.append("\(c.heading):")
            if let intro = c.intro { lines += page(intro, indent: "  Introduction: ") }
            lines += c.pages.flatMap { page($0, indent: "  ") }
        }
        if !loose.isEmpty {
            let indent = lines.isEmpty ? "" : "  "
            if !lines.isEmpty { lines.append("Not in a chapter:") }
            lines += loose.flatMap { page($0, indent: indent) }
        }
        return lines.joined(separator: "\n")
    }

    static func aboutText(_ library: LibraryStore, _ store: NotebookStore) -> String {
        do {
            let shared = try library.ensureSharedAboutPage(session: "context")
            let body = shared.store.readPage(shared.page.file)?.body ?? ""
            let proposals = shared.store.pendingPageProposals(originNotebook: store.name)
            return (body.isEmpty ? "Nothing yet." : body) + (proposals.isEmpty ? "" : "\nPending proposals from this notebook (not accepted):\n" + proposals.map { $0.line }.joined(separator: "\n"))
        } catch { return "About you unavailable; do not infer its content." }
    }

    static func memoryText(_ store: NotebookStore) -> String {
        do {
            try store.ensureNotebookPages(session: "context")
            return store.notebookPage(role: .memory).flatMap { store.readPage($0.file)?.body } ?? ""
        } catch { return "Working memory unavailable; do not infer its content." }
    }

    /// Other notebooks' titles and the links that touch this one.
    static func linksText(_ library: LibraryStore, _ store: NotebookStore) -> String {
        let others = library.otherNotebooks(than: store.name)
        let links = library.links(touching: store.name)
        var out = "\nOther notebooks:\n"
        out += others.isEmpty ? "None.\n" : others.map { "\"\($0.name)\"\n" + ($0.pages.isEmpty ? "  (no pages)" : $0.pages.split(separator: "\n").prefix(80).map { "  " + $0 }.joined(separator: "\n")) }.joined(separator: "\n") + "\n"
        if !links.isEmpty {
            out += "\nLinks:\n" + links.map { l in
                let from = [l["from"]?["notebook"]?.string, l["from"]?["page"]?.string, l["from"]?["section"]?.string.map { "§ " + $0 }].compactMap { $0 }.joined(separator: " › ")
                let to = [l["to"]?["notebook"]?.string, l["to"]?["page"]?.string, l["to"]?["section"]?.string.map { "§ " + $0 }].compactMap { $0 }.joined(separator: " › ")
                return "- \(l.str("id") ?? "")\(LibraryStore.isProvisional(l) ? " [provisional]" : " [confirmed]"): \(from) ↔ \(to): \(l.str("reason") ?? "")"
            }.joined(separator: "\n") + "\n"
        }
        return out
    }

    static func notesText(_ store: NotebookStore, limit: Int = 20) -> String {
        do {
            try store.ensureNotebookPages(session: "context")
            return store.notebookPage(role: .notes).flatMap { store.readPage($0.file)?.body } ?? ""
        } catch { return "Notes page unavailable; do not infer its content." }
    }

    /// Keep Sophia's record and the person's authoritative correction distinguishable.
    static func recordWithCorrection(_ record: JSONObject, in store: NotebookStore) -> String {
        guard let correction = store.correction(of: record.str("id") ?? "") else { return record.line }
        return record.line + "\nThe person's correction (use this over Sophia's interpretation): " + correction.line
    }

    /// Added to the system prompt when the conversation process starts.
    public static func context(_ store: NotebookStore, thread: String = "", before: String? = nil, canOpenSources: Bool = false) -> String {
        _ = try? store.ensureNotebookPages(session: "context")
        let pages = pageList(store)
        let library = LibraryStore(root: store.url.deletingLastPathComponent())
        let separate = store.isSeparate
        let linkTool = separate ? "" : "\n- Other notebooks are listed below by chapter and page title; that's all you see of them. Sections (§) are listed under each page. When a page or section here genuinely connects to one there, `link` proposes the link with a one-line reason; link to a section when the connection is that specific. Once the person confirms a link you can read that page, or just the section, with `read_page` (pass `notebook`, and `section`). Propose a link only when the connection would help, not for every shared word."
        let elsewhere = separate ? "\nThis notebook is kept separate from the person's other notebooks.\n" : linksText(library, store)
        return """
        # This app

        You are running inside Sophia, a Mac app. The notebook is "\(store.name)".
        - Answer every part of the person's question in this conversation, including when the same turn writes or revises a page. Give the requested explanation before optional notes or memory updates; a saved page or note is not a conversational answer. If a tool is needed first, return to the unanswered question after it.
        - The person sees your text as it arrives. Keep the conversation concise and useful, with the requested explanation and any important tool outcome.
        - `write_page` saves a page to the book right away; the person can open it from its conversation card; their selection and conversation stay where they are. To change an existing page, pass its file name as `page`: the new text replaces it, and the previous version is kept. Read the page first and keep what the person still wants. The person can undo any page you write.
        - Pages can be grouped into chapters. `set_chapter` puts existing pages in a chapter (created if needed) without changing them, and `write_page` takes an optional `chapter` for a new page. Number pages within a numbered chapter in their titles ("0.1 Entropy" in "Chapter 0: Foundations"); the app styles the numbers. Don't repeat the title or chapter at the top of the page body. Group pages when the person asks or when the book's structure has become clear, not on every page.
        - `note` revises the ordinary Markdown Sophia’s notes page. Read it first; supply its complete body with exact words as `quote` or existing evidence `refs` supporting the change. Keep the person’s actual words distinct from your interpretation. Preserve useful existing content and all protected personal lines. Most turns need no note update.
        - `set_memory` revises the ordinary Markdown Working memory page. Supply its complete body and evidence refs. Keep it concise about where this inquiry stands, rather than repeating About you or Goals. Preserve protected personal contributions. The person can read, edit and undo it like any page.
        - `recall` looks up your long-term notes and the person's earlier messages by note id, page, or words. Use it when a topic comes back, before re-teaching something, or when a memory line points to notes you want in full.
        - `about_you` proposes a whole Markdown replacement for "About you", shared by all the person's notebooks: their background or a standing preference that carries across topics, in their own words. Nothing topic-specific (that belongs in your memory or notes), no judgments of ability. It stays pending until they accept it.\(linkTool)
        - The person can edit pages themselves, a section at a time. You're told about their edits at your next turn. Lines they wrote, and block quotes of their words, are protected: a `write_page` revision that drops or changes them is refused and nothing is saved. Keep their lines exactly and revise around them; if their text itself should change, say why in the conversation and pass the reason as `why`. They can let you change it, and you'll be told. While they have a section open, revisions that change it are refused; don't retry, answer in the conversation.
        - `read_page` takes a file name from the list below; without one it lists the pages. The list below is from when this conversation started, so call `read_page` for the current list.
        - `set_goal` proposes a complete Markdown Goals page body, based on the person’s exact words as `quote`. Preserve accepted goals they still want. A proposal does not change the saved page: the person reviews and accepts it. Goals are ordinary prose; formatting does not create formal status or evidence of understanding. Do not infer confirmation, met or dropped status from a Markdown edit.
        - Pages and your replies render Markdown with LaTeX math. Use $...$ for inline mathematics and $$ on separate lines for display equations. Use LaTeX for fractions, subscripts, matrices, and aligned derivations; don't put equations in code fences. Escape literal currency dollars as \\$ in Markdown. Music goes in ```abc fences (ABC notation), which the reader typesets as staff notation. Keep page titles, goal titles, and goal criteria in plain text.
        - Current Markdown pages take precedence over historical note, goal and memory records. Historical source records preserve provenance and evidence; do not treat those records as a second current version of edited pages.
        - Messages that begin with "[Sophia app]" come from the app, not the person. Follow their output format exactly.

        \(canOpenSources ? approvedResearchAccess : researchAccess)

        Goals:
        \(goalsText(store))

        About you (accepted Markdown; pending changes labelled separately):
        \(aboutText(library, store))

        Your memory for this notebook:
        \(memoryText(store))

        Sophia’s notes (current Markdown):
        \(notesText(store))
        \(elsewhere)

        Pages:
        \(pages.isEmpty ? "None yet." : pages)

        Current conversation: \(thread.isEmpty ? "Contents" : thread).
        \(thread.isEmpty ? "" : "Page in hand:\n" + (store.readPage(thread)?.body ?? "(page unavailable)"))
        Historical source notes relevant to this thread (not current page content):
        \(store.notes(for: thread).map { recordWithCorrection($0, in: store) }.joined(separator: "\n"))
        Creating exchange (from the conversation that made this page):
        \((store.threadEntries(for: thread).contains { $0.str("purpose") == "clear" } ? [] : store.creatingExchange(for: thread)).map { $0.line }.joined(separator: "\n"))
        Conversation in hand:
        \((store.carried(for: thread, before: before) + store.window(for: thread, before: before)).compactMap(contextLine).joined(separator: "\n"))
        Earlier searches and pages read are not still in hand. Look them up again silently when needed. Before continuing a cut-off turn, check Sophia’s saved changes.
        """
    }

    /// Shared About has its own stable conversation, without another notebook's context.
    public static func sharedAboutContext(_ store: NotebookStore, libraryRoot: URL,
                                          thread: String = ClaudeEngine.sharedAboutFile, before: String? = nil,
                                          canOpenSources: Bool = false) -> String {
        guard ClaudeEngine.isSharedAboutLocation(store.url, libraryRoot: libraryRoot, page: thread),
              let page = store.page(thread), page.role == .about, page.scope == .library,
              let body = store.readPage(thread)?.body else { return "About conversation unavailable. Do not infer or retrieve another notebook's content." }
        let pending = store.pendingPageProposals(originNotebook: ClaudeEngine.sharedAboutOrigin).filter { $0.str("file") == thread }
        return """
        # About you conversation
        This is the one conversation beside the Library’s shared About you page. The page and this conversation have their own durable store; this is not an ordinary topic notebook.
        Accepted Markdown below is shared with notebooks. A pending change is private to its originating conversation until the person accepts it. You see only proposals originating here, never proposals or source conversations from other notebooks.
        `read_page` reads only about-you.md here. `about_you` proposes a complete Markdown replacement, supported by exact words from this conversation. It does not save the shared body: the person reviews the full change and accepts or rejects it. Preserve accepted content the person still wants. Do not invent background, preferences or judgments of ability.
        No tools for other notebook reads, links, ordinary page writes, goals, notes or working memory are available here. Answer the person's actual question in the conversation; do not force a profile-writing task.
        \(canOpenSources ? approvedResearchAccess : researchAccess)

        Accepted About you Markdown:
        \(body)

        Pending proposals from this conversation (not accepted):
        \(pending.isEmpty ? "None." : pending.map { $0.line }.joined(separator: "\n"))

        Conversation in hand:
        \((store.carried(for: thread, before: before) + store.window(for: thread, before: before)).compactMap(contextLine).joined(separator: "\n"))
        """
    }

    /// Refresh a warm About engine without replaying history or notebook-only context.
    public static func sharedAboutTurnPrefix(_ store: NotebookStore, libraryRoot: URL) -> String {
        let file = ClaudeEngine.sharedAboutFile
        guard ClaudeEngine.isSharedAboutLocation(store.url, libraryRoot: libraryRoot, page: file),
              let page = store.page(file), page.role == .about, page.scope == .library,
              let body = store.readPage(file)?.body else { return "[Sophia app] About context is unavailable. Do not infer or retrieve another notebook’s content.\n\n" }
        let pending = store.pendingPageProposals(originNotebook: ClaudeEngine.sharedAboutOrigin).filter { $0.str("file") == file }
        return "[Sophia app] Current accepted About you Markdown (use this over earlier versions):\n" + body
            + "\nPending proposals originating in this About conversation (not accepted):\n"
            + (pending.isEmpty ? "None." : pending.map { $0.line }.joined(separator: "\n"))
            + "\nThe person’s message follows.\n\n"
    }

    static func contextLine(_ e: JSONObject) -> String? {
        if NotebookStore.isMessage(e) { return "[\(e.str("id") ?? "")] \(e.str("role") ?? ""): \(e.str("text") ?? "")" }
        if e.str("role") == "sophia", e.str("purpose") == "briefing" {
            return "[\(e.str("id") ?? "")] sophia (welcome back): \(e.str("text") ?? "")"
        }
        if e["recovered"] == .bool(true) { return nil }
        if e.str("tool") == "WebFetch" {
            let label = e["is_error"] == .bool(true) ? "Source request did not complete (not a source passage): " : "Provider-extracted source response (not raw full text or independently verified quotation): "
            return label + e.line
        }
        if e.str("tool") == "write_page" {
            if e["unchanged"] == .bool(true) { return "Unchanged \(e.str("file") ?? "")." }
            return e["refused"] == .bool(true) ? "Write refused on \(e.str("file") ?? ""): \(e.str("reason") ?? ""). \(e.str("current") ?? "")"
                : "Saved \(e.str("file") ?? "") (\(e["revised"] == .bool(true) ? "revision" : "new page"))."
        }
        if ["release_edit", "undo_release", "undo_page", "edit_page"].contains(e.str("purpose") ?? "") { return e.line }
        return nil
    }

    /// Derived from the origin thread's previous turn, with no foreign conversation words.
    public static func turnPrefix(_ store: NotebookStore, thread: String, before: String? = nil) -> String {
        _ = try? store.ensureNotebookPages(session: "context")
        let end = before.flatMap { id in store.transcript.firstIndex { $0.str("id") == id } } ?? store.transcript.count
        let priorTurn = store.transcript[..<end].lastIndex { NotebookStore.thread(of: $0) == thread && NotebookStore.isPersonMessage($0) }
        let clear = store.clearPosition(for: thread, before: before)
        let previous = max(clear, priorTurn ?? store.cursor(for: thread, before: before))
        let changes = Array(store.transcript[(previous + 1)...]).filter { $0.str("id") != before }
        var out = bookChanges(store, since: previous + 1)
        // A reused engine must receive the actual editable pages, including personal corrections.
        out += "[Sophia app] Current notebook Markdown (authoritative over historical note/memory records):\nSophia’s notes:\n"
            + notesText(store) + "\nWorking memory:\n" + memoryText(store) + "\nGoals:\n" + goalsText(store) + "\n"
        for e in changes where e["recovered"] != .bool(true) && e["unchanged"] != .bool(true) {
            if e.str("file") == thread && ((e.str("tool") == "write_page" && NotebookStore.thread(of: e) != thread) || e.str("purpose") == "undo_page") {
                out += "[Sophia app] This page changed: \(contextLine(e) ?? e.line)\n"
            }
        }
        let others = Set(changes.filter { $0["recovered"] != .bool(true) && NotebookStore.isMessage($0) && NotebookStore.thread(of: $0) != thread }.map { NotebookStore.thread(of: $0) })
        for page in others.sorted() { out += "[Sophia app] Another conversation was active: \(page.isEmpty ? "Contents" : page).\n" }
        return out
    }

    /// The session-end request for one session's messages.
    public static func checkpoint(_ store: NotebookStore, session: String) -> String {
        checkpoint(store, messages: store.transcript.filter { $0.str("session") == session && NotebookStore.isPersonMessage($0) }, catchUp: false)
    }

    /// The notes request. The person's messages are listed with ids so Sophia can quote and cite them.
    /// A catch-up covers messages from earlier sittings that were closed without ending the session.
    public static func checkpoint(_ store: NotebookStore, messages: [JSONObject], catchUp: Bool) -> String {
        let day = DateFormatter()
        day.dateFormat = "MMM d, HH:mm"
        let iso = ISO8601DateFormatter()
        let mine = messages.map { m -> String in
            let when = m.str("at").flatMap { iso.date(from: $0) }.map { " (\(day.string(from: $0)))" } ?? ""
            return "\(m.str("id") ?? "") [page: \(NotebookStore.thread(of: m))]\(when): \(m.str("text") ?? "")"
        }.joined(separator: "\n")
        let opening = catchUp
            ? "[Sophia app] The person has come back. Their messages below, from when they were last here, have no notes yet. Write your notes on them, and your memory as it should now stand, as one JSON object and nothing else."
            : "[Sophia app] The person ended the session. Write your notes on this session, and your memory as it should now stand, as one JSON object and nothing else."
        return """
        \(opening)

        Return {"notes": "complete Markdown body" or null, "memory": "complete Markdown body" or null, "refs": [existing source ids], "quote": "optional exact person words"}.
        null leaves that page alone; use it when nothing useful changed. These are ordinary Markdown pages, not arrays of records or memory lines. Read the existing bodies below and preserve what remains useful, every personal contribution, and quotes of their words. No curriculum, mastery claim or judgment of ability. Notes distinguish the person’s actual attempt from your tentative interpretation and what remains unshown. Working memory stays concise about where the inquiry stands. Every changed body needs supporting refs or an exact quote from the messages below. Existing n-/g-/criterion refs name historical evidence, not current authoritative page content. Do not invent identities or overwrite a person’s correction.

        Historical source records (not current page content; replacement chains remain evidence):
        \(store.learning.suffix(40).map { $0.line }.joined(separator: "\n"))

        Current notes:
        \(notesText(store))

        Current working memory:
        \(memoryText(store))

        The person’s messages:
        \(mine.isEmpty ? "(none)" : mine)

        Goals:
        \(goalsText(store))
        """
    }

    /// Drop only a verbatim repeat within the current turn, allowing outer whitespace.
    /// Shared vocabulary, reordered words, or an added sentence can carry new reasoning.
    public static func isRestatement(_ text: String, of earlier: [String]) -> Bool {
        let candidate = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty else { return false }
        return earlier.contains { $0.trimmingCharacters(in: .whitespacesAndNewlines) == candidate }
    }

    /// Put before the person's message when they changed the book since their previous message:
    /// their edits as changed lines, and edits they let Sophia change or took back. Empty if nothing changed.
    public static func bookChanges(_ store: NotebookStore, since index: Int, before: Int? = nil) -> String {
        func clip(_ s: String) -> String { s.count > 1500 ? String(s.prefix(1500)) + " …" : s }
        func place(_ e: JSONObject?) -> String {
            let section = e?.str("section") ?? ""
            let within = ["(opening)": ", the opening", "(page)": ""][section] ?? ", section “\(section)”"
            return "“\(e?.str("title") ?? "")” (\(e?.str("file") ?? ""))\(within)"
        }
        func entry(_ id: String?) -> JSONObject? { store.transcript.first { $0.str("id") == id } }
        var lines: [String] = []
        for e in store.transcript[min(index, store.transcript.count)..<min(before ?? store.transcript.count, store.transcript.count)] where e["recovered"] != .bool(true) && e["migrationSource"] == nil {
            switch e.str("purpose") {
            case "edit_page":
                lines.append("- Edited \(place(e)):")
                for h in e["hunks"]?.array ?? [] {
                    let before = h["before"]?.string ?? "", after = h["after"]?.string ?? ""
                    lines.append("  was: " + (before.isEmpty ? "(nothing)" : clip(before)))
                    lines.append("  now: " + (after.isEmpty ? "(removed)" : clip(after)))
                }
            case "release_edit":
                lines.append("- Let you change their edit in \(place(entry(e.str("entry")))). You may now revise those lines.")
            case "undo_release":
                lines.append("- Took back letting you change their edit in \(place(entry(entry(e.str("entry"))?.str("entry")))). Those lines are protected again.")
            case "undo_page":
                let action = entry(e.str("entry"))
                lines.append("- Undid \(action?.str("purpose") == "edit_page" ? "their edit to" : "a page write on") \(place(action)).")
            default: break
            }
        }
        guard !lines.isEmpty else { return "" }
        return "[Sophia app] Since your last reply, the person changed the book themselves:\n" + lines.joined(separator: "\n")
            + "\nMention an edit only if it matters, for example a corrected step that later steps depend on. The person's message follows.\n\n"
    }

    /// Put before the person's message when pages show notation warnings Sophia hasn't been told
    /// about: one line per tune, naming the page, section, and abcjs's warnings. Empty if none.
    public static func musicWarnings(_ tunes: [MusicWarnings]) -> String {
        guard !tunes.isEmpty else { return "" }
        let lines = tunes.prefix(10).map { t in
            let section = t.section.map { ", section “\($0)”" } ?? ""
            let tune = t.tune.isEmpty ? "" : ", tune “\(t.tune)”"
            let shown = t.warnings.prefix(5).joined(separator: "; ")
            let more = t.warnings.count > 5 ? " (and \(t.warnings.count - 5) more)" : ""
            return "- “\(t.page)” (\(t.file))\(section)\(tune): \(shown)\(more)"
        }
        return "[Sophia app] The music notation on these pages shows warnings when typeset:\n" + lines.joined(separator: "\n")
            + "\nFix what these warnings name with `write_page`, changing nothing else in the tune; mention it only if the person would notice, and then say what the warning was. The person's message follows.\n\n"
    }

    /// Put before the person's message when the conversation was quiet for a long time but the
    /// window stayed open, so there was no briefing.
    public static func afterQuiet(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds / 3600)
        let span = hours >= 48 ? "\(hours / 24) days" : "\(hours) hours"
        return "[Sophia app] The conversation has been quiet for about \(span). If it helps, re-anchor in a line within your reply. The person's message follows.\n\n"
    }

    /// The return briefing. It must link every claim to records, messages, or pages.
    public static func briefing(_ store: NotebookStore) -> String {
        let records = store.currentLearning.filter { $0.str("kind") != "memory" }.suffix(40).map { r -> String in
            var s = "\(r.str("id") ?? "") [\(r.str("kind") ?? ""), by \(r.str("by") ?? "")]: \(r.str("text") ?? "")"
            if let q = r["quote"]?.object { s += " (their words: \"\(q.str("text") ?? "")\")" }
            if let c = store.correction(of: r.str("id") ?? "") { s += " (corrected by the person: \(c.str("text") ?? ""))" }
            return s
        }.joined(separator: "\n")
        let pages = store.pages.map { "p:\($0.file) — \($0.title)" }.joined(separator: "\n")
        let recent = store.transcript.filter { ["person", "sophia"].contains($0.str("role") ?? "") && $0.str("purpose") == nil }.suffix(12)
            .map { "\($0.str("id") ?? "") \($0.str("role") ?? ""): \(String(($0.str("text") ?? "").prefix(400)))" }.joined(separator: "\n")
        return """
        [Sophia app] The person has come back to this notebook after a while. Write at most two short sentences to help them pick up, as a single JSON object and nothing else:
        {"kind": "briefing", "text": "…", "refs": ["…"]}

        Sentence one: the single thread most worth picking up, usually an open question or something that didn't click. Sentence two: one offer they can ignore by just carrying on, such as a short recall question before you restate anything, or the next step. At most 50 words. No greeting. Don't list pages or goals, mention goals to confirm, or recount the history: the person can see the book and their goals.
        Example: "Still open from last time: the cross-entropy step that didn't click. Want to try saying what −log p measures, or go straight on to maximum likelihood?"
        A source-comparison offer must fit the research access below: do not imply external passages are already inspected or ready. Offer links/pasted text when the passages are not in hand.
        \(researchAccess)
        If nothing is worth picking up, return {"kind": "briefing", "text": ""}.
        refs must list the ids your sentences rest on, using only ids shown here. If a person corrected a record, use their correction.

        Goals:
        \(goalsText(store))

        Your memory for this notebook:
        \(memoryText(store))

        Current notes:
        \(notesText(store))

        Historical source records (use as evidence, not current facts):
        \(records.isEmpty ? "(none)" : records)

        Pages:
        \(pages.isEmpty ? "(none)" : pages)

        Most recent messages:
        \(recent.isEmpty ? "(none)" : recent)
        """
    }
}
