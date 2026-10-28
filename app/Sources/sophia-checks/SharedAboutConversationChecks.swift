import Foundation
@testable import SophiaCore

func sharedAboutConversationHasOwnHistoryAndNarrowCapabilities() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("sophia-about-scope-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let ordinary = try NotebookStore(url: root.appendingPathComponent("about"))
    try ordinary.appendTranscript(["role": .string("person"), "text": .string("ORDINARY_NOTEBOOK_PRIVATE_QUOTE"), "session": .string("s")])
    let library = LibraryStore(root: root)
    _ = try library.setAbout(text: "Accepted shared background.", replacing: nil, notebook: nil)
    let shared = try library.ensureSharedAboutPage(session: "s")
    try shared.store.appendTranscript(["role": .string("person"), "page": .string(shared.page.file), "text": .string("OWN_ABOUT_CONVERSATION_WORDS"), "session": .string("s")])
    try shared.store.appendTranscript(["role": .string("sophia"), "page": .string(shared.page.file), "text": .string("OWN_ABOUT_REPLY"), "session": .string("s")])
    _ = try shared.store.proposePageChange(file: shared.page.file, content: "ORDINARY_PENDING_PRIVATE", originNotebook: ordinary.name, evidence: [:], session: "s")
    _ = try shared.store.proposePageChange(file: shared.page.file, content: "OWN_ABOUT_PENDING", originNotebook: ClaudeEngine.sharedAboutOrigin, evidence: [:], session: "s")
    let reopened = try NotebookStore.open(url: shared.store.url)
    let context = Prompts.sharedAboutContext(reopened, libraryRoot: root)
    for text in ["Accepted shared background.", "OWN_ABOUT_CONVERSATION_WORDS", "OWN_ABOUT_REPLY", "OWN_ABOUT_PENDING"] { expect(context.contains(text)) }
    for text in ["ORDINARY_NOTEBOOK_PRIVATE_QUOTE", "ORDINARY_PENDING_PRIVATE", "Other notebooks:", "Your memory for this notebook:"] { expect(!context.contains(text)) }
    expect(shared.store.pendingPageProposals(originNotebook: "about").count == 1)
    expect(shared.store.pendingPageProposals(originNotebook: ClaudeEngine.sharedAboutOrigin).count == 1)
    expect(!Prompts.sharedAboutContext(ordinary, libraryRoot: root).contains("Accepted shared background."))
    let engine = ClaudeEngine(config: .init(claudePath: "/unused", toolServerPath: "/unused", notebookURL: shared.store.url,
        systemPrompt: "", context: context, session: "s", page: shared.page.file, conversationScope: .sharedAbout, libraryRoot: root))
    let arguments = engine.arguments
    let allowed = arguments.drop(while: { $0 != "--allowedTools" }).dropFirst().prefix(while: { !$0.hasPrefix("--") })
    expect(Set(allowed) == Set(["mcp__sophia__read_page", "mcp__sophia__about_you", "WebSearch"]))
    expect(arguments[arguments.firstIndex(of: "--tools")! + 1] == "WebSearch")
    expect(!arguments.contains("--permission-prompt-tool"))
    let mcp = JSON.parse(arguments[arguments.firstIndex(of: "--mcp-config")! + 1])!
    expect(mcp["mcpServers"]?["sophia"]?["args"]?.array?.compactMap(\.string) == [shared.store.url.path, "s", shared.page.file, "--scope", "shared-about", "--library-root", root.path])
    try engine.start(); engine.cancel() // start prepares only; no provider process or send.
    let invalid = ClaudeEngine(config: .init(claudePath: "/unused", toolServerPath: "/unused", notebookURL: ordinary.url,
        systemPrompt: "", context: "", session: "s", page: shared.page.file, conversationScope: .sharedAbout, libraryRoot: root))
    expectThrows { try invalid.start() }
    expect(!invalid.isRunning)
    let proposal = try shared.store.proposePageChange(file: shared.page.file, content: "A changed body", originNotebook: ClaudeEngine.sharedAboutOrigin, evidence: [:], session: "s")
    let range = try shared.store.beginEdit(file: shared.page.file, key: "(page)", session: "s")!
    expectThrows { try shared.store.acceptPageProposal(proposal.str("id")!, session: "s") }
    _ = try shared.store.editPage(file: shared.page.file, section: "(page)", baseHash: range.hash, text: "My personal edit", session: "s")
    shared.store.endEdit()
    expectThrows { try shared.store.acceptPageProposal(proposal.str("id")!, session: "s") }
    expect(shared.store.readPage(shared.page.file)!.body.contains("My personal edit"))
}
