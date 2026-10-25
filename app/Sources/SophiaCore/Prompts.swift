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
    static func goalsText(_ store: NotebookStore) -> String {
        let goals = store.goals.filter { $0.str("status") != "dropped" }
        guard !goals.isEmpty else { return "No goals recorded yet." }
        return goals.map { g in
            let root = store.rootID(of: g.str("id") ?? "")
            let who = store.isProvisional(g) ? ", provisional: you wrote it and the person hasn't confirmed it" : ""
            var s = "- \(root) [\(g.str("status") ?? "working")\(who)]: \(g.str("text") ?? "")"
            for (i, c) in (g["criteria"]?.array ?? []).enumerated() { s += "\n  - \(root)#\(i + 1): \(c.string ?? "")" }
            return s
        }.joined(separator: "\n")
    }

    /// The book's pages by chapter, with file names, for Sophia. With `sections`, each page's
    /// section titles follow it (used for other notebooks, so Sophia can link into a section).
    public static func pageList(_ store: NotebookStore, sections: Bool = false) -> String {
        var lines: [String] = []
        func page(_ p: NotebookStore.Page, indent: String) -> [String] {
            var out = ["\(indent)- \(p.file) — \(p.title)"]
            if sections { out += store.sections(of: p.file).prefix(15).map { "\(indent)    § \($0.title)" } }
            return out
        }
        for c in store.chapters {
            lines.append("\(c.heading):")
            lines += c.pages.flatMap { page($0, indent: "  ") }
        }
        let loose = store.unfiledPages
        if !loose.isEmpty {
            let indent = lines.isEmpty ? "" : "  "
            if !lines.isEmpty { lines.append("Not in a chapter:") }
            lines += loose.flatMap { page($0, indent: indent) }
        }
        return lines.joined(separator: "\n")
    }

    static func aboutText(_ library: LibraryStore, _ store: NotebookStore) -> String {
        let lines = library.aboutLines(visibleIn: store.name)
        guard !lines.isEmpty else { return "Nothing yet." }
        return lines.map { "- \($0.str("id") ?? "")\(LibraryStore.isProvisional($0) ? " [provisional]" : ""): \($0.str("text") ?? "")" }.joined(separator: "\n")
    }

    static func memoryText(_ store: NotebookStore) -> String {
        let lines = store.memory
        guard !lines.isEmpty else { return "Empty." }
        return lines.map { m in
            var s = "- \(m.str("id") ?? ""): \(m.str("text") ?? "") [\((m["refs"]?.array ?? []).compactMap(\.string).joined(separator: ", "))]"
            if let c = store.correction(of: m.str("id") ?? "") { s += " (corrected by the person: \(c.str("text") ?? ""))" }
            return s
        }.joined(separator: "\n")
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
        let notes = store.shownNotes.suffix(limit)
        guard !notes.isEmpty else { return "None yet." }
        return notes.map { r in
            var s = "- \(r.str("id") ?? "") [\(r.str("kind") ?? "")]: \(r.str("text") ?? "")"
            if let c = store.correction(of: r.str("id") ?? "") { s += " (corrected by the person: \(c.str("text") ?? ""))" }
            return s
        }.joined(separator: "\n")
    }

    /// Keep Sophia's record and the person's authoritative correction distinguishable.
    static func recordWithCorrection(_ record: JSONObject, in store: NotebookStore) -> String {
        guard let correction = store.correction(of: record.str("id") ?? "") else { return record.line }
        return record.line + "\nThe person's correction (use this over Sophia's interpretation): " + correction.line
    }

    /// Added to the system prompt when the conversation process starts.
    public static func context(_ store: NotebookStore, thread: String = "", before: String? = nil) -> String {
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
        - `note` writes one of your notes, which you'll have when the person comes back. Write one when something comes up that you'd want to check on later ("follow_up": whether the cross-entropy idea has landed), or when you learn something about the person in relation to this topic ("background": what they already know, what's rusty, how they like to work on it), or when they make a real attempt or leave a question open. Base it on their exact words (`quote`) or on ids in `refs`. A few notes a session at most: most turns need none, and if a note exists, revise it (pass `note`) rather than adding another, for example to close a follow-up once it's checked. Stay with the topic; no judgments of their ability or character.
        - Your memory: `set_memory` keeps at most 10 short lines on where things stand in this notebook now: what the person knows or finds rusty here, what to check next, what's open. You see it at the start of every conversation; your notes are not shown in full. Rewrite it when something changes what's true now (keep lines by id, reword by id, leave out what no longer matters; the notes behind it stay). Don't repeat what's in About you or the goals; memory is about this topic. Each line cites what it rests on: notes (n-…), their messages (t-…), pages, or goals.
        - `recall` looks up your long-term notes and the person's earlier messages by note id, page, or words. Use it when a topic comes back, before re-teaching something, or when a memory line points to notes you want in full.
        - `about_you` proposes a line for "About you", shared by all the person's notebooks: their background or a standing preference that carries across topics, in their own words. Nothing topic-specific (that belongs in your memory or notes), no judgments of ability. It's provisional until they confirm it.\(linkTool)
        - The person can edit pages themselves, a section at a time. You're told about their edits at your next turn. Lines they wrote, and block quotes of their words, are protected: a `write_page` revision that drops or changes them is refused and nothing is saved. Keep their lines exactly and revise around them; if their text itself should change, say why in the conversation and pass the reason as `why`. They can let you change it, and you'll be told. While they have a section open, revisions that change it are refused; don't retry, answer in the conversation.
        - `read_page` takes a file name from the list below; without one it lists the pages. The list below is from when this conversation started, so call `read_page` for the current list.
        - `set_goal` records a goal for this notebook in the Goals section, or revises one (pass its id as `goal`). Listen throughout the conversation for what the person wants from this notebook, and record it when they state or imply an aim, or when an aim changes or gets sharper. Use their wording where you can and pass the words you drew on as `quote`. Add `criteria`: concrete signs of what reaching the goal would look like. Your goals are provisional until the person confirms them. Don't record a goal on every turn, don't duplicate one that exists (revise it instead), and never mark a goal met or dropped; that is the person's call.
        - Pages and your replies render Markdown with LaTeX math. Use $...$ for inline mathematics and $$ on separate lines for display equations. Use LaTeX for fractions, subscripts, matrices, and aligned derivations; don't put equations in code fences. Escape literal currency dollars as \\$ in Markdown. Music goes in ```abc fences (ABC notation), which the reader typesets as staff notation. Keep page titles, goal titles, and goal criteria in plain text.
        - Messages that begin with "[Sophia app]" come from the app, not the person. Follow their output format exactly.

        Goals:
        \(goalsText(store))

        About you (confirmed by the person unless marked provisional):
        \(aboutText(library, store))

        Your memory for this notebook:
        \(memoryText(store))

        Your long-term notes: \(store.shownNotes.count) (use `recall`).\(thread.isEmpty && store.memory.isEmpty && !store.shownNotes.isEmpty ? " Your memory is empty, so here are the latest:\n" + notesText(store, limit: 10) : "")
        \(elsewhere)

        Pages:
        \(pages.isEmpty ? "None yet." : pages)

        Current conversation: \(thread.isEmpty ? "Contents" : thread).
        \(thread.isEmpty ? "" : "Page in hand:\n" + (store.readPage(thread)?.body ?? "(page unavailable)"))
        Relevant notes:
        \(store.notes(for: thread).map { recordWithCorrection($0, in: store) }.joined(separator: "\n"))
        Creating exchange (from the conversation that made this page):
        \((store.threadEntries(for: thread).contains { $0.str("purpose") == "clear" } ? [] : store.creatingExchange(for: thread)).map { $0.line }.joined(separator: "\n"))
        Conversation in hand:
        \((store.carried(for: thread, before: before) + store.window(for: thread, before: before)).compactMap(contextLine).joined(separator: "\n"))
        Earlier searches and pages read are not still in hand. Look them up again silently when needed. Before continuing a cut-off turn, check what it already saved.
        """
    }

    static func contextLine(_ e: JSONObject) -> String? {
        if NotebookStore.isMessage(e) { return "[\(e.str("id") ?? "")] \(e.str("role") ?? ""): \(e.str("text") ?? "")" }
        if e.str("role") == "sophia", e.str("purpose") == "briefing" {
            return "[\(e.str("id") ?? "")] sophia (welcome back): \(e.str("text") ?? "")"
        }
        if e["recovered"] == .bool(true) { return nil }
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
        let end = before.flatMap { id in store.transcript.firstIndex { $0.str("id") == id } } ?? store.transcript.count
        let priorTurn = store.transcript[..<end].lastIndex { NotebookStore.thread(of: $0) == thread && NotebookStore.isPersonMessage($0) }
        let clear = store.clearPosition(for: thread, before: before)
        let previous = max(clear, priorTurn ?? store.cursor(for: thread, before: before))
        let changes = Array(store.transcript[(previous + 1)...]).filter { $0.str("id") != before }
        var out = bookChanges(store, since: previous + 1)
        // Engines stay open across turns, so a Notes edit must reach the next request too.
        // Notes stay scoped to this conversation; working memory is already notebook-wide.
        let corrected = (store.notes(for: thread) + store.memory).filter { store.correction(of: $0.str("id") ?? "") != nil }
        if !corrected.isEmpty {
            out += "[Sophia app] Current corrections from the person to your relevant records. Use these instead of your earlier interpretation; acknowledge them only when relevant to the question.\n"
                + corrected.map { recordWithCorrection($0, in: store) }.joined(separator: "\n") + "\n"
        }
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
        let checkpointAt = store.transcript.last { $0.str("purpose") == "checkpoint" }?.str("at") ?? ""
        let records = store.learning.filter { ($0.str("at") ?? "") >= checkpointAt }.map { "\($0.str("id") ?? "") [\($0.str("kind") ?? "")]: \($0.str("text") ?? "")" }.joined(separator: "\n")
        return """
        \(opening)

        {"notes": [records…], "memory": [lines…]}
        Each record: {"kind": ..., "text": ..., "quote": {"entry": "t-…", "text": "…"} (optional), "refs": ["…"]}
        Kinds you may write: "attempt" (something the person tried: quote their exact words; text is your tentative read, and says how much help came before it: none, a hint, or a shown step), "read" (your read of their progress on a goal criterion; refs must include the attempt records or their message ids it rests on, and the criterion like "g-1#2"), "question" (an open question that came up), "follow_up" (something to check on later), "background" (something you learned about the person in relation to this topic), "next_step" (one useful next step; at most one).
        Don't repeat notes you already wrote during the conversation (listed under existing records); add only what they missed.
        Rules: quote only words that appear exactly in the person's messages below. Every record needs a quote or refs. Refs may be message ids (t-…), record ids (n-…, g-…), criteria (g-1#2), or pages (p:file.md). Never describe the person's level or ability. If nothing is worth noting, "notes" is [].
        Memory: at most \(NotebookStore.memoryLimit) short lines on where things stand now (what they know or find rusty here, what to check next, what's open). Each line: {"id": "n-…" to keep or reword an existing line, or omit for a new one, "text": …, "refs": [message ids, existing note ids, pages, or criteria it rests on]}. Lines you leave out are forgotten. Don't repeat About you or the goals. Your current memory:
        \(memoryText(store))

        The person's messages:
        \(mine.isEmpty ? "(none)" : mine)

        Existing records:
        \(records.isEmpty ? "(none)" : records)

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
        for e in store.transcript[min(index, store.transcript.count)..<min(before ?? store.transcript.count, store.transcript.count)] where e["recovered"] != .bool(true) {
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
        If nothing is worth picking up, return {"kind": "briefing", "text": ""}.
        refs must list the ids your sentences rest on, using only ids shown here. If a person corrected a record, use their correction.

        Goals:
        \(goalsText(store))

        Your memory for this notebook:
        \(memoryText(store))

        Records:
        \(records.isEmpty ? "(none)" : records)

        Pages:
        \(pages.isEmpty ? "(none)" : pages)

        Most recent messages:
        \(recent.isEmpty ? "(none)" : recent)
        """
    }
}
