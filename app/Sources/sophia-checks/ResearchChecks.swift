import Foundation
import SophiaCore

func researchOffersMatchTheExposedWebCapability() throws {
    let store = try tempStore()
    let engine = ClaudeEngine(config: .init(claudePath: "/unused/claude", toolServerPath: "/unused/sophia-mcp", notebookURL: store.url, systemPrompt: "test", context: "test", session: "s-1"))
    expect(engine.arguments.contains("WebSearch"))
    expect(!engine.arguments.contains("WebFetch"))
    let context = Prompts.context(store)
    let briefing = Prompts.briefing(store)
    for prompt in [context, briefing] {
        expect(prompt.contains("no tool for opening external web pages"))
        expect(prompt.contains("passages the person supplies here"))
        expect(prompt.contains("available notebook pages with read_page"))
        expect(prompt.contains("search result, summary or remembered quotation is not verified source text"))
        expect(prompt.contains("find openable links"))
    }
    expect(briefing.contains("do not imply external passages are already inspected or ready"))
}
