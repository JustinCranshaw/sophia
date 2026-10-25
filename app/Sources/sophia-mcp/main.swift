// Sophia's notebook tools, served to Claude Code over stdio (newline-delimited JSON-RPC).
// read_page reads or lists pages (or a linked page in another notebook). write_page saves a page,
// set_chapter groups pages into a chapter, set_goal records a provisional goal, note writes a note,
// set_memory rewrites Sophia's working memory, recall looks up her notes, about_you proposes a line
// about the person for every notebook, and link proposes a link to another notebook's page. All
// write through NotebookStore or LibraryStore so they follow the same rules and locking as the app.
// Usage: sophia-mcp <notebook-directory> <session>
import Foundation
import SophiaCore

let args = CommandLine.arguments
// Separate approval-only mode never opens a notebook or exposes its tools.
if args.count == 3, args[1] == "--source-permissions" {
    let directory = URL(fileURLWithPath: args[2], isDirectory: true)
    while let line = readLine(), let data = line.data(using: .utf8) {
        guard let message = try? JSONDecoder().decode(JSON.self, from: data), let id = message["id"] else { continue }
        let result: JSON
        switch message["method"]?.string {
        case "initialize": result = .object(["protocolVersion": .string("2024-11-05"), "capabilities": .object(["tools": .object([:])]), "serverInfo": .object(["name": .string("sophia-source-permissions"), "version": .string("1")])])
        case "tools/list": result = .object(["tools": .array([.object(["name": .string("approve"), "description": .string("Host permission callback for opening one web source. Do not invoke directly."), "inputSchema": .object(["type": .string("object"), "properties": .object(["tool_name": .object(["type": .string("string")]), "input": .object(["type": .string("object")]), "tool_use_id": .object(["type": .string("string")])]), "required": .array([.string("tool_name"), .string("input"), .string("tool_use_id")])])])])])
        case "tools/call":
            let params = message["params"]
            if params?["name"]?.string == "approve" {
                let decision = SourcePermissionBridge.awaitDecision(directory: directory, arguments: params?["arguments"] ?? .null, toolUseID: params?["_meta"]?["claudecode/toolUseId"]?.string ?? "")
                result = .object(["content": .array([.object(["type": .string("text"), "text": .string(decision.line)])])])
            } else { result = .object(["content": .array([.object(["type": .string("text"), "text": .string("Unknown permission callback.")])]), "isError": .bool(true)]) }
        default: result = .object([:])
        }
        print(JSON.object(["jsonrpc": .string("2.0"), "id": id, "result": result]).line)
        fflush(stdout)
    }
    exit(0)
}
let notebook = URL(fileURLWithPath: args.count > 1 ? args[1] : ".")
let session = args.count > 2 ? args[2] : "s-0"
let thread = args.count > 3 ? args[3] : ""
var writableStore: NotebookStore?

func send(_ obj: [String: Any]) {
    guard let data = try? JSONSerialization.data(withJSONObject: obj) else { return }
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
}

let tools: [[String: Any]] = [
    [
        "name": "read_page",
        "description": "Read a page from this notebook by its file name (for example \"fiedler-vector.md\"). Without a file name, lists the pages. To read a page in another notebook, pass `notebook`; that works only through a link the person confirmed. Pass `section` (a section title) to read just that section.",
        "inputSchema": ["type": "object", "properties": ["file": ["type": "string"], "notebook": ["type": "string"], "section": ["type": "string"]]]
    ],
    [
        "name": "write_page",
        "description": "Save a page to the notebook's book. It is saved immediately and the person sees it. To revise an existing page, pass its file name as `page`; the previous version is kept and the person can undo. A revision must keep, exactly, the lines the person wrote themselves and quotations of their words; otherwise it is refused and nothing changes.",
        "inputSchema": [
            "type": "object",
            "properties": [
                "title": ["type": "string"],
                "content": ["type": "string", "description": "The page body in Markdown, without the title. Put sources at the end with what you actually read. Link each source you opened or found by search as [title](url), using the URL the tool gave you; never write a URL from memory."],
                "page": ["type": "string", "description": "File name of the page to revise. Omit to add a new page."],
                "chapter": ["type": "string", "description": "Optional chapter to put the page in, such as \"Chapter 0: Foundations\". Created if it doesn't exist."],
                "why": ["type": "string", "description": "One line on why a revision changes text the person wrote. If the revision is refused, it is shown to them beside their text."]
            ],
            "required": ["title", "content"]
        ]
    ],
    [
        "name": "set_chapter",
        "description": "Put existing pages in a chapter of the book, in the order given, after any pages already in it. The chapter is matched by number or title, or created. Pages move from wherever they were; their content doesn't change.",
        "inputSchema": [
            "type": "object",
            "properties": [
                "chapter": ["type": "string", "description": "The chapter, such as \"Chapter 0: Foundations\" or \"Spectral methods\"."],
                "pages": ["type": "array", "items": ["type": "string"], "description": "File names of the pages to put in it."]
            ],
            "required": ["chapter", "pages"]
        ]
    ],
    [
        "name": "note",
        "description": "Write one of your notes on this notebook, which you'll see when the person comes back, or revise one of yours (pass its id as `note`). Kinds: \"follow_up\" (something to check on later, such as whether an idea has landed), \"background\" (something you learned about the person in relation to this topic: what they know, what's rusty, how they like to work on it), \"attempt\" (something they tried: quote their words; text is your tentative read), \"question\" (an open question). Every note needs their exact words as `quote` or ids in `refs`. When a noteworthy actual attempt addresses an existing goal criterion, include the person’s message ref (t-…) alongside its known criterion ref and state which part it supports, what help preceded it, and what remains unshown; do not infer mastery or create goals or notes just to fill criteria. Note only what you'd want to know next time; most turns need no note.",
        "inputSchema": [
            "type": "object",
            "properties": [
                "kind": ["type": "string", "enum": ["follow_up", "background", "attempt", "question"]],
                "text": ["type": "string", "description": "One or two sentences. Tentative where it's your interpretation."],
                "quote": ["type": "string", "description": "The person's exact words from this conversation that the note rests on."],
                "refs": ["type": "array", "items": ["type": "string"], "description": "Message ids (t-…), notes (n-…), goal criteria (g-1#2), or pages (p:file.md) this rests on."],
                "note": ["type": "string", "description": "Id of your note to revise, such as \"n-4\", for example to close a follow-up. Omit for a new note."]
            ],
            "required": ["text"]
        ]
    ],
    [
        "name": "set_memory",
        "description": "Rewrite your working memory for this notebook: at most 10 short lines on where things stand now (what the person knows or finds rusty here, what to check next, what's open). You see it at the start of every conversation. Pass every line you want to keep: unchanged lines with their id, reworded lines with their id and new text, new lines without an id. Lines you leave out are forgotten; the notes behind them stay. Each new line needs refs to what it rests on.",
        "inputSchema": [
            "type": "object",
            "properties": [
                "lines": ["type": "array", "items": [
                    "type": "object",
                    "properties": ["id": ["type": "string"], "text": ["type": "string"], "refs": ["type": "array", "items": ["type": "string"]]],
                    "required": ["text"]
                ]]
            ],
            "required": ["lines"]
        ]
    ],
    [
        "name": "recall",
        "description": "Look up your long-term notes on this notebook (and the person's own messages) by note id, by page, or by words. Use it when a topic comes back and your memory points to notes, or to check what they said or tried before.",
        "inputSchema": [
            "type": "object",
            "properties": [
                "notes": ["type": "array", "items": ["type": "string"], "description": "Note ids, such as \"n-4\"."],
                "page": ["type": "string", "description": "A page file name: notes that refer to it."],
                "words": ["type": "string", "description": "Words that must all appear, such as \"cross entropy\"."]
            ]
        ]
    ],
    [
        "name": "about_you",
        "description": "Propose a line for \"About you\", which every notebook shares: the person's background or a standing preference that carries across topics (for example \"PhD in computer science; away from ML research for 10–15 years\"). Quote their exact words. Nothing about a specific topic, and no judgments of ability. It stays provisional, and visible only in this notebook, until they confirm it.",
        "inputSchema": [
            "type": "object",
            "properties": [
                "text": ["type": "string"],
                "quote": ["type": "string", "description": "The person's exact words it rests on."],
                "line": ["type": "string", "description": "Id of your provisional line to revise, such as \"a-2\"."]
            ],
            "required": ["text", "quote"]
        ]
    ],
    [
        "name": "link",
        "description": "Propose a link from this notebook (or one of its pages) to a page in another notebook, with a one-line reason. The other notebooks' pages are listed in your context. The person confirms links; after that you can read the linked page.",
        "inputSchema": [
            "type": "object",
            "properties": [
                "notebook": ["type": "string", "description": "The other notebook's name."],
                "page": ["type": "string", "description": "The page's file name in that notebook."],
                "section": ["type": "string", "description": "A section title on that page (listed with §), to link into that section."],
                "from_page": ["type": "string", "description": "The page here it connects to. Omit to link the notebook as a whole."],
                "from_section": ["type": "string", "description": "A section title on the page here, if the connection starts there."],
                "reason": ["type": "string", "description": "One line: what connects them."]
            ],
            "required": ["notebook", "page", "reason"]
        ]
    ],
    [
        "name": "set_goal",
        "description": "Record a goal for this notebook, or revise one. It appears in the notebook's Goals as provisional until the person confirms it.",
        "inputSchema": [
            "type": "object",
            "properties": [
                "text": ["type": "string", "description": "The goal, in the person's terms."],
                "criteria": ["type": "array", "items": ["type": "string"], "description": "Concrete signs of what reaching the goal would look like. When revising, existing criteria are kept."],
                "goal": ["type": "string", "description": "Id of the goal to revise, such as \"g-1\". Omit for a new goal."],
                "quote": ["type": "string", "description": "The person's exact words this goal comes from."]
            ],
            "required": ["text"]
        ]
    ]
]

func readPage(_ name: String?, notebook other: String?, section: String?) -> String {
    let root = notebook.deletingLastPathComponent()
    guard let local = ExistingNotebook(root: root, name: notebook.lastPathComponent) else { return "This notebook is unavailable." }
    if let other, !other.isEmpty, other != local.name {
        let file = name ?? ""
        let page: ExistingNotebook.Page
        switch LibraryStore.readExistingLinkedPage(file, in: other, from: local.name, root: root) {
        case .success(let found): page = found
        case .failure(let reason): return reason.message
        }
        if let section, !section.isEmpty {
            guard let text = page.sectionText(named: section) else { return "That linked page has no unique current section “\(section)”." }
            return "# \(page.title)\n(from the notebook \(other); this section only)\n\n\(text)"
        }
        return "# \(page.title)\n(from the notebook \(other))\n\n\(page.body)"
    }
    guard let name, !name.isEmpty else {
        return local.pageFiles.isEmpty ? "The book has no pages yet." : local.pageList()
    }
    let file = name
    guard let page = local.readPage(file) else { return "No page named \(name). Call read_page without a file name to list the pages." }
    if let section, !section.isEmpty, let text = page.sectionText(named: section) {
        return "# \(page.title)\n(this section only)\n\n\(text)"
    }
    return "# \(page.title)\n\n\(page.body)"
}

/// What Sophia is told when a revision is refused. The person's text is returned, never lost.
func refusalText(_ e: JSONObject) -> String {
    let section = e.str("section") ?? ""
    let place = ["(opening)": "the opening of the page", "(page)": "the page"][section] ?? "the section “\(section)”"
    let current = "\n\nTheir text there now:\n\n" + (e.str("current") ?? "")
    switch e.str("reason") {
    case "open":
        return "Not saved: the person is editing \(place) right now. Don't retry this revision. Answer in the conversation instead; if something there should change, say what, and they can make it or ask you after they finish." + current
    case "quote":
        return "Not saved: the revision drops or changes a quotation of the person's words in \(place). Keep quoted blocks exactly as they are, with their quote marker." + current
    default:
        return "Not saved: the revision drops or changes lines the person wrote themselves in \(place). Keep their lines exactly and revise around them. If their text itself should change, say why in the conversation; the person can let you change it, and you'll be told." + current
    }
}

func call(_ name: String?, _ a: [String: Any], toolUse: String) -> String {
    if name == "read_page" {
        return readPage(a["file"] as? String, notebook: a["notebook"] as? String, section: a["section"] as? String)
    }
    do {
        if writableStore == nil { writableStore = try NotebookStore(url: notebook) }
        let store = writableStore!
        let library = LibraryStore(root: notebook.deletingLastPathComponent())
        switch name {
        case "write_page":
            let title = (a["title"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let content = a["content"] as? String ?? ""
            guard !title.isEmpty, !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "Not saved: a page needs a title and content." }
            let page = (a["page"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            if let page, !store.pageFiles.contains(page) { return "Not saved: there is no page named \(page). Omit `page` to add a new page." }
            let e = try store.writePage(title: title, content: content, revising: page, session: session, toolUseID: toolUse,
                                        why: a["why"] as? String, thread: thread)
            if e["refused"] == .bool(true) { return refusalText(e) }
            let file = e.str("file") ?? ""
            var filed = ""
            if let chapter = (a["chapter"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !chapter.isEmpty,
               store.chapter(of: file).map({ NotebookStore.splitNumber(chapter).rest.lowercased() != $0.title.lowercased() }) ?? true {
                filed = " It is in \(try store.fileInChapter([file], chapter: chapter).heading)."
            }
            if e["unchanged"] == .bool(true) { return "Unchanged \(file): the page already matches." + filed }
            return (page == nil ? "Saved as a new page, \(file). The person can see it and undo it." : "Revised \(file). The previous version is kept, and the person can undo it.") + filed
        case "set_chapter":
            let chapter = (a["chapter"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let files = a["pages"] as? [String] ?? []
            guard !chapter.isEmpty, !files.isEmpty else { return "Not changed: name a chapter and at least one page." }
            store.reload()
            if let missing = files.first(where: { !store.pageFiles.contains($0) }) { return "Not changed: there is no page named \(missing). Call read_page without a file name to list the pages." }
            let c = try store.fileInChapter(files, chapter: chapter)
            try store.appendTranscript(["role": .string("tool"), "tool": .string("set_chapter"), "session": .string(session), "page": .string(thread),
                                        "chapter": .string(c.heading), "files": .array(files.map { .string($0) })])
            return "\(c.heading) now has: " + c.pages.map(\.title).joined(separator: "; ") + "."
        case "note":
            var fields: JSONObject = ["text": .string((a["text"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines))]
            if let k = a["kind"] as? String { fields["kind"] = .string(k) }
            let quote = (a["quote"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            fields["refs"] = .array((a["refs"] as? [String] ?? []).map { .string($0) })
            let revising = (a["note"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            if revising == nil && fields["kind"] == nil { return "Not saved: give the note a kind." }
            store.reload()
            let (saved, problems) = try store.writeNote(fields, quote: quote, revising: revising, session: session, thread: thread)
            guard let saved else { return "Not saved. " + problems.joined(separator: " ") }
            return "Noted as \(saved.str("id") ?? ""). The person can see, correct, or delete it." + (problems.isEmpty ? "" : " " + problems.joined(separator: " "))
        case "set_memory":
            let lines = (a["lines"] as? [[String: Any]] ?? []).map {
                NotebookStore.MemoryLine(id: ($0["id"] as? String).flatMap { $0.isEmpty ? nil : $0 }, text: $0["text"] as? String ?? "",
                                         refs: $0["refs"] as? [String] ?? [])
            }
            let (memory, problems) = try store.setMemory(lines, session: session)
            let now = memory.map { "- \($0.str("id") ?? ""): \($0.str("text") ?? "")" }.joined(separator: "\n")
            return "Your memory now:\n" + (now.isEmpty ? "(empty)" : now) + (problems.isEmpty ? "" : "\n\n" + problems.joined(separator: "\n"))
        case "recall":
            store.reload()
            let (notes, messages) = store.recall(ids: a["notes"] as? [String] ?? [], page: a["page"] as? String, words: a["words"] as? String)
            if notes.isEmpty && messages.isEmpty { return "Nothing found." }
            var out = notes.map { n -> String in
                var line = "- \(n.str("id") ?? "") [\(n.str("kind") ?? ""), \(String((n.str("at") ?? "").prefix(10)))]: \(n.str("text") ?? "")"
                if let q = n["quote"]?["text"]?.string { line += " (their words: \"\(q)\")" }
                if let c = store.correction(of: n.str("id") ?? "") { line += " (corrected by the person: \(c.str("text") ?? ""))" }
                return line
            }
            if !messages.isEmpty {
                out.append("Their messages:")
                out += messages.map { "- \($0.str("id") ?? "") [\(String(($0.str("at") ?? "").prefix(10)))]: \(String(($0.str("text") ?? "").prefix(300)))" }
            }
            return out.joined(separator: "\n")
        case "about_you":
            store.reload()
            let (saved, problem) = try library.proposeAbout(text: a["text"] as? String ?? "", quote: a["quote"] as? String ?? "",
                                                           revising: (a["line"] as? String).flatMap { $0.isEmpty ? nil : $0 }, from: store)
            guard let saved else { return problem ?? "Not saved." }
            try store.appendTranscript(["role": .string("tool"), "tool": .string("about_you"), "session": .string(session), "page": .string(thread), "record": saved["id"]!])
            return "Proposed \(saved.str("id") ?? "") for About you. It's provisional until the person confirms it."
        case "link":
            store.reload()
            let (saved, problem) = try library.proposeLink(from: store, page: (a["from_page"] as? String).flatMap { $0.isEmpty ? nil : $0 },
                                                          section: a["from_section"] as? String,
                                                          toNotebook: a["notebook"] as? String ?? "", toPage: a["page"] as? String ?? "",
                                                          toSection: a["section"] as? String, reason: a["reason"] as? String ?? "")
            guard let saved else { return problem ?? "Not saved." }
            try store.appendTranscript(["role": .string("tool"), "tool": .string("link"), "session": .string(session), "page": .string(thread), "record": saved["id"]!])
            return "Proposed link \(saved.str("id") ?? ""). The person can confirm or remove it; once confirmed you can read that page."
        case "set_goal":
            let text = (a["text"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return "Not recorded: the goal needs text." }
            let criteria = (a["criteria"] as? [String] ?? []).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            let goal = (a["goal"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            if let goal, store.record(goal.split(separator: "#").first.map(String.init) ?? goal) == nil {
                return "Not recorded: there is no goal \(goal). Omit `goal` to record a new one."
            }
            let r = try store.writeGoal(text: text, criteria: criteria, revising: goal, quote: a["quote"] as? String, session: session, thread: thread)
            let root = store.rootID(of: r.str("id") ?? "")
            let quoteNote = (a["quote"] as? String).map { q in r["quote"] == nil && !q.isEmpty ? " The quote didn't match the person's words exactly, so it was left out." : "" } ?? ""
            return "Recorded \(goal == nil ? "goal" : "a revision of goal") \(root) as provisional; the person can confirm, change, or remove it.\(quoteNote)"
        default:
            return "Unknown tool."
        }
    } catch {
        return "Not saved: \(error.localizedDescription)"
    }
}

while let line = readLine() {
    guard let data = line.data(using: .utf8),
          let msg = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
    let id = msg["id"]
    switch msg["method"] as? String ?? "" {
    case "initialize":
        let params = msg["params"] as? [String: Any]
        send(["jsonrpc": "2.0", "id": id as Any, "result": [
            "protocolVersion": params?["protocolVersion"] as? String ?? "2025-06-18",
            "capabilities": ["tools": [:]],
            "serverInfo": ["name": "sophia", "version": "0.2.0"]
        ]])
    case "tools/list":
        send(["jsonrpc": "2.0", "id": id as Any, "result": ["tools": tools]])
    case "tools/call":
        let params = msg["params"] as? [String: Any] ?? [:]
        let meta = params["_meta"] as? [String: Any]
        let toolUse = meta?["claudecode/toolUseId"] as? String ?? ""
        let text = call(params["name"] as? String, params["arguments"] as? [String: Any] ?? [:], toolUse: toolUse)
        send(["jsonrpc": "2.0", "id": id as Any, "result": ["content": [["type": "text", "text": text]]]])
    default:
        if id != nil { send(["jsonrpc": "2.0", "id": id as Any, "result": [:]]) }
    }
}
