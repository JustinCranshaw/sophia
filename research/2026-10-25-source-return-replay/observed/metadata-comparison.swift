import Foundation
import SophiaCore
let file = URL(fileURLWithPath: "/tmp/sophia-sop32-current-ui/library/Freedom and citizenship/notebook.json")
var value = try JSONDecoder().decode(JSON.self, from: Data(contentsOf: file)).object!
value["learning_ids"] = .object(["g": .string("3"), "n": .string("39")])
let originalHash = NotebookStore.hash(JSON.object(value).pretty)
print(originalHash)
