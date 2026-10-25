import Foundation
import SophiaCore
let store = try NotebookStore.open(url: URL(fileURLWithPath: "/tmp/sophia-sop32-current-ui/library/Freedom and citizenship", isDirectory: true))
let urls = ["https://cuny.manifoldapp.org/read/black-reconstruction-in-america-toward-a-history-of-the-part-which-black-folk-played-in-the-attempt-to-reconstruct-democracy-in-america-1860-1880/section/aa903055-6ea8-4a69-a130-5195b8a41832", "https://www.ericfoner.com/articles/011321NYer.html"]
let body = "DEVELOPER-SUPPLIED SOURCE CANDIDATES FOR A CONTROLLED REPLAY. These are not learner statements, discovered links, verified quotations, or current availability claims. This fixture does not revise the learner's goals.\n\n" + urls.joined(separator: "\n\n")
let page = try store.writePage(title: "Developer source candidates — controlled replay", content: body, revising: nil, session: "developer-fixture", toolUseID: "developer-fixture").str("file")!
var lines = store.memory.map { NotebookStore.MemoryLine(id: $0.str("id"), text: $0.str("text")!, refs: ($0["refs"]?.array ?? []).compactMap(\.string)) }
precondition(lines.count + urls.count <= NotebookStore.memoryLimit)
lines += urls.map { NotebookStore.MemoryLine(id: nil, text: "DEVELOPER SOURCE CANDIDATE: " + $0, refs: ["p:" + page]) }
let result = try store.setMemory(lines, session: "developer-fixture")
precondition(result.problems.isEmpty)
print(JSON.object(["fixturePage": .string(page), "memoryCount": .number(Double(store.memory.count)), "memoryProblems": .array(result.problems.map(JSON.string))]).pretty)
