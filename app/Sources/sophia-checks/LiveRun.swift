import Foundation
import SophiaCore

/// End-to-end run against the real Claude Code binary, using the same core code as the app:
/// conversation (Sophia records a goal she hears and writes a page) → closed without End session → on return,
/// catch-up notes and a two-sentence briefing → a page revision.
/// Usage: swift run sophia-checks --live <empty-dir>
/// Uses the person's Claude Code login. Stops if Claude Code reports an API key.
/// Runs scripted turns against the real Claude Code binary for one notebook, the way the app does.
struct LiveRunner {
    let store: NotebookStore
    let claude: String
    let toolServer: String
    let prompt: String

    init(store: NotebookStore) {
        self.store = store
        let bin = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
        toolServer = bin.appendingPathComponent("sophia-mcp").path
        var promptURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        while !FileManager.default.fileExists(atPath: promptURL.appendingPathComponent("SOPHIA.md").path), promptURL.path != "/" {
            promptURL.deleteLastPathComponent()
        }
        guard let prompt = try? String(contentsOf: promptURL.appendingPathComponent("SOPHIA.md"), encoding: .utf8),
              let claude = ClaudeEngine.locateClaude() else { print("Missing SOPHIA.md or Claude Code."); exit(2) }
        self.prompt = prompt
        self.claude = claude
    }

    func run(session: String, resume: String?, messages: [(String, String?)], page: String = "") -> [String: String] {
        let internalRequest = messages.contains { ["checkpoint", "briefing"].contains($0.1 ?? "") }
        let engine = ClaudeEngine(config: .init(claudePath: claude, toolServerPath: toolServer, notebookURL: store.url,
                                                systemPrompt: prompt, context: Prompts.context(store, thread: page), session: session, page: page, readOnly: internalRequest))
        var done = false, reply = "", info: [String: String] = [:]
        var queue = messages
        var currentPurpose: String? = nil
        var turnTexts: [String] = []
        func next() {
            guard !queue.isEmpty else { engine.stop(); done = true; return }
            guard NotebookStore.nextStep(thread: page, pending: false) == .reply else { return }
            let (text, purpose) = queue.removeFirst()
            currentPurpose = purpose
            if let purpose { info[purpose + "_failed"] = "true" }
            reply = ""
            turnTexts = []
            var before: String?
            if purpose == nil { before = try! store.appendTranscript(["role": .string("person"), "page": .string(page), "session": .string(session), "text": .string(text)]).str("id") }
            engine.send((purpose == nil ? Prompts.turnPrefix(store, thread: page, before: before) : "") + text)
        }
        engine.onEvent = { ev in
            switch ev {
            case .started(let sid, let source, let tools, let model):
                info["apiKeySource"] = source; info["tools"] = tools.joined(separator: ","); info["model"] = model
                if source != "none" { print("Claude Code reports an API key source (\(source)); stopping."); engine.stop(); done = true; return }
                _ = sid
            case .assistantText(let t):
                // As the app does: only a verbatim repeat within the turn is dropped.
                if Prompts.isRestatement(t, of: turnTexts) { info["restated"] = (info["restated"] ?? "") + "x"; break }
                turnTexts.append(t)
                reply += t
                if currentPurpose == nil { try! store.appendTranscript(["role": .string("sophia"), "page": .string(page), "session": .string(session), "text": .string(t)]) }
            case .toolUse(_, let name, let input):
                print("  tool used: \(name) \(input["title"]?.string ?? input["text"]?.string ?? input["query"]?.string ?? "")")
            case .toolResult:
                store.reload()
            case .turnDone(let isError, let message, _):
                if isError { print("  turn error: \(message ?? "")") }
                if let p = currentPurpose { info[p] = reply; info[p + "_failed"] = isError ? "true" : "false" }
                else if !isError { try! store.appendTranscript(["role": .string("client"), "purpose": .string("replied"), "page": .string(page), "session": .string(session)]) }
                next()
            case .exited(let code, _, _):
                done = true
                if code != 0 { print("  claude exited \(code)") }
            default: break
            }
        }
        try! engine.start()
        next()
        let deadline = Date().addingTimeInterval(600)
        while !done && Date() < deadline { RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.2)) }
        return info
    }
}

func runLive(dir: URL) {
    let store = try! NotebookStore(url: dir.appendingPathComponent("Graph Clustering"))
    // A second notebook in the same library, for links.
    let other = try! NotebookStore(url: dir.appendingPathComponent("Linear Algebra"))
    let rq = try! other.writePage(title: "The Rayleigh quotient", content: "For symmetric $A$, $R(x) = x^\\top A x / x^\\top x$ is minimized by the eigenvector of the smallest eigenvalue; constrained to vectors orthogonal to it, by the second.", revising: nil, session: "s-1", toolUseID: "seed").str("file")!
    let library = LibraryStore(root: dir)
    let runner = LiveRunner(store: store)
    func run(session: String, resume: String?, messages: [(String, String?)]) -> [String: String] {
        runner.run(session: session, resume: resume, messages: messages)
    }


    print("Session 1: conversation")
    let s1 = run(session: "s-1", resume: nil, messages: [
        ("For context, I have a PhD in computer science but I've been out of research for about ten years. I used spectral clustering years ago and I want to get fluent again with why it works, well enough to predict what it will do before running it. Why does the second eigenvector of the graph Laplacian split a graph? Keep it short. Then ask me to predict something about two triangles joined by one edge.", nil),
        ("I'd guess positive on one triangle, negative on the other, and the same size on all six vertices.", nil),
        ("That's helpful. Let's keep this in the book, including my prediction.", nil),
    ])
    print("  model: \(s1["model"] ?? "?"), auth source: \(s1["apiKeySource"] ?? "?"), tools: \(s1["tools"] ?? "?")")
    store.reload()
    let goals = store.goals
    print(goals.isEmpty ? "FAIL: Sophia recorded no goal." : "  goals: " + goals.map { "\($0.str("id") ?? "") [\(store.isProvisional($0) ? "provisional" : "confirmed")] \($0.str("text") ?? "") (\($0["criteria"]?.array?.count ?? 0) criteria\($0["quote"] == nil ? "" : ", quote verified"))" }.joined(separator: "; "))
    let live = store.shownNotes.filter { $0.str("session") == "s-1" }
    print("  notes during the conversation: \(live.count)" + live.map { "\n    [\($0.str("kind") ?? "")] \($0.str("text") ?? "")\($0["quote"] == nil ? "" : " (quote verified)")" }.joined())
    guard let page = store.pages.first else { print("FAIL: Sophia wrote no page."); exit(1) }
    print("  pages: \(store.pages.map(\.file).joined(separator: ", "))")
    _ = page

    print("Session 2: coming back; notes on the last session, which was closed without ending it")
    let unnoted = store.unnotedMessages
    let s2a = run(session: "s-2", resume: nil, messages: [(Prompts.checkpoint(store, messages: unnoted, catchUp: true), "checkpoint")])
    let (items, memory, _) = RecordChecks.parseCheckpoint(s2a["checkpoint"] ?? "")
    let out = RecordChecks(store: store).check(items, allowedKinds: RecordChecks.checkpointKinds,
                                               quoteEntries: Set(unnoted.compactMap { $0.str("id") }))
    let checkpoint = try! store.finishCheckpoint(s2a["checkpoint"] ?? "", failed: s2a["checkpoint_failed"] != "false",
        through: unnoted.last?.str("id") ?? "", entries: Set(unnoted.compactMap { $0.str("id") }), session: "s-2", catchUp: true)
    if checkpoint == .failed { print("FAIL: checkpoint could not be saved.") }
    _ = memory
    print("  memory after the checkpoint (\(store.memory.count) lines):" + store.memory.map { "\n    \($0.str("id") ?? ""): \($0.str("text") ?? "")" }.joined())
    print("  Sophia wrote \(items.count) records; kept \(out.kept.count); quotes verified: \(out.kept.filter { $0["quote"] != nil }.count); messages still without notes: \(store.unnotedMessages.count)")
    for n in out.notes { print("  not kept / changed: \(n)") }

    print("Session 2: return briefing")
    let s2 = run(session: "s-2", resume: nil, messages: [(Prompts.briefing(store), "briefing")])
    var obj = RecordChecks.extractJSON(s2["briefing"] ?? "")?.object ?? [:]
    obj["kind"] = .string("briefing")
    let b = RecordChecks(store: store).check([.object(obj)], allowedKinds: RecordChecks.briefingKinds, session: "s-2")
    if s2["briefing_failed"] == "false", let rec = b.kept.first {
        try! store.appendLearning(rec, by: "sophia", session: "s-2")
        let words = (rec.str("text") ?? "").split(whereSeparator: { $0.isWhitespace }).count
        print("  briefing kept (\(words) words), citing: \((rec["refs"]?.array ?? []).compactMap(\.string).joined(separator: ", "))")
        print("\n" + (rec.str("text") ?? ""))
    } else {
        print("FAIL: briefing not kept: \(b.notes)")
    }
    print("Session 2: recall, About you, and links")
    library.reload()
    print("  About you: " + (library.aboutLines.isEmpty ? "nothing proposed" : library.aboutLines.map { "\($0.str("id") ?? "") [\(LibraryStore.isProvisional($0) ? "provisional" : "confirmed")] \($0.str("text") ?? "")" }.joined(separator: "; ")))
    _ = run(session: "s-2", resume: nil, messages: [
        ("Remind me, what did I get wrong last time about the two triangles? Short answer.", nil),
        ("Does any of this connect to my other notebooks?", nil)])
    library.reload()
    let links = library.links(touching: store.name)
    print("  links: " + (links.isEmpty ? "none proposed" : links.map { "\($0.str("id") ?? ""): \($0["to"]?["notebook"]?.string ?? "") › \($0["to"]?["page"]?.string ?? ""): \($0.str("reason") ?? "")" }.joined(separator: "; ")))
    if let l = links.first(where: { $0["to"]?["page"]?.string == rq }) {
        try! library.confirmLink(l.str("id")!)
        print("  confirmed the link as the person; asking Sophia to use it")
        let s3 = run(session: "s-2", resume: nil, messages: [("I confirmed that link. What does my Rayleigh quotient page say that bears on the Fiedler vector? One sentence.", "linked")])
        print("  reply: \(String((s3["linked"] ?? "").prefix(300)))")
    }

    print("Session 2: revising a page")
    store.reload()
    let revisionFile = page.file
    let beforeRevisionIDs = Set(store.pageWrites.compactMap { $0.str("id") })
    let beforeRevisionPages = Set(store.pageFiles)
    let beforeRevisionBytes = try! Data(contentsOf: store.pagesURL.appendingPathComponent(revisionFile))
    // Generate the personal question only now: the initial page cannot already contain it.
    let revisionMarker = "S1-NEW-QUESTION-" + UUID().uuidString
    let newQuestion = "Personal question [\(revisionMarker)]: How would increasing the bridge weight change the endpoint magnitudes?"
    guard !String(decoding: beforeRevisionBytes, as: UTF8.self).contains(revisionMarker) else {
        print("FAIL: the new revision marker was already present before the turn."); exit(1)
    }
    _ = run(session: "s-2", resume: nil, messages: [
        ("Please add this new personal question at the end of my existing page \(revisionFile). Keep its title and all existing content exactly, and put the question on its own line:\n\n\(newQuestion)\n\nDo not answer the question yet, create another page, or search the web.", nil)])
    store.reload()
    let newRevisionWrites = store.pageWrites.filter { !beforeRevisionIDs.contains($0.str("id") ?? "") }
    let revision = newRevisionWrites.last { $0["revised"] == .bool(true) && $0.str("file") == revisionFile }
    guard let r = revision, let file = r.str("file"),
          store.hasPreviousVersion(file), Set(store.pageFiles) == beforeRevisionPages,
          newRevisionWrites.allSatisfy({ $0["revised"] == .bool(true) && $0.str("file") == revisionFile }),
          let savedBytes = try? Data(contentsOf: store.pagesURL.appendingPathComponent(file)),
          savedBytes.starts(with: beforeRevisionBytes),
          String(decoding: savedBytes, as: UTF8.self).components(separatedBy: "\n").contains(newQuestion),
          r.str("hash") == store.pageHash(file),
          let previousBytes = try? Data(contentsOf: store.pagesURL.appendingPathComponent(String(file.dropLast(3)) + ".previous.md")),
          previousBytes == beforeRevisionBytes else {
        print("FAIL: Sophia didn't make a new in-place revision of \(revisionFile) preserving its content, requested question, previous bytes and page set (pages: \(store.pages.map(\.file).joined(separator: ", ")))"); exit(1)
    }
    print("  revised \(file); previous version kept: \(store.hasPreviousVersion(file)); pages: \(store.pages.count)")
    print("  new question marker: \(revisionMarker); exact prior bytes retained and only the existing page revised")
    print("Page-origin MCP: revise P and create R from P")
    let p = page.file
    _ = runner.run(session: "s-3", resume: nil, messages: [
        ("Read \(p), then revise that same page with write_page, retaining everything and appending the exact standalone line S1-P-ORIGIN-REVISION. Then use write_page to create a new page titled S1 windowing R, whose body contains the exact line S1-P-ORIGIN-CREATION. Do not search the web.", nil)
    ], page: p)
    store.reload()
    guard let revised = store.pageWrites.last(where: { $0.str("file") == p && $0["revised"] == .bool(true) }),
          revised.str("page") == p, revised.str("hash") == store.pageHash(p),
          store.readPage(p)?.body.contains("S1-P-ORIGIN-REVISION") == true,
          let created = store.pageWrites.last(where: { $0.str("file") != p && $0.str("title") == "S1 windowing R" }),
          let r = created.str("file"), created.str("page") == p, created.str("hash") == store.pageHash(r),
          store.readPage(r)?.body.contains("S1-P-ORIGIN-CREATION") == true else {
        print("FAIL: page-origin MCP revision/creation, ownership, saved bytes or hash."); exit(1)
    }
    print("  observed P-origin revision and R creation, exact marker bytes and full-page hashes verified")
    print("  LiveRunner does not exercise NotebookSession selection, focus, or completion routing. Billing corroboration: inconclusive.")
    print("\nNotebook: \(store.url.path)")
}
