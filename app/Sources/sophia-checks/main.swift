// Checks for SophiaCore. Run with: swift run sophia-checks
// (Swift's test frameworks ship with Xcode; this runs with the Command Line Tools alone.)
import Foundation

if let i = CommandLine.arguments.firstIndex(of: "--attribution"), i + 1 < CommandLine.arguments.count {
    runAttributionProbe(dir: URL(fileURLWithPath: CommandLine.arguments[i + 1]))
    exit(0)
}
if let i = CommandLine.arguments.firstIndex(of: "--probes"), i + 1 < CommandLine.arguments.count {
    runProbes(dir: URL(fileURLWithPath: CommandLine.arguments[i + 1]))
    exit(0)
}
if let i = CommandLine.arguments.firstIndex(of: "--music"), i + 1 < CommandLine.arguments.count {
    runMusic(dir: URL(fileURLWithPath: CommandLine.arguments[i + 1]))
    exit(0)
}
if let i = CommandLine.arguments.firstIndex(of: "--live"), i + 1 < CommandLine.arguments.count {
    runLive(dir: URL(fileURLWithPath: CommandLine.arguments[i + 1]))
    exit(0)
}

var failures = 0
var current = ""

func expect(_ ok: @autoclosure () throws -> Bool, line: Int = #line) {
    let passed = (try? ok()) ?? false
    if !passed { failures += 1; print("  FAILED in \(current), main.swift:\(line)") }
}

func expectThrows(_ body: () throws -> Any) {
    do { _ = try body(); failures += 1; print("  FAILED in \(current): expected an error") } catch {}
}

import Foundation
@testable import SophiaCore

func tempStore() throws -> NotebookStore {
let url = FileManager.default.temporaryDirectory.appendingPathComponent("sophia-test-\(UUID().uuidString)")
return try NotebookStore(url: url)
}

func j(_ s: String) -> JSON { JSON.parse(s)! }

// MARK: RecordCheckTests
func keepsVerifiedQuoteAndStampsNothingFromSophia() throws {
    let store = try tempStore()
    let msg = try store.appendTranscript(["role": .string("person"), "session": .string("s-1"),
                                          "text": .string("Positive on one triangle,   negative on the other.")])
    let id = msg.str("id")!
    let out = RecordChecks(store: store).check(
        [j(#"{"kind":"attempt","by":"person","status":"met","text":"Signs right.","quote":{"entry":"\#(id)","text":"Positive on one triangle, negative on the other."},"refs":["\#(id)"]}"#)],
        allowedKinds: RecordChecks.checkpointKinds, session: "s-1")
    expect(out.kept.count == 1)
    expect(out.kept[0]["by"] == nil)        // the store stamps `by`, never Sophia
    expect(out.kept[0]["status"] == nil)
    expect(out.kept[0]["quote"] != nil)
    let saved = try store.appendLearning(out.kept[0], by: "sophia", session: "s-1")
    expect(saved.str("by") == "sophia")
}

func misquoteBecomesParaphrase() throws {
    let store = try tempStore()
    let id = try store.appendTranscript(["role": .string("person"), "session": .string("s-1"), "text": .string("I think it's balanced.")]).str("id")!
    let out = RecordChecks(store: store).check(
        [j(#"{"kind":"attempt","text":"Close.","quote":{"entry":"\#(id)","text":"I know it is balanced"},"refs":["\#(id)"]}"#)],
        allowedKinds: RecordChecks.checkpointKinds, session: "s-1")
    expect(out.kept.count == 1)
    expect(out.kept[0]["quote"] == nil)
    expect(out.kept[0]["paraphrase"] == .bool(true))
}

func quoteFromAnEarlierSessionIsRemoved() throws {
    let store = try tempStore()
    let id = try store.appendTranscript(["role": .string("person"), "session": .string("s-1"), "text": .string("My old attempt")]).str("id")!
    let out = RecordChecks(store: store).check(
        [j(#"{"kind":"attempt","text":"Read.","quote":{"entry":"\#(id)","text":"My old attempt"},"refs":["\#(id)"]}"#)],
        allowedKinds: RecordChecks.checkpointKinds, session: "s-2")
    expect(out.kept.first?["quote"] == nil)
}

func rejectsDisallowedKindsAndEvidenceFreeRecords() throws {
    let store = try tempStore()
    let out = RecordChecks(store: store).check(
        [j(#"{"kind":"profile","text":"Strong at maths","refs":[]}"#),
         j(#"{"kind":"question","text":"You have a strong intuition.","refs":["t-9999"]}"#),
         j(#"{"kind":"goal","text":"Learn everything"}"#)],
        allowedKinds: RecordChecks.checkpointKinds, session: "s-1")
    expect(out.kept.isEmpty)
    expect(out.notes.contains { $0.contains("don't exist") })
}

func readMustRestOnAnAttemptNotAPage() throws {
    let store = try tempStore()
    let file = try store.writePage(title: "A page", content: "Body", revising: nil, session: "s-1", toolUseID: "tu").str("file")!
    let out = RecordChecks(store: store).check(
        [j(#"{"kind":"read","text":"Understands it.","refs":["p:\#(file)"]}"#)],
        allowedKinds: RecordChecks.checkpointKinds, session: "s-1")
    expect(out.kept.isEmpty)
}

func briefingCannotQuoteButCanCite() throws {
    let store = try tempStore()
    let id = try store.appendTranscript(["role": .string("person"), "session": .string("s-1"), "text": .string("Hello")]).str("id")!
    let out = RecordChecks(store: store).check(
        [j(#"{"kind":"briefing","text":"Last time…","quote":{"entry":"\#(id)","text":"Hello"},"refs":["\#(id)"]}"#)],
        allowedKinds: RecordChecks.briefingKinds, session: "s-2")
    expect(out.kept.count == 1)
    expect(out.kept[0]["quote"] == nil)
}

// MARK: Coming back
func catchUpCoversEverythingSinceTheLastNotesAcrossSessions() throws {
    let store = try tempStore()
    func say(_ text: String, _ session: String) throws -> String {
        try store.appendTranscript(["role": .string("person"), "session": .string(session), "text": .string(text)]).str("id")!
    }
    let old = try say("Noted already", "s-1")
    _ = try store.appendTranscript(["role": .string("client"), "session": .string("s-1"), "purpose": .string("checkpoint"),
                                    "through": .string(old), "kept": .array([])])
    let a = try say("I honestly don't remember", "s-2")
    let b = try say("It's the expected surprise", "s-3")   // a relaunch: same sitting, new session
    expect(store.unnotedMessages.compactMap { $0.str("id") } == [a, b])

    // Quotes may come from any message in the span, but not from one already noted.
    let entries = Set(store.unnotedMessages.compactMap { $0.str("id") })
    let out = RecordChecks(store: store).check(
        [j(#"{"kind":"attempt","text":"Recalled it.","quote":{"entry":"\#(b)","text":"the expected surprise"}}"#),
         j(#"{"kind":"attempt","text":"Earlier.","quote":{"entry":"\#(a)","text":"I honestly don't remember"}}"#),
         j(#"{"kind":"attempt","text":"Again.","quote":{"entry":"\#(old)","text":"Noted already"}}"#)],
        allowedKinds: RecordChecks.checkpointKinds, quoteEntries: entries)
    expect(out.kept.count == 2)
    expect(out.kept[0]["quote"] != nil && out.kept[1]["quote"] != nil)

    // Once a checkpoint covers them, they aren't offered again.
    _ = try store.appendTranscript(["role": .string("client"), "session": .string("s-4"), "purpose": .string("checkpoint"),
                                    "through": .string(b), "kept": .array([])])
    expect(store.unnotedMessages.isEmpty)
}

func olderCheckpointWithoutThroughCoversWhatCameBefore() throws {
    let store = try tempStore()
    _ = try store.appendTranscript(["role": .string("person"), "session": .string("s-1"), "text": .string("Before")])
    _ = try store.appendTranscript(["role": .string("client"), "session": .string("s-1"), "purpose": .string("checkpoint"), "kept": .array([])])
    let after = try store.appendTranscript(["role": .string("person"), "session": .string("s-2"), "text": .string("After")]).str("id")!
    expect(store.unnotedMessages.compactMap { $0.str("id") } == [after])
}

func onlyALongQuietCountsAsComingBack() throws {
    let store = try tempStore()
    expect(!store.isReturn(after: 6 * 3600))                       // nothing said yet
    _ = try store.appendTranscript(["role": .string("person"), "session": .string("s-1"), "text": .string("Hi")])
    expect(!store.isReturn(after: 6 * 3600))                       // a relaunch a moment later
    expect(store.isReturn(after: 6 * 3600, now: Date().addingTimeInterval(7 * 3600)))
    // A briefing counts as the conversation, so reopening soon after one doesn't brief again.
    _ = try store.appendTranscript(["role": .string("sophia"), "session": .string("s-2"), "purpose": .string("briefing"), "text": .string("Still open…")])
    expect(!store.isReturn(after: 6 * 3600, now: Date().addingTimeInterval(60)))
    // App notes don't count.
    _ = try store.appendTranscript(["role": .string("client"), "session": .string("s-3"), "purpose": .string("stopped")])
    expect(store.isReturn(after: 6 * 3600, now: Date().addingTimeInterval(7 * 3600)))
}

func longBriefingIsNotKept() throws {
    let store = try tempStore()
    let id = try store.appendTranscript(["role": .string("person"), "session": .string("s-1"), "text": .string("Hello")]).str("id")!
    let long = Array(repeating: "word", count: RecordChecks.briefingWordLimit + 1).joined(separator: " ")
    let out = RecordChecks(store: store).check(
        [j(#"{"kind":"briefing","text":"\#(long)","refs":["\#(id)"]}"#),
         j(#"{"kind":"briefing","text":"Still open: the cross-entropy step. Want to try it, or move on?","refs":["\#(id)"]}"#)],
        allowedKinds: RecordChecks.briefingKinds, session: "s-2")
    expect(out.kept.count == 1)
    expect(out.notes.contains { $0.contains("words") })
}

// MARK: Chapters
func sectionNumbersAreReadFromTitles() throws {
    expect(NotebookStore.splitNumber("0.1 Surprise, Entropy") == ("0.1", "Surprise, Entropy"))
    expect(NotebookStore.splitNumber("Chapter 0: Foundations") == ("0", "Foundations"))
    expect(NotebookStore.splitNumber("2. Spectral methods") == ("2", "Spectral methods"))
    expect(NotebookStore.splitNumber("Foundations") == (nil, "Foundations"))
    expect(NotebookStore.splitNumber("1990s computing") == (nil, "1990s computing"))
}

func pagesMoveIntoNumberedChaptersInOrder() throws {
    let store = try tempStore()
    func page(_ t: String) throws -> String { try store.writePage(title: t, content: "Body", revising: nil, session: "s-1", toolUseID: "tu").str("file")! }
    let road = try page("Roadmap")
    let a = try page("0.0 Probability"), b = try page("0.1 Entropy"), c = try page("1.0 Next tokens")
    _ = try store.fileInChapter([c], chapter: "Chapter 1: Language models")
    let ch = try store.fileInChapter([a, b], chapter: "Chapter 0: Foundations")
    expect(ch.heading == "Chapter 0: Foundations" && ch.pages.map(\.file) == [a, b])
    expect(store.chapters.map(\.title) == ["Foundations", "Language models"])   // number order, not creation order
    expect(store.unfiledPages.map(\.file) == [road])
    expect(store.pageFiles == [a, b, c, road])
    // Matching by number keeps one chapter; a chapter left empty disappears.
    _ = try store.fileInChapter([c], chapter: "0 Foundations")
    expect(store.chapters.count == 1 && store.chapters[0].pages.map(\.file) == [a, b, c])
    expectThrows { try store.fileInChapter(["missing.md"], chapter: "Chapter 2: X") }
}

// MARK: Notes during the conversation
func sophiaNotesDuringTheConversationWithinLimits() throws {
    let store = try tempStore()
    let t = try store.appendTranscript(["role": .string("person"), "session": .string("s-1"),
                                        "text": .string("This is something I would have known cold 15 years ago.")]).str("id")!
    // The store finds the message the quote comes from.
    let (bg, _) = try store.writeNote(["kind": .string("background"), "text": .string("Knew cross-entropy well once; rusty now.")],
                                      quote: "would have known cold 15 years ago", revising: nil, session: "s-1")
    expect(bg?["quote"]?["entry"]?.string == t && bg?.str("by") == "sophia")
    expect(store.transcript.last?.str("tool") == "note")

    // A note with nothing behind it, or of a kind Sophia can't write live, isn't saved.
    expect(try store.writeNote(["kind": .string("background"), "text": .string("Strong at maths.")], quote: "words they never said", revising: nil, session: "s-1").saved == nil)
    expect(try store.writeNote(["kind": .string("read"), "text": .string("Has it."), "refs": .array([.string(t)])], quote: nil, revising: nil, session: "s-1").saved == nil)

    // Closing a follow-up replaces it; only the latest version shows.
    let (fu, _) = try store.writeNote(["kind": .string("follow_up"), "text": .string("Check whether cross-entropy has landed."), "refs": .array([.string(t)])], quote: nil, revising: nil, session: "s-1")
    let fid = fu!.str("id")!
    let (closed, _) = try store.writeNote(["text": .string("Checked: explained it back correctly."), "refs": .array([.string(t)])], quote: nil, revising: fid, session: "s-1")
    expect(closed?.str("kind") == "follow_up" && closed?.str("replaces") == fid)
    expect(!store.shownNotes.contains { $0.str("id") == fid } && store.shownNotes.contains { $0.str("id") == closed?.str("id") })

    // A note the person corrected stays as they have it.
    _ = try store.appendLearning(["kind": .string("correction"), "replaces": bg!["id"]!, "text": .string("Not rusty, just never learned it.")], by: "person", session: "s-1")
    expect(try store.writeNote(["text": .string("Rusty."), "refs": .array([.string(t)])], quote: nil, revising: bg!.str("id"), session: "s-1").saved == nil)
    expect(store.shownNotes.contains { $0.str("id") == bg!.str("id") })   // still shown, with the correction

    // A session's new notes are capped.
    for i in 0..<NotebookStore.liveNotesPerSession {
        _ = try store.writeNote(["kind": .string("question"), "text": .string("Q\(i)"), "refs": .array([.string(t)])], quote: nil, revising: nil, session: "s-1")
    }
    let over = try store.writeNote(["kind": .string("question"), "text": .string("One more"), "refs": .array([.string(t)])], quote: nil, revising: nil, session: "s-1")
    expect(over.saved == nil && over.problems.contains { $0.contains("Revise") })
}

// MARK: Memory, recall, About you, links
func memoryIsRewrittenWholeAndKeepsItsEvidence() throws {
    let store = try tempStore()
    let t = try store.appendTranscript(["role": .string("person"), "session": .string("s-1"), "text": .string("I'd have known cross-entropy cold once")]).str("id")!
    var r = try store.setMemory([.init(id: nil, text: "Rusty on cross-entropy.", refs: [t]),
                                 .init(id: nil, text: "Check KL next.", refs: [t]),
                                 .init(id: nil, text: "Floats free.", refs: ["t-9999"])], session: "s-1")
    expect(r.memory.count == 2 && r.problems.count == 1)          // a line resting on nothing isn't kept
    let rusty = r.memory[0].str("id")!, kl = r.memory[1].str("id")!
    // Keep one, reword one (it keeps its refs), add one; nothing is dropped yet.
    r = try store.setMemory([.init(id: rusty, text: "Rusty on cross-entropy.", refs: []),
                             .init(id: kl, text: "Check the KL link next.", refs: []),
                             .init(id: nil, text: "Prefers reading chapters for fundamentals.", refs: [t])], session: "s-1")
    expect(r.memory.count == 3 && r.memory.contains { $0.str("id") == rusty })
    expect(r.memory.first { $0.str("text") == "Check the KL link next." }?["refs"] == .array([.string(t)]))
    // Leaving a line out forgets it; the person's corrected line stays.
    _ = try store.appendLearning(["kind": .string("correction"), "replaces": .string(rusty), "text": .string("Never learned it.")], by: "person", session: "s-1")
    r = try store.setMemory([], session: "s-1")
    expect(r.memory.map { $0.str("id") } == [rusty])
    // At most memoryLimit lines.
    let many = (0...NotebookStore.memoryLimit).map { NotebookStore.MemoryLine(id: nil, text: "Line \($0)", refs: [t]) }
    r = try store.setMemory(many, session: "s-1")
    expect(r.memory.count == 1 && r.problems.contains { $0.contains("at most") })
}

func recallFindsNotesByIdPageAndWords() throws {
    let store = try tempStore()
    let file = try store.writePage(title: "0.1 Entropy", content: "Body", revising: nil, session: "s-1", toolUseID: "tu").str("file")!
    let t = try store.appendTranscript(["role": .string("person"), "session": .string("s-1"), "text": .string("Cross entropy still confuses me")]).str("id")!
    let a = try store.writeNote(["kind": .string("follow_up"), "text": .string("Check cross-entropy has landed."), "refs": .array([.string(t), .string("p:" + file)])], quote: nil, revising: nil, session: "s-1").saved!
    _ = try store.writeNote(["kind": .string("question"), "text": .string("Why base 2?"), "refs": .array([.string(t)])], quote: nil, revising: nil, session: "s-1")
    expect(store.recall(ids: [a.str("id")!]).notes.count == 1)
    expect(store.recall(page: file).notes.map { $0.str("id") } == [a.str("id")])
    let byWords = store.recall(words: "cross ENTROPY")
    expect(byWords.notes.count == 1 && byWords.messages.map { $0.str("id") } == [t])
    expect(store.recall(words: "eigenvalue").notes.isEmpty)
}

func libraryTemp() throws -> (LibraryStore, NotebookStore, NotebookStore) {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("sophia-lib-\(UUID().uuidString)")
    let a = try NotebookStore(url: root.appendingPathComponent("Graph Clustering"))
    let b = try NotebookStore(url: root.appendingPathComponent("LLMs"))
    return (LibraryStore(root: root), a, b)
}

func aboutYouIsProvisionalAndStaysHomeUntilConfirmed() throws {
    let (lib, a, b) = try libraryTemp()
    _ = try a.appendTranscript(["role": .string("person"), "session": .string("s-1"), "text": .string("I have a PhD in computer science but stopped following ML.")])
    expect(try lib.proposeAbout(text: "Has a PhD in CS.", quote: "I have a doctorate", revising: nil, from: a).saved == nil)   // not their words
    let line = try lib.proposeAbout(text: "PhD in computer science; away from ML research for years.", quote: "PhD in computer science", revising: nil, from: a).saved!
    expect(lib.aboutLines(visibleIn: a.name).count == 1 && lib.aboutLines(visibleIn: b.name).isEmpty)
    try lib.setAbout(text: line.str("text")!, replacing: line.str("id"), notebook: nil)   // the person confirms
    expect(lib.aboutLines(visibleIn: b.name).count == 1 && !LibraryStore.isProvisional(lib.aboutLines[0]))
    expect(try lib.proposeAbout(text: "Changed.", quote: "PhD in computer science", revising: lib.aboutLines[0].str("id"), from: a).saved == nil)
    try lib.deleteAbout(lib.aboutLines[0].str("id")!)
    expect(lib.aboutLines.isEmpty)
}

func linksAreConfirmedBeforeAnythingIsRead() throws {
    let (lib, a, b) = try libraryTemp()
    let pa = try a.writePage(title: "Why the Fiedler vector splits a graph", content: "Rayleigh", revising: nil, session: "s-1", toolUseID: "tu").str("file")!
    let pb = try b.writePage(title: "0.2 Eigenvectors", content: "Rayleigh too", revising: nil, session: "s-1", toolUseID: "tu").str("file")!
    expect(lib.otherNotebooks(than: b.name).map(\.name) == [a.name])          // titles only
    expect(try lib.proposeLink(from: b, page: pb, toNotebook: a.name, toPage: "missing.md", reason: "x").saved == nil)
    let l = try lib.proposeLink(from: b, page: pb, toNotebook: a.name, toPage: pa, reason: "Both rest on the Rayleigh quotient.").saved!
    expect(!lib.mayRead(pa, in: a.name, from: b.name))                         // provisional: nothing crosses
    try lib.confirmLink(l.str("id")!)
    expect(lib.mayRead(pa, in: a.name, from: b.name) && lib.mayRead(pb, in: b.name, from: a.name))
    expect(lib.links(touching: a.name).count == 1)
    // A notebook kept separate drops out of view, links, and reading.
    try a.setSeparate(true)
    expect(lib.otherNotebooks(than: b.name).isEmpty && !lib.mayRead(pa, in: a.name, from: b.name))
    expect(try lib.proposeLink(from: a, page: pa, toNotebook: b.name, toPage: pb, reason: "x").saved == nil)
}

func checkpointRepliesCarryNotesAndMemory() throws {
    let both = RecordChecks.parseCheckpoint(#"{"notes":[{"kind":"question","text":"q"}],"memory":[{"text":"m","refs":["t-0001"]}]}"#)
    expect(both.notes.count == 1 && both.memory?.count == 1)
    let old = RecordChecks.parseCheckpoint(#"[{"kind":"question","text":"q"}]"#)
    expect(old.notes.count == 1 && old.memory == nil && old.parsed)
    expect(RecordChecks.parseCheckpoint(#"{"notes":[],"memory":[]}"#).memory == nil)   // an empty memory never wipes it
}

func deepLinksNameASectionThatExists() throws {
    let (lib, a, b) = try libraryTemp()
    let body = "Intro.\n\n## 1. Surprise\n\nText one.\n\n```\n## not a heading\n```\n\n### Why the log\n\nDetail.\n\n## 2. Entropy\n\nText two."
    let pa = try a.writePage(title: "0.1 Entropy", content: body, revising: nil, session: "s-1", toolUseID: "tu").str("file")!
    let pb = try b.writePage(title: "Losses", content: "Cross-entropy loss.", revising: nil, session: "s-1", toolUseID: "tu").str("file")!
    expect(a.sections(of: pa).map(\.title) == ["1. Surprise", "Why the log", "2. Entropy"])
    let surprise = a.section("1 surprise", of: pa)!                      // matched loosely
    let text = a.sectionText(surprise, of: pa) ?? ""
    expect(text.contains("Text one.") && text.contains("Detail.") && !text.contains("Text two."))
    expect(lib.otherNotebooks(than: b.name).first?.pages.contains("§ Why the log") == true)
    expect(try lib.proposeLink(from: b, page: pb, toNotebook: a.name, toPage: pa, toSection: "3. Nothing", reason: "x").saved == nil)
    let l = try lib.proposeLink(from: b, page: pb, toNotebook: a.name, toPage: pa, toSection: "2 entropy", reason: "Loss is cross-entropy.").saved!
    expect(l["to"]?["section"]?.string == "2. Entropy")               // stored as written in the page
}

func aReplyWrittenTwiceIsRecognized() throws {
    let first = "That's not true in general. It holds for symmetric matrices, and more generally for normal matrices. That's the spectral theorem. It fails for arbitrary square matrices. Counterexample: the matrix with rows one one and zero two has eigenvectors one zero and one one, whose dot product is one, so they are not orthogonal. Rescaling an eigenvector doesn't change its direction."
    let again = "Your notes are wrong on this one. Only symmetric matrices, or more generally normal ones, are guaranteed orthogonal eigenvectors. That's the spectral theorem. For other square matrices the eigenvectors may not be orthogonal: the matrix with rows one one and zero two has eigenvectors one zero and one one, whose dot product is one. Rescaling doesn't change their direction."
    let different = "Next, the singular value decomposition writes every matrix as a rotation, a diagonal scaling, and another rotation. Unlike eigenvectors, input and output directions differ, which is why it always exists and why least squares, low rank approximation, and principal components analysis all depend on it in practice."
    expect(Prompts.isRestatement(first, of: [first]))
    expect(Prompts.isRestatement("  " + first + "\n", of: [first]))
    expect(!Prompts.isRestatement(again, of: [first]))
    expect(!Prompts.isRestatement(first + " A one-mass kick adds another mode because its velocity is not proportional to the mode shape.", of: [first]))
    expect(!Prompts.isRestatement("The velocities must follow (1,-1).", of: ["The velocities must not follow (1,-1). "]))
    expect(!Prompts.isRestatement("", of: [" "]))
    expect(!Prompts.isRestatement(different, of: [first]))
    expect(!Prompts.isRestatement("I added a page with this.", of: [first]))
}

func extractsJSONFromAFencedReply() throws {
    let v = RecordChecks.extractJSON("Here you go:\n```json\n[{\"kind\":\"question\",\"text\":\"x\"}]\n```")
    expect(v?.array?.count == 1)
}

// MARK: PageTests
func sophiaWritesAPageDirectlyAndUndoRemovesIt() throws {
    let store = try tempStore()
    let e = try store.writePage(title: "Why the Fiedler vector splits a graph", content: "xᵀLx", revising: nil, session: "s-1", toolUseID: "tu")
    let file = e.str("file")!
    expect(store.readPage(file)?.body.contains("xᵀLx") == true)
    expect(store.readPage(file)?.title == "Why the Fiedler vector splits a graph")
    expect(try NotebookStore(url: store.url).pageFiles == [file])
    try store.undoPageWrite(e.str("id")!, session: "s-1")
    let reopened = try NotebookStore(url: store.url)
    expect(reopened.pageFiles.isEmpty)
    expect(reopened.isUndone(e.str("id")!))
}

func revisionKeepsThePreviousVersionAndUndoRestoresIt() throws {
    let store = try tempStore()
    let file = try store.writePage(title: "T", content: "First", revising: nil, session: "s-1", toolUseID: "1").str("file")!
    let r = try store.writePage(title: "T, revised", content: "Second", revising: file, session: "s-1", toolUseID: "2")
    expect(r.str("file") == file)
    expect(store.pageFiles == [file])
    expect(store.readPage(file)?.body.contains("Second") == true)
    expect(store.readPreviousVersion(file)?.body.contains("First") == true)
    try store.undoPageWrite(r.str("id")!, session: "s-1")
    expect(store.readPage(file)?.body.contains("First") == true)
    expect(store.readPage(file)?.title == "T")
}

func twoWritersDoNotLoseEachOthersWork() throws {
    let app = try tempStore()
    let tools = try NotebookStore(url: app.url)   // the tool server's copy, opened earlier
    try app.appendTranscript(["role": .string("person"), "session": .string("s-1"), "text": .string("Keep this")])
    let w = try tools.writePage(title: "P", content: "B", revising: nil, session: "s-1", toolUseID: "tu")
    try app.appendTranscript(["role": .string("sophia"), "session": .string("s-1"), "text": .string("Done")])
    let ids = try NotebookStore(url: app.url).transcript.compactMap { $0.str("id") }
    expect(ids == ["t-0001", "t-0002", "t-0003"])
    expect(app.pageFiles == [w.str("file")!])
}

func undecidedDraftsFromOlderNotebooksBecomePages() throws {
    let store = try tempStore()
    for (pid, title) in [("pr-1", "Pending"), ("pr-2", "Discarded")] {
        try store.appendTranscript(["role": .string("tool"), "session": .string("s-1"), "proposal": .string(pid), "target": .string("page"),
                                    "tool_use": .string("tu"), "payload": .object(["title": .string(title), "content": .string("Body")])])
    }
    try store.appendTranscript(["role": .string("client"), "session": .string("s-1"), "proposal": .string("pr-2"), "decision": .string("reject")])
    store.fileUndecidedDrafts(session: "s-2")
    store.fileUndecidedDrafts(session: "s-3")
    expect(store.pages.map(\.title) == ["Pending"])
}

// MARK: GoalTests
func sophiasGoalIsProvisionalUntilConfirmedAndCriteriaOnlyGrow() throws {
    let store = try tempStore()
    try store.appendTranscript(["role": .string("person"), "session": .string("s-1"), "text": .string("I want to be able to explain spectral clustering to my team.")])
    let g = try store.writeGoal(text: "Explain spectral clustering to your team", criteria: ["Explain why the Fiedler vector splits a graph"],
                                revising: nil, quote: "explain spectral clustering to my team", session: "s-1")
    expect(store.isProvisional(store.goals[0]))
    expect(g["quote"] != nil)
    expect(g.str("status") == "working")
    let r = try store.writeGoal(text: "Explain spectral clustering to your team, with an example", criteria: ["Work an example by hand"],
                                revising: g.str("id"), quote: "words they never said", session: "s-1")
    expect(r["quote"] == nil)
    expect(store.goals.count == 1)
    expect(store.goals[0]["criteria"]?.array?.count == 2)
    expect(store.rootID(of: r.str("id")!) == g.str("id"))
    var confirmed: JSONObject = ["kind": .string("goal"), "replaces": r["id"]!]
    for k in ["text", "status", "criteria"] { confirmed[k] = r[k] }
    try store.appendLearning(confirmed, by: "person", session: "s-1")
    expect(!store.isProvisional(store.goals[0]))
}

func orphanPageIsListedAfterACrash() throws {
    let store = try tempStore()
    try Data("---\ntitle: \"Orphan\"\n---\nBody\n".utf8).write(to: store.pagesURL.appendingPathComponent("orphan.md"))
    expect(try NotebookStore.open(url: store.url).pageFiles == ["orphan.md"])
}

// MARK: LearningTests
func deletingARecordRemovesItsCorrectionsAndUndoRestores() throws {
    let store = try tempStore()
    let a = try store.appendLearning(["kind": .string("attempt"), "text": .string("Read")], by: "sophia", session: "s-1")
    _ = try store.appendLearning(["kind": .string("correction"), "text": .string("Mine"), "replaces": a["id"]!], by: "person", session: "s-2")
    let removed = try store.deleteLearning(a.str("id")!)
    expect(removed.count == 2)
    expect(try NotebookStore(url: store.url).learning.isEmpty)
    try store.restoreLearning(removed)
    expect(store.learning.count == 2)
}

func goalRewordKeepsItsFirstID() throws {
    let store = try tempStore()
    let g = try store.appendLearning(["kind": .string("goal"), "text": .string("Refresh"), "status": .string("working")], by: "person", session: "s-1")
    let g2 = try store.appendLearning(["kind": .string("goal"), "text": .string("Get fluent"), "status": .string("working"), "replaces": g["id"]!], by: "person", session: "s-2")
    expect(store.goals.count == 1)
    expect(store.rootID(of: g2.str("id")!) == g.str("id"))
}


// MARK: The person's edits (EDITING.md)
let editBody = "Opening line with $x$.\n\n## 1. Signs\n\nThe sign is $-1$.\t\n\n```\n## not a heading\n```\n\n### Detail\n\n* odd marker\n+ another   \n\n## 2. Next\n\nλ₂ ≈ 0.4\n\n> “Positive on one side.” <!-- quote: t-0001 -->\n"

func editStore(_ body: String = editBody, raw: String? = nil) throws -> (NotebookStore, String) {
    let store = try tempStore()
    let file = try store.writePage(title: "Signs", content: "x", revising: nil, session: "s-1", toolUseID: "tu").str("file")!
    try Data((raw ?? "---\ntitle: \"Signs\"\nsources: []   \n---\n" + body).utf8).write(to: store.pagesURL.appendingPathComponent(file))
    return (store, file)
}

func range(_ store: NotebookStore, _ file: String, _ key: String) -> NotebookStore.EditRange { store.editRanges(of: file).first { $0.key == key }! }

func splicingASectionLeavesEveryOtherByteIdentical() throws {
    let crlf = editBody.replacingOccurrences(of: "\n", with: "\r\n")
    for raw in ["---\ntitle: \"Signs\"\nsources: []   \n---\n" + editBody, "---\ntitle: \"Signs\"\n---\n" + crlf,
                "---\ntitle: \"Signs\"\n---\n\n# Signs\n\n" + editBody] {
        let (store, file) = try editStore(raw: raw)
        let url = store.pagesURL.appendingPathComponent(file)
        let before = try Data(contentsOf: url)
        expect(store.editRanges(of: file).map(\.key) == ["(opening)", "§0", "§1", "§2", "(page)"])
        let s = range(store, file, "§0")
        expect(s.text.contains("## not a heading") && s.text.contains("### Detail") && !s.text.contains("2. Next"))
        let edited = s.text.replacingOccurrences(of: "$-1$", with: "$+1$")
        guard case .saved = try store.editPage(file: file, section: "§0", baseHash: s.hash, text: edited, session: "s-1") else { expect(false); continue }
        let expected = String(decoding: before, as: UTF8.self).replacingOccurrences(of: "$-1$", with: "$+1$")
        expect(try Data(contentsOf: url) == Data(expected.utf8))
        expect(try Data(contentsOf: store.pagesURL.appendingPathComponent(String(file.dropLast(3)) + ".previous.md")) == before)
        // The whole page, opened and committed untouched, writes nothing; a repeated title stays out of it.
        let page = range(store, file, "(page)")
        expect(!page.text.contains("# Signs\n") && !page.text.hasPrefix("# Signs"))
        let count = store.transcript.count
        guard case .unchanged = try store.editPage(file: file, section: "(page)", baseHash: page.hash, text: page.text, session: "s-1") else { expect(false); continue }
        expect(try store.transcript.count == count && Data(contentsOf: url) == Data(expected.utf8))
    }
}

func aCommitWithNoChangeWritesNothing() throws {
    let (store, file) = try editStore()
    let s = range(store, file, "§1")
    let count = store.transcript.count
    guard case .unchanged = try store.editPage(file: file, section: "§1", baseHash: s.hash, text: s.text, session: "s-1") else { expect(false); return }
    expect(store.transcript.count == count)
    expect(!store.hasPreviousVersion(file))
    expect(store.protectedLines(of: file).isEmpty)
}

func aCommitAgainstAChangedSectionIsRefused() throws {
    let (store, file) = try editStore()
    let s = range(store, file, "§2")
    let body = store.readPage(file)!.body
    // Sophia's revision lands before the editor's marker (or the person undid something meanwhile).
    try store.writePage(title: "Signs", content: body.replacingOccurrences(of: "λ₂ ≈ 0.4\n", with: "λ₂ is about 0.4\n"), revising: file, session: "s-1", toolUseID: "2")
    let onDisk = try Data(contentsOf: store.pagesURL.appendingPathComponent(file))
    guard case .conflict(let current) = try store.editPage(file: file, section: "§2", baseHash: s.hash, text: s.text + "\nMine.", session: "s-1") else { expect(false); return }
    expect(current?.text.contains("about 0.4") == true)
    expect(try Data(contentsOf: store.pagesURL.appendingPathComponent(file)) == onDisk)
    // Keep mine: commit against the new base.
    guard case .saved = try store.editPage(file: file, section: "§2", baseHash: current!.hash, text: s.text + "\nMine.", session: "s-1") else { expect(false); return }
    expect(store.readPage(file)!.body.contains("Mine."))
    // Sections inserted above move the range; it is found by its text.
    let s0 = range(store, file, "§0")
    let b2 = store.readPage(file)!.body
    try store.writePage(title: "Signs", content: b2.replacingOccurrences(of: "## 1. Signs", with: "## 0. New\n\nNew.\n\n## 1. Signs").dropLast() + "", revising: file, session: "s-1", toolUseID: "3")
    guard case .saved = try store.editPage(file: file, section: "§0", baseHash: s0.hash, text: s0.text.replacingOccurrences(of: "$-1$", with: "$1$"), session: "s-1") else { expect(false); return }
    expect(store.readPage(file)!.body.contains("## 0. New") && store.readPage(file)!.body.contains("$1$"))
}

func protectedLinesAndQuotesRefuseSophiasRevision() throws {
    let (store, file) = try editStore()
    let s = range(store, file, "§2")
    guard case .saved(let edit) = try store.editPage(file: file, section: "§2", baseHash: s.hash, text: s.text.replacingOccurrences(of: "0.4", with: "0.44"), session: "s-1") else { expect(false); return }
    expect(edit["hunks"]?.array?.first?["before"]?.string == "λ₂ ≈ 0.4" && edit["hunks"]?.array?.first?["after"]?.string == "λ₂ ≈ 0.44")
    expect(store.unnotedMessages.isEmpty && !store.hasEarlierConversation)        // an edit isn't a message
    let body = store.readPage(file)!.body.dropLast()
    let reworded = try store.writePage(title: "Signs", content: body.replacingOccurrences(of: "λ₂ ≈ 0.44", with: "λ₂ ≈ 0.45"), revising: file, session: "s-1", toolUseID: "2", why: "Recomputed.")
    expect(reworded["refused"] == .bool(true) && reworded.str("section") == "2. Next" && reworded.str("edit") == edit.str("id"))
    expect(reworded.str("why") == "Recomputed." && reworded.str("current")?.contains("0.44") == true)
    expect(store.readPage(file)!.body.contains("0.44") && store.pageWrites.count == 1)
    let unquoted = try store.writePage(title: "Signs", content: body.replacingOccurrences(of: "“Positive on one side.”", with: "“Positive.”"), revising: file, session: "s-1", toolUseID: "3")
    expect(unquoted["refused"] == .bool(true) && unquoted.str("reason") == "quote")
    let intact = try store.writePage(title: "Signs", content: body.replacingOccurrences(of: "Opening line", with: "First line"), revising: file, session: "s-1", toolUseID: "4")
    expect(intact["refused"] == nil && store.readPage(file)!.body.contains("First line"))
    // The person deletes their own line: it is no longer protected.
    let s2 = range(store, file, "§2")
    _ = try store.editPage(file: file, section: "§2", baseHash: s2.hash, text: s2.text.replacingOccurrences(of: "λ₂ ≈ 0.44\n", with: ""), session: "s-1")
    expect(store.protectedLines(of: file).isEmpty)
}

func anOpenSectionIsRefusedAndOthersAreNot() throws {
    let (store, file) = try editStore()
    _ = try store.beginEdit(file: file, key: "§2", session: "s-1")
    let body = store.readPage(file)!.body.dropLast()
    let tools = try NotebookStore(url: store.url)       // the tool server's process
    let open = try tools.writePage(title: "Signs", content: body.replacingOccurrences(of: "0.4", with: "0.5"), revising: file, session: "s-1", toolUseID: "2")
    expect(open["refused"] == .bool(true) && open.str("reason") == "open")
    let other = try tools.writePage(title: "Signs", content: body.replacingOccurrences(of: "$-1$", with: "$1$"), revising: file, session: "s-1", toolUseID: "3")
    expect(other["refused"] == nil)
    store.endEdit()
    expect(store.editMarker == nil)
    expect(try tools.writePage(title: "Signs", content: body.replacingOccurrences(of: "0.4", with: "0.5"), revising: file, session: "s-1", toolUseID: "4")["refused"] == nil)
}

func undoingAPersonEditRestoresThePreviousVersion() throws {
    let (store, file) = try editStore()
    let before = store.readPage(file)!.body
    let s = range(store, file, "(opening)")
    guard case .saved(let edit) = try store.editPage(file: file, section: "(opening)", baseHash: s.hash, text: "Fixed typo.\n", session: "s-1") else { expect(false); return }
    expect(store.isLatestWrite(edit.str("id")!))
    try store.undoPageWrite(edit.str("id")!, session: "s-1")
    expect(store.readPage(file)!.body == before)
    expect(store.transcript.last?.str("purpose") == "undo_page" && store.transcript.last?.str("entry") == edit.str("id"))
    expect(store.protectedLines(of: file).isEmpty)
    expectThrows { try store.undoPageWrite(edit.str("id")!, session: "s-1") }
}

func aReleaseLiftsOnlyThatEdit() throws {
    let (store, file) = try editStore()
    let a = range(store, file, "§0")
    guard case .saved(let e1) = try store.editPage(file: file, section: "§0", baseHash: a.hash, text: a.text.replacingOccurrences(of: "$-1$", with: "$+1$"), session: "s-1") else { expect(false); return }
    let b = range(store, file, "§2")
    guard case .saved(let e2) = try store.editPage(file: file, section: "§2", baseHash: b.hash, text: b.text.replacingOccurrences(of: "0.4", with: "0.44"), session: "s-1") else { expect(false); return }
    let since = store.transcript.count
    let body = store.readPage(file)!.body.dropLast()
    let both = body.replacingOccurrences(of: "0.44", with: "0.45").replacingOccurrences(of: "$+1$", with: "$1$")
    expect(try store.writePage(title: "Signs", content: both, revising: file, session: "s-1", toolUseID: "2")["refused"] == .bool(true))
    let released = try store.releaseEdits([e2.str("id")!], session: "s-1")
    expect(try store.writePage(title: "Signs", content: both, revising: file, session: "s-1", toolUseID: "3")["refused"] == .bool(true))   // e1 still protected
    let one = body.replacingOccurrences(of: "0.44", with: "0.45")
    try store.undoRelease(released[0].str("id")!, session: "s-1")
    expect(try store.writePage(title: "Signs", content: one, revising: file, session: "s-1", toolUseID: "4")["refused"] == .bool(true))
    try store.releaseEdits([e2.str("id")!], session: "s-1")
    expect(try store.writePage(title: "Signs", content: one, revising: file, session: "s-1", toolUseID: "5")["refused"] == nil)
    expect(store.protectedLines(of: file).map { $0.edit.str("id") } == [e1.str("id")])
    let told = Prompts.bookChanges(store, since: since)
    expect(told.contains("Let you change their edit") && told.contains("Took back") && !told.contains("Edited"))
    expect(Prompts.bookChanges(store, since: 0).contains("was: λ₂ ≈ 0.4\n  now: λ₂ ≈ 0.44"))
}

func notationWarningsNameTheirPageAndSection() throws {
    let body = "# Tunes\n\nOpening.\n\n## Reels\n\n### The first\n\n```abc\nK:C\nCD@E|\n```\n\n## Airs\n\nText."
    let ranges = NotebookStore.editRanges(in: body, hidden: 2)
    expect(NotebookStore.sectionTitle(containing: 2, in: ranges) == nil)
    expect(NotebookStore.sectionTitle(containing: 8, in: ranges) == "The first")
    expect(NotebookStore.sectionTitle(containing: 15, in: ranges) == "Airs")
    expect(Prompts.musicWarnings([]) == "")
    let warning = "Line 2 of the tune, column 3: Unknown character ignored: CD@E|"
    let told = Prompts.musicWarnings([
        MusicWarnings(file: "tunes.md", page: "Tunes", section: "The first", tune: "Reel", warnings: [warning]),
        MusicWarnings(file: "tunes.md", page: "Tunes", section: nil, tune: "", warnings: (1...7).map { "w\($0)" })
    ])
    expect(told.hasPrefix("[Sophia app]") && told.hasSuffix("The person's message follows.\n\n"))
    expect(told.contains("- “Tunes” (tunes.md), section “The first”, tune “Reel”: \(warning)\n"))
    expect(told.contains("- “Tunes” (tunes.md): w1; w2; w3; w4; w5 (and 2 more)\n"))
}

// Page-owned conversation checks. Crash fixtures below represent persisted boundaries, not OS crashes.
func fixturePage(_ store: NotebookStore, _ title: String = "P", body: String = "First", thread: String = "") throws -> JSONObject {
    try store.writePage(title: title, content: body, revising: nil, session: "s-1", toolUseID: UUID().uuidString, thread: thread)
}
@discardableResult
func message(_ store: NotebookStore, _ text: String, page: String, role: String = "person", session: String = "s-1") throws -> JSONObject {
    try store.appendTranscript(["role": .string(role), "text": .string(text), "page": .string(page), "session": .string(session)])
}
func verificationInterleavedThreadOwnership() throws {
    let s = try tempStore()
    let p = try fixturePage(s).str("file")!, q = try fixturePage(s, "Q").str("file")!
    let person = try message(s, "P words", page: p)
    _ = try message(s, "Q words", page: q)
    // These synthetic fields exercise appendTranscript preservation, not NotebookSession/MCP delivery.
    let paths: [JSONObject] = [
        ["role": .string("sophia"), "text": .string("Answer")],
        ["role": .string("tool"), "tool": .string("WebSearch")],
        ["role": .string("client"), "purpose": .string("goal_noted")],
        ["role": .string("tool"), "tool": .string("set_chapter")],
        ["role": .string("tool"), "tool": .string("about_you")],
        ["role": .string("tool"), "tool": .string("link")],
        ["role": .string("client"), "purpose": .string("stopped")],
        ["role": .string("client"), "purpose": .string("replied")]
    ]
    for fields in paths { var fields = fields; fields["page"] = .string(p); expect(NotebookStore.thread(of: try s.appendTranscript(fields)) == p) }
    let write = try s.writePage(title: "Q", content: "Changed", revising: q, session: "s-1", toolUseID: "cross", thread: p)
    expect(NotebookStore.thread(of: write) == p)
    // Another app action reloads the saved tool effect before its result callback arrives.
    let reloadedCopy = try NotebookStore(url: s.url)
    _ = try message(reloadedCopy, "Queued while the tool result was pending", page: q)
    reloadedCopy.reload()
    expect(reloadedCopy.pageWrite(toolUse: "cross")?.str("id") == write.str("id"))
    expect(reloadedCopy.pageWrite(toolUse: "not-a-tool-use") == nil)
    let range = s.editRanges(of: q).last!
    guard case .saved(let edit) = try s.editPage(file: q, section: range.key, baseHash: range.hash, text: "Protected", session: "s-1") else { expect(false); return }
    expect(NotebookStore.thread(of: edit) == q && edit.str("hash") == s.pageHash(q))
    let refusal = try s.writePage(title: "Q", content: "Dropped", revising: q, session: "s-1", toolUseID: "refusal", thread: p)
    expect(NotebookStore.thread(of: refusal) == q && refusal["refused"] == .bool(true))
    let release = try s.releaseEdits([edit.str("id")!], session: "s-1")[0]
    expect(NotebookStore.thread(of: release) == q && release["hash"] == nil)
    try s.undoRelease(release.str("id")!, session: "s-1")
    expect(NotebookStore.thread(of: s.transcript.last!) == q)
    let note = try s.writeNote(["kind": .string("question"), "text": .string("Open")], quote: "P words", revising: nil, session: "s-1", thread: p)
    expect(note.saved != nil && NotebookStore.thread(of: s.transcript.last!) == p)
    _ = try s.setMemory([.init(id: nil, text: "Remember", refs: [person.str("id")!])], session: "s-1")
    expect(NotebookStore.thread(of: s.transcript.last!) == "")
    for purpose in ["checkpoint", "briefing"] {
        let e = try s.appendTranscript(["role": .string("client"), "purpose": .string(purpose), "page": .string(p)])
        expect(NotebookStore.thread(of: e) == "")
    }
    expect(NotebookStore.thread(of: [:]) == "" && NotebookStore.thread(of: ["page": .string("")]) == "")
    expect(NotebookStore.isPending(thread: q, running: p, queued: [q]))
    expect(NotebookStore.nextStep(thread: q, pending: true) == .wait)
}
func verificationUndoAcrossScopesAndReopen() throws {
    let s = try tempStore(); let w = try fixturePage(s), p = w.str("file")!
    _ = try message(s, "P conversation", page: p); _ = try message(s, "Q conversation", page: "q.md")
    let reopened = try NotebookStore.open(url: s.url)
    expect(reopened.isUndoable(w))
    let revision = try reopened.writePage(title: "P", content: "Second", revising: p, session: "s-2", toolUseID: "revision", thread: p)
    _ = try message(reopened, "More", page: p)
    expect(try NotebookStore.open(url: s.url).isUndoable(revision))
    expectThrows { try s.undoPageWrite(w.str("id")!, session: "s-1") }
    try reopened.undoPageWrite(revision.str("id")!, session: "s-2")
    expect(reopened.readPage(p)?.body == "First\n")
    let original = try Data(contentsOf: reopened.pagesURL.appendingPathComponent(p))
    let range = reopened.editRanges(of: p).last!
    guard case .saved(let edit) = try reopened.editPage(file: p, section: range.key, baseHash: range.hash, text: "Person edit", session: "s-2") else { expect(false); return }
    _ = try message(reopened, "After my edit in P", page: p)
    _ = try message(reopened, "After my edit in Q", page: "q.md")
    let afterEdit = try NotebookStore.open(url: reopened.url)
    expect(afterEdit.isUndoable(edit))
    try afterEdit.undoPageWrite(edit.str("id")!, session: "s-3")
    expect(try Data(contentsOf: afterEdit.pagesURL.appendingPathComponent(p)) == original)
    expect(!afterEdit.isUndoable(edit) && afterEdit.transcript.last?.str("page") == p)
}
func verificationLatestReleaseAndOneWayUndo() throws {
    let s = try tempStore(); let p = try fixturePage(s).str("file")!, r = s.editRanges(of: p).last!
    guard case .saved(let edit) = try s.editPage(file: p, section: r.key, baseHash: r.hash, text: "Mine", session: "s-1") else { expect(false); return }
    let release = try s.releaseEdits([edit.str("id")!], session: "s-1")[0]
    expect(!s.isUndoable(edit) && s.isReleaseUndoable(release))
    try s.undoRelease(release.str("id")!, session: "s-1")
    expect(!s.isUndoable(edit) && !s.isReleaseUndoable(release) && !s.isUndoable(s.transcript.last!))
    expectThrows { try s.undoRelease(release.str("id")!, session: "s-1") }
    let again = try s.releaseEdits([edit.str("id")!], session: "s-1")[0]
    _ = try s.writePage(title: "P", content: "Sophia", revising: p, session: "s-1", toolUseID: "rewrite", thread: p)
    expect(!s.isReleaseUndoable(again))

    // Separate controls release one edit at a time; the latest-action rule remains scalar.
    let two = try tempStore(), file = try fixturePage(two, body: "One\nTwo").str("file")!
    let firstRange = two.editRanges(of: file).last!
    guard case .saved(let e1) = try two.editPage(file: file, section: firstRange.key, baseHash: firstRange.hash, text: "First mine\nTwo", session: "s-1") else { expect(false); return }
    let secondRange = two.editRanges(of: file).last!
    guard case .saved(let e2) = try two.editPage(file: file, section: secondRange.key, baseHash: secondRange.hash, text: "First mine\nSecond mine", session: "s-1") else { expect(false); return }
    let refusal = try two.writePage(title: "P", content: "Drops both", revising: file, session: "s-1", toolUseID: "refused")
    expect(Set((refusal["edits"]?.array ?? []).compactMap(\.string)) == Set([e1.str("id")!, e2.str("id")!]))
    let r1 = try two.releaseEdits([e1.str("id")!], session: "s-1")[0]
    expect(two.isReleased(e1.str("id")!) && !two.isReleased(e2.str("id")!))
    expect(two.protectedLines(of: file).map { $0.edit.str("id")! } == [e2.str("id")!])
    let r2 = try two.releaseEdits([e2.str("id")!], session: "s-1")[0]
    expect(!two.isReleaseUndoable(r1) && two.isReleaseUndoable(r2) && two.protectedLines(of: file).isEmpty)
    try two.undoRelease(r2.str("id")!, session: "s-1")
    expect(two.isReleased(e1.str("id")!) && !two.isReleased(e2.str("id")!))
    expect(two.protectedLines(of: file).map { $0.edit.str("id")! } == [e2.str("id")!])
    expect(!two.isReleaseUndoable(r1) && !two.isReleaseUndoable(r2) && !two.isUndoable(two.transcript.last!))
}
func verificationRecoveredRevisionBeforeEntry() throws {
    for iteration in 0..<2 {
        let s = try tempStore(); let w = try fixturePage(s), p = w.str("file")!
        let original = try Data(contentsOf: s.pagesURL.appendingPathComponent(p))
        try original.write(to: s.pagesURL.appendingPathComponent(NotebookStore.previousName(p)))
        try Data("---\ntitle: \"P\"\n---\nUnrecorded \(iteration)\n".utf8).write(to: s.pagesURL.appendingPathComponent(p), options: .atomic)
        let opened = try NotebookStore.open(url: s.url), recovered = opened.transcript.last!
        expect(recovered["recovered"] == .bool(true) && recovered.str("hash") == opened.pageHash(p))
        expect(!opened.isUndoable(recovered) && !opened.isUndoable(w))
        expect(try NotebookStore.open(url: s.url).transcript.count == opened.transcript.count)
        let found = try Data(contentsOf: opened.pagesURL.appendingPathComponent(p))
        expectThrows { try opened.undoPageWrite(recovered.str("id")!, session: "s-2") }
        expect(try Data(contentsOf: opened.pagesURL.appendingPathComponent(p)) == found)
        expect(try Data(contentsOf: opened.pagesURL.appendingPathComponent(NotebookStore.previousName(p))) == original)
    }
}
func verificationRecoveredNewPageBeforeUnfiled() throws {
    let s = try tempStore(), file = "orphan.md"
    try Data("Orphan bytes".utf8).write(to: s.pagesURL.appendingPathComponent(file))
    expect(try NotebookStore(url: s.url).pageFiles.isEmpty)
    let opened = try NotebookStore.open(url: s.url)
    expect(opened.pageFiles == [file] && opened.transcript.last?["recovered"] == .bool(true))
    let found = opened.transcript.last!
    expect(!opened.isUndoable(found))
    expectThrows { try opened.undoPageWrite(found.str("id")!, session: "s-2") }
    expect(try Data(contentsOf: opened.pagesURL.appendingPathComponent(file)) == Data("Orphan bytes".utf8))
    expect(try NotebookStore.open(url: s.url).transcript.count == 1)
    let other = try tempStore(), recorded = try fixturePage(other), f = recorded.str("file")!
    try Data("{\"chapters\":[],\"unfiled\":[]}".utf8).write(to: other.url.appendingPathComponent("notebook.json"))
    let listed = try NotebookStore.open(url: other.url)
    expect(listed.pageFiles == [f] && listed.transcript.count == 1)
}
func verificationExternalAndCopyOnlyChanges() throws {
    let s = try tempStore(), p = try fixturePage(s).str("file")!
    let r = try s.writePage(title: "P", content: "Second", revising: p, session: "s-1", toolUseID: "r")
    let count = s.transcript.count
    try Data("Outside".utf8).write(to: s.pagesURL.appendingPathComponent(p))
    let external = try NotebookStore.open(url: s.url)
    expect(external.transcript.count == count && !external.isUndoable(r))
    let copyOnly = try tempStore(), f = try fixturePage(copyOnly).str("file")!
    let last = try copyOnly.writePage(title: "P", content: "Second", revising: f, session: "s-1", toolUseID: "r")
    try Data(contentsOf: copyOnly.pagesURL.appendingPathComponent(f)).write(to: copyOnly.pagesURL.appendingPathComponent(NotebookStore.previousName(f)))
    let opened = try NotebookStore.open(url: copyOnly.url)
    expect(opened.transcript.count == 2 && !opened.isUndoable(last))
    let legacy = try tempStore(), w = try fixturePage(legacy), file = w.str("file")!
    var old = w; old.removeValue(forKey: "hash")
    try Data((old.line + "\n").utf8).write(to: legacy.url.appendingPathComponent("transcript.jsonl"))
    try Data("Outside legacy".utf8).write(to: legacy.pagesURL.appendingPathComponent(file))
    expect(try NotebookStore.open(url: legacy.url).transcript.count == 1)
    expect(!legacy.isUndoable(old))
}
func verificationAtomicUndoAndNewPageCutoff() throws {
    let s = try tempStore(), p = try fixturePage(s).str("file")!
    let bytes = try Data(contentsOf: s.pagesURL.appendingPathComponent(p))
    let revision = try s.writePage(title: "P", content: "Second", revising: p, session: "s-1", toolUseID: "r")
    expect(FileManager.default.fileExists(atPath: s.pagesURL.appendingPathComponent(p).path))
    let preUndo = try Data(contentsOf: s.pagesURL.appendingPathComponent(p))
    expect(preUndo != bytes && revision.str("hash") == s.pageHash(p))
    expect(try Data(contentsOf: s.pagesURL.appendingPathComponent(NotebookStore.previousName(p))) == bytes)
    try s.undoPageWrite(revision.str("id")!, session: "s-1")
    expect(try Data(contentsOf: s.pagesURL.appendingPathComponent(p)) == bytes)
    expect(s.transcript.last?.str("hash") == s.pageHash(p) && !s.hasPreviousVersion(p))
    let newStore = try tempStore(), w = try fixturePage(newStore), f = w.str("file")!
    try Data("{\"chapters\":[],\"unfiled\":[]}".utf8).write(to: newStore.url.appendingPathComponent("notebook.json"))
    let cut = try NotebookStore.open(url: newStore.url)
    expect(cut.pageFiles == [f] && cut.isUndoable(w))
    try FileManager.default.removeItem(at: cut.pagesURL.appendingPathComponent(f))
    let gone = try NotebookStore.open(url: cut.url)
    expect(gone.transcript.count == 1 && !gone.isUndoable(w))
}
func verificationUnknownRecoveryPreservesOutsideBytes() throws {
    let s = try tempStore(), first = try fixturePage(s, "Ambiguous", body: "Recorded"), file = first.str("file")!
    let page = s.pagesURL.appendingPathComponent(file)
    let previous = s.pagesURL.appendingPathComponent(NotebookStore.previousName(file))
    let recorded = try Data(contentsOf: page)
    try FileManager.default.copyItem(at: page, to: previous) // Copy succeeded, write never happened.
    let outside = recorded + Data("\nOutside wording\n".utf8)
    try outside.write(to: page, options: .atomic)
    let opened = try NotebookStore.open(url: s.url)
    let unknown = opened.transcript.last!
    expect(unknown["recovered"] == .bool(true) && !opened.isUndoable(unknown))
    expectThrows { try opened.undoPageWrite(unknown.str("id")!, session: "s-2") }
    expect(try Data(contentsOf: page) == outside)
    expect(try Data(contentsOf: previous) == recorded)
    expect(opened.readPreviousVersion(file)?.body.contains("Recorded") == true)
    let reopened = try NotebookStore.open(url: s.url)
    expect(reopened.transcript.count == opened.transcript.count && !reopened.isUndoable(unknown))
    // Old recovered markers receive the same non-destructive treatment on reopen.
    expectThrows { try reopened.undoPageWrite(unknown.str("id")!, session: "s-3") }
    expect(try Data(contentsOf: page) == outside)
    let value = reopened.readPage(file)!
    let same = try reopened.writePage(title: value.title, content: String(value.body.dropLast()), revising: file,
                                     session: "s-3", toolUseID: "same-unknown")
    expect(same["unchanged"] == .bool(true) && !reopened.isUndoable(same))
    expect(try Data(contentsOf: page) == outside)
    expect(try Data(contentsOf: previous) == recorded)
}

func verificationNoOpRevisionCannotClaimOutsideEdits() throws {
    let s = try tempStore(), first = try fixturePage(s, "No-op", body: "Earlier bytes"), file = first.str("file")!
    let current = s.url.appendingPathComponent("pages").appendingPathComponent(file)
    let priorRevision = try s.writePage(title: "No-op", content: "Same bytes", revising: file, session: "s-1", toolUseID: "revision")
    let previousFile = s.url.appendingPathComponent("pages").appendingPathComponent(NotebookStore.previousName(file))
    let previousBytes = try Data(contentsOf: previousFile)
    expect(s.isUndoable(priorRevision))
    let unchangedBytes = try Data(contentsOf: current)
    let same = try s.writePage(title: "No-op", content: "Same bytes", revising: file, session: "s-1", toolUseID: "same")
    expect(same["unchanged"] == .bool(true) && s.hasPreviousVersion(file))
    expect(try Data(contentsOf: previousFile) == previousBytes)
    expect(!Prompts.turnPrefix(s, thread: file).contains("Unchanged"))
    expectThrows { try s.undoPageWrite(same.str("id")!, session: "s-2") }
    let afterNoOp = try Data(contentsOf: current)
    expect(!s.isUndoable(same) && !s.isUndoable(priorRevision) && !s.isUndoable(first) && afterNoOp == unchangedBytes)
    let outside = unchangedBytes + Data("\nOutside wording\n".utf8)
    try outside.write(to: current, options: .atomic)
    let opened = try NotebookStore.open(url: s.url)
    expect(!opened.transcript.contains { $0["recovered"] == .bool(true) })
    let afterOpen = try Data(contentsOf: current)
    expect(!opened.isUndoable(same) && afterOpen == outside)

    // A later copy/write cutoff is still indexed, preserving both versions without inferred Undo.
    let interrupted = try tempStore(), initial = try fixturePage(interrupted, "Later cutoff", body: "Before"), p = initial.str("file")!
    _ = try interrupted.writePage(title: "Later cutoff", content: "Before", revising: p, session: "s-1", toolUseID: "same")
    let page = interrupted.url.appendingPathComponent("pages").appendingPathComponent(p)
    let previous = page.deletingPathExtension().appendingPathExtension("previous.md")
    let prior = try Data(contentsOf: page)
    try FileManager.default.copyItem(at: page, to: previous)
    try (prior + Data("\nInterrupted new text\n".utf8)).write(to: page, options: .atomic)
    let recovered = try NotebookStore.open(url: interrupted.url)
    let records = recovered.transcript.filter { $0["recovered"] == .bool(true) }
    expect(records.count == 1 && !recovered.isUndoable(records[0]))
    let unrecorded = try Data(contentsOf: page)
    expectThrows { try recovered.undoPageWrite(records[0].str("id")!, session: "s-2") }
    expect(try Data(contentsOf: page) == unrecorded)
    expect(try Data(contentsOf: previous) == prior)
}

func verificationNeverReuseUndoneFilename() throws {
    let s = try tempStore(), w = try fixturePage(s), p = w.str("file")!
    _ = try message(s, "Keep my words", page: p)
    try s.undoPageWrite(w.str("id")!, session: "s-1")
    let next = try fixturePage(s)
    expect(next.str("file") != p && s.threadEntries(for: p).contains { $0.str("text") == "Keep my words" })
    let file = next.str("file")!
    let revision = try s.writePage(title: "Renamed", content: "Body", revising: file, session: "s-1", toolUseID: "r")
    _ = try s.fileInChapter([file], chapter: "Chapter 1: New home")
    expect(revision.str("file") == file && s.chapter(of: file) != nil)
}
func verificationWindowUsesThroughPosition() throws {
    let s = try tempStore(), p = "p.md", q = "q.md"
    for i in 0..<9 {
        _ = try message(s, "P old \(i)", page: p, role: i % 2 == 0 ? "person" : "sophia")
        _ = try s.appendTranscript(["role": .string("person"), "purpose": .string("release_edit"), "page": .string(p)])
    }
    let through = s.transcript.last(where: NotebookStore.isMessage)!.str("id")!
    let later = try message(s, "During checkpoint", page: p)
    _ = try message(s, "Foreign words", page: q)
    _ = try s.appendTranscript(["purpose": .string("checkpoint"), "through": .string(through)])
    let outgoing = try message(s, "Outgoing only once", page: p)
    expect(s.carried(for: p, before: outgoing.str("id")).count == 6)
    expect(s.window(for: p, before: outgoing.str("id")).contains { $0.str("id") == later.str("id") })
    let context = Prompts.context(s, thread: p, before: outgoing.str("id"))
    expect(context.contains("During checkpoint") && !context.contains("Foreign words") && !context.contains("Outgoing only once"))
    _ = try s.appendTranscript(["purpose": .string("clear"), "page": .string(p)])
    expect(s.carried(for: p).isEmpty && s.window(for: p).isEmpty)
    // Q queued before P finished and before its checkpoint entry: dispatch sees current storage.
    let queued = try message(s, "Queued question", page: q)
    let late = try message(s, "Saved while Q waited", page: q, role: "sophia")
    _ = try s.appendTranscript(["purpose": .string("checkpoint"), "through": .string(through)])
    let rebuilt = Prompts.context(s, thread: q, before: queued.str("id"))
    expect(rebuilt.contains(late.str("text")!) && !rebuilt.contains("Queued question"))

    // A separate briefing process stops before the ordinary reply is rebuilt from storage.
    let returning = try tempStore(), prior = try message(returning, "Earlier Contents question", page: "")
    _ = try returning.appendTranscript(["purpose": .string("checkpoint"), "through": prior["id"]!])
    let offer = "Shall we compare the two filter responses next?"
    _ = try returning.appendTranscript(["role": .string("sophia"), "purpose": .string("briefing"), "page": .string(""), "text": .string(offer)])
    let answer = try message(returning, "Yes, let's do that", page: "")
    let resumed = Prompts.context(returning, thread: "", before: answer.str("id"))
    expect(resumed.contains(offer) && !resumed.contains("Yes, let's do that"))
    expect(!Prompts.context(returning, thread: "p.md").contains(offer))
    _ = try returning.appendTranscript(["purpose": .string("clear"), "page": .string("")])
    expect(!Prompts.context(returning, thread: "").contains(offer))
}
func scenario2PageContextAndBookChanges() throws {
    let s = try tempStore(), p = try fixturePage(s, "P", body: "Page P body").str("file")!, q = try fixturePage(s, "Q", body: "Page Q body").str("file")!
    let origin = try message(s, "Creating question", page: p)
    _ = try message(s, "Creating answer", page: p, role: "sophia")
    let r = try fixturePage(s, "R", thread: p).str("file")!
    _ = try message(s, "Next turn excluded", page: p)
    _ = try s.appendLearning(["kind": .string("question"), "text": .string("Relevant by page"), "refs": .array([.string("p:" + q)])], by: "sophia", session: "s-1")
    _ = try s.appendLearning(["kind": .string("question"), "text": .string("Relevant by quote"), "quote": .object(["entry": origin["id"]!, "text": .string("Creating question")])], by: "sophia", session: "s-1")
    expect(s.notes(for: q).contains { $0.str("text") == "Relevant by page" })
    expect(s.notes(for: p).contains { $0.str("text") == "Relevant by quote" })
    _ = try s.appendLearning(["kind": .string("question"), "text": .string("Relevant by message"), "refs": .array([origin["id"]!])], by: "sophia", session: "s-1")
    expect(s.notes(for: p).contains { $0.str("text") == "Relevant by message" })
    let context = Prompts.context(s, thread: r)
    expect(context.contains("Creating question") && context.contains("Creating answer") && !context.contains("Next turn excluded"))
    _ = try message(s, "Prior Q turn", page: q)
    let range = s.editRanges(of: p).last!
    _ = try s.editPage(file: p, section: range.key, baseHash: range.hash, text: "Person hunk", session: "s-1")
    let revised = try s.writePage(title: "Q", content: "Q changed", revising: q, session: "s-1", toolUseID: "cross", thread: p)
    let prefix = Prompts.turnPrefix(s, thread: q)
    expect(prefix.contains("Person hunk") && prefix.contains(q))
    try s.undoPageWrite(revised.str("id")!, session: "s-1")
    expect(Prompts.turnPrefix(s, thread: q).contains("undo_page"))
    _ = try s.appendTranscript(["role": .string("client"), "tool": .string("write_page"), "recovered": .bool(true), "file": .string(q), "page": .string(q)])
    expect(!Prompts.turnPrefix(s, thread: q).contains("recovered"))
    _ = try s.appendTranscript(["purpose": .string("checkpoint"), "through": origin["id"]!])
    expect(Prompts.context(s, thread: r).contains("Creating question"))
    _ = try s.appendTranscript(["purpose": .string("clear"), "page": .string(r)])
    expect(!s.creatingExchange(for: r).isEmpty && !Prompts.context(s, thread: r).contains("Creating question"))

    // First turn on a never-discussed page starts at through, rather than notebook creation.
    let fresh = try tempStore(), untouched = try fixturePage(fresh, "Never discussed", body: "Base").str("file")!
    let oldRange = fresh.editRanges(of: untouched).last!
    _ = try fresh.editPage(file: untouched, section: oldRange.key, baseHash: oldRange.hash, text: "Old edit", session: "s-1")
    _ = try fresh.writePage(title: "Never discussed", content: "Old edit\nOld revision", revising: untouched, session: "s-1", toolUseID: "old-cross", thread: "")
    let oldThrough = try message(fresh, "Old Contents activity", page: "")
    _ = try fresh.appendTranscript(["purpose": .string("checkpoint"), "through": oldThrough["id"]!])
    let newRange = fresh.editRanges(of: untouched).last!
    _ = try fresh.editPage(file: untouched, section: newRange.key, baseHash: newRange.hash, text: "Fresh edit", session: "s-2")
    _ = try fresh.writePage(title: "Never discussed", content: "Fresh edit\nFresh revision", revising: untouched, session: "s-2", toolUseID: "fresh-cross", thread: "fresh.md")
    _ = try message(fresh, "Fresh foreign activity", page: "fresh.md")
    let queued = try message(fresh, "First question", page: untouched)
    let firstPrefix = Prompts.turnPrefix(fresh, thread: untouched, before: queued.str("id"))
    expect(!firstPrefix.contains("was: Base") && !firstPrefix.contains("active: Contents"))
    expect(firstPrefix.components(separatedBy: "- Edited ").count - 1 == 1)
    expect(firstPrefix.contains("Fresh edit") && firstPrefix.contains("active: fresh.md"))
    expect(firstPrefix.components(separatedBy: "[Sophia app] This page changed:").count - 1 == 1)
    _ = try fresh.appendTranscript(["purpose": .string("clear"), "page": .string(untouched)])
    let clearedRange = fresh.editRanges(of: untouched).last!
    _ = try fresh.editPage(file: untouched, section: clearedRange.key, baseHash: clearedRange.hash, text: "After clear", session: "s-2")
    let afterClear = Prompts.turnPrefix(fresh, thread: untouched)
    expect(afterClear.contains("After clear") && !afterClear.contains("Old edit") && !afterClear.contains("active: fresh.md"))
    expect(afterClear.components(separatedBy: "- Edited ").count - 1 == 1 && !afterClear.contains("This page changed:"))
}
func scenario3GoalAndNoteQuoteOwnership() throws {
    let s = try tempStore(), p = try message(s, "My P goal", page: "p.md")
    _ = try message(s, "Queued Q goal", page: "q.md")
    let goal = try s.writeGoal(text: "Goal", criteria: [], revising: nil, quote: "My P goal", session: "s-1", thread: "p.md")
    expect(goal["refs"]?.array == [p["id"]!] && goal["quote"]?["entry"] == p["id"])
    let noted = s.transcript.filter { $0.str("purpose") == "goal_noted" && $0["record"] == goal["id"] }
    expect(noted.count == 1 && noted[0].str("page") == "p.md" && noted[0].str("session") == "s-1")
    let appCopy = try NotebookStore(url: s.url)
    _ = try message(appCopy, "Reload before tool result", page: "q.md")
    expect(appCopy.transcript.filter { $0.str("purpose") == "goal_noted" && $0["record"] == goal["id"] }.count == 1)
    let note = try s.writeNote(["kind": .string("question"), "text": .string("R starts from P")], quote: "My P goal", revising: nil, session: "s-1", thread: "r.md")
    expect(note.saved?["quote"]?["entry"] == p["id"])
    for i in 1..<NotebookStore.liveNotesPerSession {
        expect(try s.writeNote(["kind": .string("question"), "text": .string("Note \(i)"), "refs": .array([p["id"]!])], quote: nil, revising: nil, session: "s-1", thread: i % 2 == 0 ? "p.md" : "q.md").saved != nil)
    }
    expect(try s.writeNote(["kind": .string("question"), "text": .string("Too many"), "refs": .array([p["id"]!])], quote: nil, revising: nil, session: "s-1", thread: "r.md").saved == nil)
    let quotes = try tempStore()
    let old = try message(quotes, "Same words", page: "p.md", session: "s-1")
    let earlier = try quotes.writeNote(["kind": .string("question"), "text": .string("Earlier quote must be a paraphrase"), "refs": .array([old["id"]!])], quote: "Same words", revising: nil, session: "s-2", thread: "p.md")
    expect(earlier.saved != nil && earlier.saved?["quote"] == nil && earlier.saved?["paraphrase"] == .bool(true))
    let current = try message(quotes, "Same words", page: "q.md", session: "s-2")
    let fallback = try quotes.writeNote(["kind": .string("question"), "text": .string("Same-session fallback")], quote: "Same words", revising: nil, session: "s-2", thread: "p.md")
    expect(fallback.saved?["quote"]?["entry"] == current["id"])
}
func verificationCheckpointValidationBeforeMutation() throws {
    let configStore = try tempStore()
    func engine(readOnly: Bool) -> ClaudeEngine {
        ClaudeEngine(config: .init(claudePath: "/usr/bin/true", toolServerPath: "/unused", notebookURL: configStore.url,
                                  systemPrompt: "", context: "", session: "s-1", readOnly: readOnly))
    }
    func values(_ flag: String, in args: [String]) -> [String] {
        guard let index = args.firstIndex(of: flag) else { return [] }
        return Array(args.dropFirst(index + 1).prefix { !$0.hasPrefix("--") })
    }
    let internalArgs = engine(readOnly: true).arguments, userArgs = engine(readOnly: false).arguments
    let mutations = ["write_page", "set_goal", "set_chapter", "note", "set_memory", "about_you", "link"].map { "mcp__sophia__" + $0 }
    expect(values("--tools", in: internalArgs) == [""])
    expect(values("--allowedTools", in: internalArgs) == ["mcp__sophia__read_page", "mcp__sophia__recall"])
    expect(Set(values("--disallowedTools", in: internalArgs)) == Set(mutations))
    expect(values("--tools", in: userArgs) == ["WebSearch"])
    expect(values("--allowedTools", in: userArgs) == ["mcp__sophia__read_page", "mcp__sophia__write_page", "mcp__sophia__set_goal", "mcp__sophia__set_chapter", "mcp__sophia__note", "mcp__sophia__set_memory", "mcp__sophia__recall", "mcp__sophia__about_you", "mcp__sophia__link", "WebSearch"])
    expect(!userArgs.contains("--disallowedTools") && internalArgs.contains("--restricted") && internalArgs.contains("--strict-mcp-config"))
    let s = try tempStore(), m = try message(s, "Evidence", page: "p.md"), id = m.str("id")!
    _ = try s.setMemory([.init(id: nil, text: "Existing", refs: [id])], session: "s-1")
    let transcript = s.transcript, learning = s.learning
    for text in ["bad JSON", "42", "\"text\"", "{}", "{\"notes\":{}}", "{\"notes\":[],\"memory\":42}", "{\"notes\":[{\"kind\":\"question\",\"text\":\"No evidence\"}],\"memory\":[]}"] {
        expect(try s.finishCheckpoint(text, failed: false, through: id, entries: [id], session: "s-2", catchUp: false) == .failed)
        expect(s.transcript == transcript && s.learning == learning)
    }
    expect(try s.finishCheckpoint("{\"notes\":[]}", failed: true, through: id, entries: [id], session: "s-2", catchUp: false) == .failed)
    expect(s.transcript == transcript && s.learning == learning)
    expect(try s.finishCheckpoint("{\"notes\":[]}", failed: false, through: id, entries: [id], session: "s-2", catchUp: false) == .saved)
    expect(s.unnotedMessages.isEmpty && s.transcript.last?.str("through") == id && s.learning == learning)
    let first = try s.appendLearning(["kind": .string("question"), "text": .string("Original historical note"), "refs": .array([.string(id)])], by: "sophia", session: "s-3")
    _ = try s.appendLearning(["kind": .string("question"), "text": .string("Replacement historical note"), "replaces": first["id"]!, "refs": .array([.string(id)])], by: "sophia", session: "s-4")
    let prompt = Prompts.checkpoint(s, messages: [m], catchUp: true)
    expect(prompt.contains("Original historical note") && prompt.contains("Replacement historical note") && prompt.contains("[page: p.md]"))
    expect(!Prompts.briefing(s).contains("Original historical note"))
}
func scenario10TornTranscriptAppend() throws {
    let s = try tempStore()
    try Data("{\"role\":\"person\",\"text\":".utf8).write(to: s.url.appendingPathComponent("transcript.jsonl"))
    _ = try message(s, "Intact", page: "p.md")
    let lines = try String(contentsOf: s.url.appendingPathComponent("transcript.jsonl"), encoding: .utf8).split(separator: "\n")
    expect(lines.count == 2 && JSON.parse(String(lines[1]))?["text"] == .string("Intact"))
    expect(try NotebookStore(url: s.url).transcript.count == 1)
}
func scenario10IntentionalEngineExit() throws {
    let s = try tempStore()
    let fixture = s.url.appendingPathComponent("exit-fixture")
    let launched = s.url.appendingPathComponent("launched")
    let script = "#!/bin/sh\ncase \" $* \" in *\" auth status \"*) printf '%s' '{\"loggedIn\":true,\"authMethod\":\"claude.ai\",\"apiProvider\":\"firstParty\"}'; exit 0;; esac\nread -r line\nprintf launched > '" + launched.path + "'\nsleep 0.2\nexit 0\n"

    try script.write(to: fixture, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: fixture.path)
    for requested in [false, true] {
        let engine = ClaudeEngine(config: .init(claudePath: fixture.path, toolServerPath: "/unused", notebookURL: s.url, systemPrompt: "", context: "", session: "s-1", page: "p.md"))
        let args = engine.arguments
        expect(!args.contains("--resume"))
        if let index = args.firstIndex(of: "--mcp-config"), let mcp = JSON.parse(args[index + 1]) {
            expect(mcp["mcpServers"]?["sophia"]?["args"]?.array == [.string(s.url.path), .string("s-1"), .string("p.md")])
        } else { expect(false) }
        var observed: Bool?
        engine.onEvent = { event in if case .exited(_, _, let stopped) = event { observed = stopped } }
        try engine.start(); engine.send("Synthetic exit fixture")
        if requested {
            let launchedDeadline = Date().addingTimeInterval(3)
            while !FileManager.default.fileExists(atPath: launched.path) && Date() < launchedDeadline { _ = RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.01)) }
            expect(engine.process?.isRunning == true)
            engine.stop()
        }
        let deadline = Date().addingTimeInterval(5)
        while observed == nil && Date() < deadline { _ = RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.02)) }
        expect(observed == requested)
        try? FileManager.default.removeItem(at: launched)
    }
}

let all: [(String, () throws -> Void)] = [
    ("controlledProtocolFailuresKeepTheirActualOutcome", controlledProtocolFailuresKeepTheirActualOutcome),
    ("shutdownInterruptionKeepsSavedRetryButExplicitStopDoesNot", shutdownInterruptionKeepsSavedRetryButExplicitStopDoesNot),
    ("cancelledEngineDropsLateOutputAndRetiresSourceBridge", cancelledEngineDropsLateOutputAndRetiresSourceBridge),
    ("ownedProcessCleanupPreservesGraceAndStopsKnownChildren", ownedProcessCleanupPreservesGraceAndStopsKnownChildren),
    ("ownedProcessSignalsRequireMatchingBirthIdentity", ownedProcessSignalsRequireMatchingBirthIdentity),
    ("providerRouteFailureRetainsRecoveryBytesWithoutRepeatedMessages", providerRouteFailureRetainsRecoveryBytesWithoutRepeatedMessages),
    ("wholeNotebookCopyPreservesBytesEvidenceAndContinuedWrites", wholeNotebookCopyPreservesBytesEvidenceAndContinuedWrites),
    ("wholeLibraryCopyIncludesSharedBackgroundAndLinks", wholeLibraryCopyIncludesSharedBackgroundAndLinks),
    ("providerRouteGuardWithholdsEveryDeniedOrFailedStatus", providerRouteGuardWithholdsEveryDeniedOrFailedStatus),
    ("providerRouteGuardAllowsOnceWithIdenticalProcessContext", providerRouteGuardAllowsOnceWithIdenticalProcessContext),
    ("providerRouteGuardRechecksReusedAndInternalRequests", providerRouteGuardRechecksReusedAndInternalRequests),
    ("providerRouteGuardCannotFlushAfterStopOrCancel", providerRouteGuardCannotFlushAfterStopOrCancel),
    ("providerRouteGuardRetainsSavedRetryAndFailedCheckpointEvidence", providerRouteGuardRetainsSavedRetryAndFailedCheckpointEvidence),
    ("providerRouteGuardDoesNotStrandBufferedRequestFailure", providerRouteGuardDoesNotStrandBufferedRequestFailure),
    ("localConnectionStatusIsAllowlistedAndRouteSpecific", localConnectionStatusIsAllowlistedAndRouteSpecific),
    ("localConnectionProcessIsBoundedAndScrubbed", localConnectionProcessIsBoundedAndScrubbed),
    ("droppingAReviewedRevisionPreservesCriteriaAndRejectsStaleActions", droppingAReviewedRevisionPreservesCriteriaAndRejectsStaleActions),
    ("evidenceReferencesRevealActualLocalMaterialWithoutWrites", evidenceReferencesRevealActualLocalMaterialWithoutWrites),
    ("evidenceReferencesDistinguishOriginalInterpretationAndCorrection", evidenceReferencesDistinguishOriginalInterpretationAndCorrection),
    ("unavailableEvidenceCannotBecomeAnArbitraryPageOrCriterion", unavailableEvidenceCannotBecomeAnArbitraryPageOrCriterion),
    ("failedSourcesAreNotReintroducedAsExtractedPassages", failedSourcesAreNotReintroducedAsExtractedPassages),
    ("deletedCriterionEvidenceCannotBeRetargetedBeforeUndo", deletedCriterionEvidenceCannotBeRetargetedBeforeUndo),
    ("decliningReferencedCriteriaCannotRetargetTheirEvidence", decliningReferencedCriteriaCannotRetargetTheirEvidence),
    ("goalConfirmationKeepsAllReviewedCriteriaAndProvenance", goalConfirmationKeepsAllReviewedCriteriaAndProvenance),
    ("staleGoalDecisionsRefuseWithoutMutation", staleGoalDecisionsRefuseWithoutMutation),
    ("wholeGoalDeclinePreservesEarlierScopeAndEvidencePositions", wholeGoalDeclinePreservesEarlierScopeAndEvidencePositions),
    ("legacyDeletionReservesIDsBeforeAnyNewAppend", legacyDeletionReservesIDsBeforeAnyNewAppend),
    ("legacyDuplicateMemoryRefusesUpdateWithoutAWrite", legacyDuplicateMemoryRefusesUpdateWithoutAWrite),
    ("aFailedLearningAppendKeepsExistingEvidence", aFailedLearningAppendKeepsExistingEvidence),
    ("learningIdentitiesSurviveDeletionCorrectionAndUndo", learningIdentitiesSurviveDeletionCorrectionAndUndo),
    ("legacyLearningReferencesReserveIDsAndRestoreRefusesCollisions", legacyLearningReferencesReserveIDsAndRestoreRefusesCollisions),
    ("sourcePermissionsAreExplicitMatchedAndTemporary", sourcePermissionsAreExplicitMatchedAndTemporary),
    ("sourceToolsContextAndExtractedEvidenceAgree", sourceToolsContextAndExtractedEvidenceAgree),
    ("researchOffersMatchTheExposedWebCapability", researchOffersMatchTheExposedWebCapability),
    ("editedCorrectionsKeepOriginalEvidenceAndReachNextTurn", editedCorrectionsKeepOriginalEvidenceAndReachNextTurn),
    ("personCorrectionsReachFreshAndOngoingThreadContext", personCorrectionsReachFreshAndOngoingThreadContext),
    ("savedQuestionsRemainRetryableUntilCompletedStoppedOrCleared", savedQuestionsRemainRetryableUntilCompletedStoppedOrCleared),
    ("verificationInterleavedThreadOwnership", verificationInterleavedThreadOwnership),
    ("verificationUndoAcrossScopesAndReopen", verificationUndoAcrossScopesAndReopen),
    ("verificationLatestReleaseAndOneWayUndo", verificationLatestReleaseAndOneWayUndo),
    ("verificationRecoveredRevisionBeforeEntry", verificationRecoveredRevisionBeforeEntry),
    ("verificationRecoveredNewPageBeforeUnfiled", verificationRecoveredNewPageBeforeUnfiled),
    ("verificationExternalAndCopyOnlyChanges", verificationExternalAndCopyOnlyChanges),
    ("verificationAtomicUndoAndNewPageCutoff", verificationAtomicUndoAndNewPageCutoff),
    ("verificationUnknownRecoveryPreservesOutsideBytes", verificationUnknownRecoveryPreservesOutsideBytes),
    ("verificationNoOpRevisionCannotClaimOutsideEdits", verificationNoOpRevisionCannotClaimOutsideEdits),
    ("verificationNeverReuseUndoneFilename", verificationNeverReuseUndoneFilename),
    ("verificationWindowUsesThroughPosition", verificationWindowUsesThroughPosition),
    ("scenario2PageContextAndBookChanges", scenario2PageContextAndBookChanges),
    ("scenario3GoalAndNoteQuoteOwnership", scenario3GoalAndNoteQuoteOwnership),
    ("verificationCheckpointValidationBeforeMutation", verificationCheckpointValidationBeforeMutation),
    ("scenario10TornTranscriptAppend", scenario10TornTranscriptAppend),
    ("scenario10IntentionalEngineExit", scenario10IntentionalEngineExit),

    ("createdAndEnumeratedNotebooksHaveTheSameURL", createdAndEnumeratedNotebooksHaveTheSameURL),
    ("keepsVerifiedQuoteAndStampsNothingFromSophia", keepsVerifiedQuoteAndStampsNothingFromSophia),
    ("misquoteBecomesParaphrase", misquoteBecomesParaphrase),
    ("quoteFromAnEarlierSessionIsRemoved", quoteFromAnEarlierSessionIsRemoved),
    ("rejectsDisallowedKindsAndEvidenceFreeRecords", rejectsDisallowedKindsAndEvidenceFreeRecords),
    ("readMustRestOnAnAttemptNotAPage", readMustRestOnAnAttemptNotAPage),
    ("briefingCannotQuoteButCanCite", briefingCannotQuoteButCanCite),
    ("sophiaWritesAPageDirectlyAndUndoRemovesIt", sophiaWritesAPageDirectlyAndUndoRemovesIt),
    ("revisionKeepsThePreviousVersionAndUndoRestoresIt", revisionKeepsThePreviousVersionAndUndoRestoresIt),
    ("twoWritersDoNotLoseEachOthersWork", twoWritersDoNotLoseEachOthersWork),
    ("undecidedDraftsFromOlderNotebooksBecomePages", undecidedDraftsFromOlderNotebooksBecomePages),
    ("sophiasGoalIsProvisionalUntilConfirmedAndCriteriaOnlyGrow", sophiasGoalIsProvisionalUntilConfirmedAndCriteriaOnlyGrow),
    ("orphanPageIsListedAfterACrash", orphanPageIsListedAfterACrash),
    ("deletingARecordRemovesItsCorrectionsAndUndoRestores", deletingARecordRemovesItsCorrectionsAndUndoRestores),
    ("goalRewordKeepsItsFirstID", goalRewordKeepsItsFirstID),
    ("catchUpCoversEverythingSinceTheLastNotesAcrossSessions", catchUpCoversEverythingSinceTheLastNotesAcrossSessions),
    ("olderCheckpointWithoutThroughCoversWhatCameBefore", olderCheckpointWithoutThroughCoversWhatCameBefore),
    ("onlyALongQuietCountsAsComingBack", onlyALongQuietCountsAsComingBack),
    ("longBriefingIsNotKept", longBriefingIsNotKept),
    ("sectionNumbersAreReadFromTitles", sectionNumbersAreReadFromTitles),
    ("pagesMoveIntoNumberedChaptersInOrder", pagesMoveIntoNumberedChaptersInOrder),
    ("sophiaNotesDuringTheConversationWithinLimits", sophiaNotesDuringTheConversationWithinLimits),
    ("memoryIsRewrittenWholeAndKeepsItsEvidence", memoryIsRewrittenWholeAndKeepsItsEvidence),
    ("recallFindsNotesByIdPageAndWords", recallFindsNotesByIdPageAndWords),
    ("aboutYouIsProvisionalAndStaysHomeUntilConfirmed", aboutYouIsProvisionalAndStaysHomeUntilConfirmed),
    ("linksAreConfirmedBeforeAnythingIsRead", linksAreConfirmedBeforeAnythingIsRead),
    ("checkpointRepliesCarryNotesAndMemory", checkpointRepliesCarryNotesAndMemory),
    ("deepLinksNameASectionThatExists", deepLinksNameASectionThatExists),
    ("aReplyWrittenTwiceIsRecognized", aReplyWrittenTwiceIsRecognized),
    ("extractsJSONFromAFencedReply", extractsJSONFromAFencedReply),
    ("splicingASectionLeavesEveryOtherByteIdentical", splicingASectionLeavesEveryOtherByteIdentical),
    ("aCommitWithNoChangeWritesNothing", aCommitWithNoChangeWritesNothing),
    ("aCommitAgainstAChangedSectionIsRefused", aCommitAgainstAChangedSectionIsRefused),
    ("protectedLinesAndQuotesRefuseSophiasRevision", protectedLinesAndQuotesRefuseSophiasRevision),
    ("anOpenSectionIsRefusedAndOthersAreNot", anOpenSectionIsRefusedAndOthersAreNot),
    ("undoingAPersonEditRestoresThePreviousVersion", undoingAPersonEditRestoresThePreviousVersion),
    ("aReleaseLiftsOnlyThatEdit", aReleaseLiftsOnlyThatEdit),
    ("notationWarningsNameTheirPageAndSection", notationWarningsNameTheirPageAndSection),
    ("pendingStatusQuitCannotLaunchOrLeaveItsOwnedProcess", pendingStatusQuitCannotLaunchOrLeaveItsOwnedProcess)
]
for (name, test) in all {
    current = name
    do { try test(); print("ok   \(name)") } catch { failures += 1; print("FAIL \(name): \(error)") }
}
print(failures == 0 ? "All \(all.count) checks passed." : "\(failures) failure(s).")
exit(failures == 0 ? 0 : 1)
