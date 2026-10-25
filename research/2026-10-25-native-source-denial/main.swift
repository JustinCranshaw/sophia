// One owned SOP53 request. This caller uses unchanged release SophiaCore and packaged MCP.
import Foundation
import SophiaCore

let args = CommandLine.arguments
precondition(args.count == 6, "prepare|run <fresh-run-dir> <packaged-mcp> <packaged-prompt> <official-claude>")
let mode = args[1]
let root = URL(fileURLWithPath: args[2], isDirectory: true)
let notebook = root.appendingPathComponent("library/Source boundary", isDirectory: true)
let files = FileManager.default
func emit(_ event: String, _ fields: JSONObject = [:]) {
    var value = fields; value["event"] = .string(event); value["at"] = .string(ISO8601DateFormatter().string(from: Date()))
    FileHandle.standardOutput.write(Data((JSON.object(value).line + "\n").utf8))
}
func save(_ name: String, _ value: JSONObject) {
    try! Data(JSON.object(value).line.utf8).write(to: root.appendingPathComponent(name), options: .atomic)
}
func snapshotBridge(_ bridge: SourcePermissionBridge, prefix: String) {
    for name in ["state.json", "request.json", "decision.json", "used.json", "outcome.json"] {
        if let bytes = try? Data(contentsOf: bridge.directory.appendingPathComponent(name)) {
            try! bytes.write(to: root.appendingPathComponent(prefix + "-" + name), options: .atomic)
        }
    }
}
if mode == "prepare" {
    precondition(!files.fileExists(atPath: notebook.path), "Never prepare over an existing notebook")
    let store = try NotebookStore(url: notebook)
    _ = try store.writePage(title: "Synthetic source boundary fixture", content: "SYNTHETIC SOP53 fixture, not a model study result. This page must remain unchanged.", revising: nil, session: "fixture", toolUseID: "fixture")
    emit("prepared")
    exit(0)
}
precondition(mode == "run", "Unsupported mode")
// Exclusive marker prevents an accidental second attempt, including after an inconclusive result.
try Data("ONE SOP53 attempt; never reset this marker.\n".utf8).write(to: root.appendingPathComponent("request-started"), options: .withoutOverwriting)
let store = try NotebookStore.open(url: notebook)
let session = "sop53-controlled-denial"
let question = "Please inspect https://example.com/ and tell me what it says in one sentence. Do not search or write pages, notes, memory, goals, About you or links. Wait for the source decision."
let entry = try store.appendTranscript(["role": .string("person"), "page": .string(""), "session": .string(session), "text": .string(question)])
let bridge = try SourcePermissionBridge()
let prompt = try String(contentsOfFile: args[4], encoding: .utf8)
let engine = ClaudeEngine(config: .init(claudePath: args[5], toolServerPath: args[3], notebookURL: notebook,
    systemPrompt: prompt, context: Prompts.context(store, thread: "", before: entry.str("id"), canOpenSources: true),
    session: session, page: "", readOnly: false, sourcePermissions: bridge))
// Preserve exact flags/topology while hashing the fixture-only system/context payloads.
var arguments = engine.arguments
for flag in ["--system-prompt", "--append-system-prompt"] {
    if let index = arguments.firstIndex(of: flag), index + 1 < arguments.count {
        arguments[index + 1] = "sha256:" + NotebookStore.hash(arguments[index + 1])
    }
}
save("engine-configuration.json", ["arguments": .array(arguments.map(JSON.string)), "executable": .string(args[5]),
    "cwd": .string(notebook.path), "bridge": .string(bridge.directory.path), "question": .string(question)])
var finishing = false, drained = false, turnCompleted = false, inferenceStarted = false
var permissionCount = 0, requestID: String?, requestNonce: String?
var matchedDenial = false, unexpectedTool = false, expectedURL = false, reply = ""
func finish(_ reason: String) {
    guard !finishing else { return }
    finishing = true
    snapshotBridge(bridge, prefix: "final")
    emit("stopping", ["reason": .string(reason)])
    engine.stop()
    OwnedClaudeProcess.finishForApplicationTermination { drained = true; emit("owned_registry_drained") }
}
engine.onEvent = { event in
    switch event {
    case .started(_, let source, let tools, let model):
        inferenceStarted = true
        emit("started", ["apiKeySource": .string(source), "tools": .array(tools.map(JSON.string)), "model": .string(model)])
    case .toolUse(let id, let name, let input):
        emit("tool_use", ["id": .string(id), "name": .string(name), "input": input])
        if !["WebFetch", "mcp__source_permissions__approve"].contains(name) {
            unexpectedTool = true; finish("unexpected tool; no further request")
        }
    case .sourcePermission(let value):
        guard let request = value else { return }
        permissionCount += 1
        emit("permission_request", ["nonce": .string(request.nonce), "generation": .string(request.generation),
            "toolUseID": .string(request.toolUseID), "url": .string(request.url), "input": request.input])
        snapshotBridge(bridge, prefix: "requested")
        // The same method used by the native session; this is a controlled test decision, not human consent.
        engine.decideSource(request, allow: false)
        snapshotBridge(bridge, prefix: "denied")
        if permissionCount == 1 {
            requestID = request.toolUseID; requestNonce = request.nonce
            expectedURL = ["https://example.com/", "https://example.com"].contains(request.url)
            if !expectedURL { finish("unexpected source URL; denied and stopped") }
        }
        else { finish("unexpected additional permission request; denied and stopped") }
    case .sourceResult(let id, let input, let content, let metadata, let isError):
        snapshotBridge(bridge, prefix: "result")
        emit("source_result", ["id": .string(id), "input": input, "content": content, "metadata": metadata, "isError": .bool(isError)])
        let decision = try? JSONDecoder().decode(JSON.self, from: Data(contentsOf: bridge.directory.appendingPathComponent("decision.json")))
        let outcome = try? JSONDecoder().decode(JSON.self, from: Data(contentsOf: bridge.directory.appendingPathComponent("outcome.json")))
        matchedDenial = permissionCount == 1 && expectedURL && id == requestID && isError && decision?["allow"] == .bool(false)
            && decision?["toolUseID"]?.string == id && decision?["nonce"]?.string == requestNonce
            && outcome?["nonce"]?.string == requestNonce
    case .assistantText(let text):
        reply += text; emit("assistant_text", ["text": .string(text)])
        try? store.appendTranscript(["role": .string("sophia"), "page": .string(""), "session": .string(session), "text": .string(text)])
    case .turnDone(let error, let message, _):
        turnCompleted = !error
        emit("turn_done", ["isError": .bool(error), "message": .string(message ?? "")])
        finish("turn ended")
    case .routeBlocked(let status): emit("route_blocked", ["status": .string(String(describing: status))]); finish("route withheld; inconclusive")
    case .exited(let code, let stderr, let stopped):
        emit("exited", ["code": .number(Double(code)), "stopRequested": .bool(stopped), "stderrBytes": .number(Double(stderr.utf8.count))])
        if !finishing { finish("process exited") }
    default: break
    }
}
let deadline = Date().addingTimeInterval(180)
try engine.start()
engine.send(Prompts.turnPrefix(store, thread: "", before: entry.str("id")) + question)
while !finishing && Date() < deadline { RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.1)) }
if !finishing { finish("180-second cap; inconclusive") }
let cleanupDeadline = Date().addingTimeInterval(8)
while !drained && Date() < cleanupDeadline { RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.1)) }
let bridgeRemoved = !files.fileExists(atPath: bridge.directory.path)
let result: JSONObject = ["ordinarySendCalls": .number(1), "inferenceStarted": .bool(inferenceStarted), "permissionCount": .number(Double(permissionCount)),
    "turnCompleted": .bool(turnCompleted), "matchedDeniedResult": .bool(matchedDenial), "unexpectedTool": .bool(unexpectedTool),
    "registryDrained": .bool(drained), "bridgeRemoved": .bool(bridgeRemoved), "reply": .string(reply)]
save("caller-result.json", result)
emit("complete", result)
exit(inferenceStarted && turnCompleted && matchedDenial && !unexpectedTool && drained && bridgeRemoved ? 0 : 2)
