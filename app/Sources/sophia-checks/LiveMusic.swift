import Foundation
import SophiaCore

/// Music notation against real Claude Code: Sophia writes a tune page, then fixes a tune the app
/// reports warnings for. The warning is written as the app would send it; abcjs isn't run here.
/// Usage: swift run sophia-checks --music <empty-dir>
func runMusic(dir: URL) {
    let store = try! NotebookStore(url: dir.appendingPathComponent("Fiddle Tunes"))
    let runner = LiveRunner(store: store)
    func tunes(_ file: String) -> String? { store.readPage(file)?.body }

    _ = runner.run(session: "s-1", resume: nil, messages: [
        ("I'm learning simple melodies on guitar. Could you make a page with the first two phrases of \"Twinkle Twinkle Little Star\" in C, notation with tab under it?", "page")])
    store.reload()
    guard let file = store.contentPages.first?.file, let body = tunes(file) else { print("FAIL: no page written"); return }
    print("\n=== Page \(file)\n\(body)")
    print(body.contains("```abc") ? "ok: abc fence" : "FAIL: no ```abc fence")
    print(body.contains("tablature") ? "ok: tablature option" : "FLAG: no tablature option")

    // Break one line of the tune, as Sophia's own earlier write, and report it the way the app does.
    guard let start = body.range(of: "```abc"), let end = body.range(of: "```", range: start.upperBound..<body.endIndex),
          let line = body[start.upperBound..<end.lowerBound].split(separator: "\n").last(where: { $0.contains("|") }) else {
        print("FAIL: no tune line to break"); return
    }
    let broken = String(line) + " &&&"
    try! store.writePage(title: store.readPage(file)!.title, content: body.replacingOccurrences(of: String(line), with: broken),
                         revising: file, session: "s-1", toolUseID: "planted")
    let warning = MusicWarnings(file: file, page: store.readPage(file)!.title, section: nil, tune: "",
                                warnings: ["Line \(body[..<end.lowerBound].split(separator: "\n").count) of the tune: Unknown character ignored: &&&"])
    let replies = runner.run(session: "s-1", resume: nil,
                             messages: [(Prompts.musicWarnings([warning]) + "Thanks, that's helpful.", "fix")])
    store.reload()
    let fixed = tunes(file) ?? ""
    print("\n=== Reply\n\(replies["fix"] ?? "")")
    print(fixed.contains("&&&") ? "FAIL: the broken line is still there" : "ok: Sophia fixed the tune")
    func tune(_ s: String) -> String? {
        guard let a = s.range(of: "```abc"), let b = s.range(of: "```", range: a.upperBound..<s.endIndex) else { return nil }
        return String(s[a.upperBound..<b.lowerBound])
    }
    print(tune(fixed) == tune(body) ? "ok: the rest of the tune is unchanged" : "FLAG: the fix changed more than the broken line")
    print("Notebook: \(store.url.path)")
}
