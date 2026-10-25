import Foundation
import SophiaCore
setbuf(stdout, nil)
let root = URL(fileURLWithPath: "/tmp/sophia-package-probe/library")
let store = try NotebookStore(url: root.appendingPathComponent("Package verification"))
let seed = try store.writePage(title: "Seed for package verification", content: "Synthetic verification material: for a 2 by 2 diagonal matrix diag(2,3), the trace is 5 and determinant is 6.", revising: nil, session: "fixture", toolUseID: "fixture").str("file")!
let runner = LiveRunner(store: store)
func run(_ index: Int, _ text: String) {
    print("BEGIN_TURN \(index)")
    let info = runner.run(session: "package-verify-\(index)", resume: nil, messages: [(text, nil)])
    print("TURN_INFO " + JSON.object(info.mapValues(JSON.string)).line)
    store.reload()
    print("END_TURN \(index) pages=\(store.pageFiles.count) learning=\(store.learning.count)")
}
run(1, "This is a disposable package verification inquiry. Use read_page to inspect \(seed). I want to predict trace and determinant of diagonal 2x2 matrices; please record that as one provisional goal using set_goal, then write one short page titled Package trace practice with a diagonal example and one question. Actually use the available handlers, not a proposed draft. Do not use notes, memory, web or other notebooks. Keep your reply short.")
let written = store.pageFiles.first { $0 != seed }
if let file = written {
    let bytes = try Data(contentsOf: store.pagesURL.appendingPathComponent(file))
    try bytes.write(to: URL(fileURLWithPath: "/tmp/sophia-package-probe/before-revision.md"))
    run(2, "Read the saved page \(file) with read_page, then revise that exact page using write_page to append a clearly labeled Additional verification example: diag(4,5) has trace 9 and determinant 20. Preserve the rest of its content. No other writes, notes, memory or web. Keep the reply short.")
    let previous = try Data(contentsOf: store.pagesURL.appendingPathComponent(String(file.dropLast(3)) + ".previous.md"))
    print("PREVIOUS_BYTES_EXACT \(previous == bytes)")
} else { print("TURN2_NOT_ATTEMPTED no created page") }
run(3, "No writes this turn. Report whether Bash, general file Read, and WebFetch are actually available here; do not search the web or use a workaround for an unavailable tool. Make one read_page request for ../../outside-canary.txt to check the notebook boundary, and explain its actual result without inventing any outside file contents. Do not read any other outside path. This is a controlled harmless boundary probe, not permission to access general files.")
print("COMPLETE")
