// Sophia's notebook tools, served to Claude Code over stdio (newline-delimited JSON-RPC).
// read_page reads or lists pages (or a linked page in another notebook). write_page saves a page,
// set_chapter groups pages into a chapter, set_goal records a provisional goal, note writes a note,
// set_memory rewrites Sophia's working memory, recall looks up Sophia's notes, about_you proposes a page change
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
let requestedSharedAbout = args.count > 4
let sharedLibraryRoot: URL? = args.count == 8 && args[4] == "--scope" && args[5] == "shared-about" && args[6] == "--library-root" && !args[7].isEmpty
    ? URL(fileURLWithPath: args[7]) : nil
let validScope = !requestedSharedAbout || sharedLibraryRoot.map { ClaudeEngine.isSharedAboutLocation(notebook, libraryRoot: $0, page: thread) } == true
var writableStore: NotebookStore?

func send(_ obj: [String: Any]) {
    guard let data = try? JSONSerialization.data(withJSONObject: obj) else { return }
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
}

let notebookTools: [[String: Any]] = [
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
                "title": ["type": "string", "description": "A short, specific plain-text title, usually two to six words. Put explanatory detail in the opening paragraph."],
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
        "description": "Revise the ordinary Markdown page Sophia’s notes. Read its current body first and supply the complete proposed body, with evidence for the change. Keep interpretation distinct from the person’s words, and preserve protected personal contributions. Most turns need no update.",
        "inputSchema": ["type": "object", "properties": ["content": ["type": "string", "description": "Complete Markdown body; preserve existing content the person still wants and every protected personal line."],"refs": ["type": "array", "items": ["type": "string"], "description": "Existing message, historical record, criterion or page references supporting this change."],"quote": ["type": "string", "description": "The person’s exact words supporting this change."]], "required": ["content"]]

    ],
    [
        "name": "set_memory",
        "description": "Revise the ordinary Markdown Working memory page. Supply its complete body with supporting references; keep it concise and preserve protected personal contributions. An empty body explicitly clears only unprotected content.",
        "inputSchema": ["type": "object", "properties": ["content": ["type": "string", "description": "Complete Markdown body; preserve existing content the person still wants and every protected personal line."],"refs": ["type": "array", "items": ["type": "string"], "description": "Existing message, historical record, criterion or page references supporting this change."]], "required": ["content","refs"]]

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
        "description": "Propose a complete Markdown replacement for the shared About you page. Keep accepted content the person still wants. Quote their exact words supporting the change. Nothing topic-specific or judgments of ability. Only this notebook sees the pending proposal; the person reviews and accepts before it becomes shared.",
        "inputSchema": ["type": "object", "properties": [
            "content": ["type": "string", "description": "The complete proposed Markdown body."],
            "quote": ["type": "string", "description": "The person's exact words supporting the change."]
        ], "required": ["content", "quote"]]

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
        "description": "Propose a complete Markdown replacement for the notebook Goals page. Quote the person’s actual words supporting the change. Only the person accepts or rejects it; prose does not automatically mark a goal confirmed, met or dropped.",
        "inputSchema": ["type": "object", "properties": ["content": ["type": "string", "description": "Complete Markdown body; preserve existing content the person still wants and every protected personal line."],"quote": ["type": "string", "description": "The person’s exact words supporting this change."]], "required": ["content","quote"]]

    ]
]

let tools: [[String: Any]] = !validScope ? [] : requestedSharedAbout ? notebookTools.filter { ["read_page", "about_you"].contains($0["name"] as? String ?? "") }.map { tool in
    var scoped = tool
    if tool["name"] as? String == "read_page" {
        scoped["description"] = "Read the shared About you page only. No other notebook or page is available in this conversation."
        scoped["inputSchema"] = ["type": "object", "properties": ["file": ["type": "string", "enum": [ClaudeEngine.sharedAboutFile]]]]
    }
    return scoped
} : notebookTools

func callSharedAbout(_ name: String?, _ a: [String: Any]) -> String {
    guard let root = sharedLibraryRoot else { return "Unavailable: invalid About conversation scope." }
    // Reject every foreign-notebook argument, even a name that happens to match this folder.
    guard a["notebook"] == nil else { return "Not allowed: this conversation cannot read another notebook." }
    if name == "read_page" {
        guard a["section"] == nil, a["file"] == nil || a["file"] as? String == ClaudeEngine.sharedAboutFile,
              let existing = ExistingNotebook(root: notebook.deletingLastPathComponent(), name: notebook.lastPathComponent),
              let page = existing.readPage(ClaudeEngine.sharedAboutFile) else { return "Unavailable: only the canonical About you page can be read here." }
        return "# " + page.title + "\n\n" + page.body
    }
    guard name == "about_you" else { return "Not allowed: this conversation only reads About you or proposes a reviewed change." }
    do {
        if writableStore == nil { writableStore = try NotebookStore(url: notebook) }
        let store = writableStore!
        store.reload()
        let content = a["content"] as? String ?? "", quote = (a["quote"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        func normalize(_ text: String) -> String { text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ") }
        guard !quote.isEmpty, !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let message = store.threadEntries(for: thread).last(where: { NotebookStore.isPersonMessage($0) && normalize($0.str("text") ?? "").contains(normalize(quote)) }),
              let entry = message.str("id") else { return "Not proposed: quote exact words from this About conversation." }
        let shared = try LibraryStore(root: root).ensureSharedAboutPage(session: session)
        let proposal = try shared.store.proposePageChange(file: shared.page.file, content: content,
            originNotebook: ClaudeEngine.sharedAboutOrigin,
            evidence: ["entry": .string(entry), "quote": .string(quote), "notebook": .string(ClaudeEngine.sharedAboutOrigin)], session: session)
        try store.appendTranscript(["role": .string("tool"), "tool": .string("about_you"), "page": .string(thread), "session": .string(session), "record": proposal["id"]!])
        return "Proposed \(proposal.str("id") ?? "") for About you. The person must review and accept it; accepted Markdown is unchanged."
    } catch { return "Not proposed: \(error.localizedDescription)" }
}

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
    guard validScope else { return "Unavailable: invalid About conversation scope; no notebook tools were opened." }
    if requestedSharedAbout { return callSharedAbout(name, a) }
    if name == "read_page" {
        return readPage(a["file"] as? String, notebook: a["notebook"] as? String, section: a["section"] as? String)
    }
    do {
        if writableStore == nil { writableStore = try NotebookStore(url: notebook) }
        let store = writableStore!
        let library = LibraryStore(root: notebook.deletingLastPathComponent())
        switch name {
        case "write_page":
            store.reload()
            let title = (a["title"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let content = a["content"] as? String ?? ""
            guard !title.isEmpty, !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "Not saved: a page needs a title and content." }
            let page = (a["page"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            store.reload()
            if let page, !store.pageFiles.contains(page) { return "Not saved: there is no page named \(page). Omit `page` to add a new page." }
            let e = try store.writeConversationPage(title: title, content: content, revising: page, session: session, toolUseID: toolUse,
                                        why: a["why"] as? String, thread: thread)
            if e["refused"] == .bool(true) { return refusalText(e) }
            let file = e.str("file") ?? ""
            var filed = ""
            if store.page(file)?.role == .content,
               let chapter = (a["chapter"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !chapter.isEmpty,
               store.chapter(of: file).map({ NotebookStore.splitNumber(chapter).rest.lowercased() != $0.title.lowercased() }) ?? true {
                filed = " It is in \(try store.fileInChapter([file], chapter: chapter, session: session, thread: thread).heading)."
            }
            if e["unchanged"] == .bool(true) { return "Unchanged \(file): the page already matches." + filed }
            return (page == nil ? "Saved as a new page, \(file). The person can see it and undo it." : "Revised \(file). The previous version is kept, and the person can undo it.") + filed
        case "set_chapter":
            let chapter = (a["chapter"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let files = a["pages"] as? [String] ?? []
            guard !chapter.isEmpty, !files.isEmpty else { return "Not changed: name a chapter and at least one page." }
            store.reload()
            if let missing = files.first(where: { !store.pageFiles.contains($0) }) { return "Not changed: there is no page named \(missing). Call read_page without a file name to list the pages." }
            if files.contains(where: { store.page($0)?.role != .content }) {
                return "Not changed: introductions keep their existing attachment. Use write_page to revise the introduction itself."
            }
            let c = try store.fileInChapter(files, chapter: chapter, session: session, thread: thread)
            try store.appendTranscript(["role": .string("tool"), "tool": .string("set_chapter"), "session": .string(session), "page": .string(thread),
                                        "chapter": .string(c.heading), "files": .array(files.map { .string($0) })])
            return "\(c.heading) now has: " + c.pages.map(\.title).joined(separator: "; ") + "."
        case "note":
            guard let content = a["content"] as? String else { return "Not saved: supply the complete Markdown content." }
            let result = try store.writeNotebookNotes(content: content, quote: a["quote"] as? String,
                refs: a["refs"] as? [String] ?? [], session: session, thread: thread)
            if result["refused"] == .bool(true) { return refusalText(result) }
            return result["unchanged"] == .bool(true) ? "Notes unchanged." : "Saved Sophia’s notes as Markdown; the person can edit or undo the change."
        case "set_memory":
            guard let content = a["content"] as? String else { return "Not saved: supply the complete Markdown content." }
            let result = try store.writeNotebookMemory(content: content, refs: a["refs"] as? [String] ?? [], session: session, thread: thread)
            if result["refused"] == .bool(true) { return refusalText(result) }
            return result["unchanged"] == .bool(true) ? "Working memory unchanged." : "Saved Working memory as Markdown; the person can edit or undo the change."
        case "recall":
            store.reload()
            let (notes, messages) = store.recall(ids: a["notes"] as? [String] ?? [], page: a["page"] as? String, words: a["words"] as? String)
            try store.ensureNotebookPages(session: session)
            var current: [String] = []
            for role in [NotebookStore.PageRole.notes, .memory] {
                if let page = store.notebookPage(role: role), let body = store.readPage(page.file)?.body { current.append("Current " + page.title + ":\n" + body) }
            }
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
            return current.joined(separator: "\n\n") + "\n\nHistorical source records (not current facts):\n" + (out.isEmpty ? "None matching." : out.joined(separator: "\n"))
        case "about_you":
            store.reload()
            let saved = try library.proposeAboutPage(content: a["content"] as? String ?? "", quote: a["quote"] as? String ?? "", from: store, session: session)
            try store.appendTranscript(["role": .string("tool"), "tool": .string("about_you"), "session": .string(session), "page": .string(thread), "record": saved["id"]!])
            return "Proposed \(saved.str("id") ?? "") for About you. The person must review and accept the whole page; it is not saved to the shared page yet."
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
            guard let content = a["content"] as? String else { return "Not proposed: supply the complete Markdown content." }
            let proposal = try store.proposeGoalsPage(content: content, quote: a["quote"] as? String ?? "", session: session, thread: thread)
            return "Proposed Goals page change \(proposal.str("id") ?? ""). The person must review and accept it; the saved page is unchanged."
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
