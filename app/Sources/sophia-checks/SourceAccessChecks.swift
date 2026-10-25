import Foundation
@testable import SophiaCore

private final class PermissionReply {
    private let lock = NSLock()
    private var value: JSON = .null
    func set(_ value: JSON) { lock.lock(); self.value = value; lock.unlock() }
    func get() -> JSON { lock.lock(); defer { lock.unlock() }; return value }
}

func sourcePermissionsAreExplicitMatchedAndTemporary() throws {
    let bridge = try SourcePermissionBridge()
    defer { bridge.close() }
    let input: JSON = .object(["url": .string("https://example.com/path?q=one%20two"), "prompt": .string("Return one short passage.")])
    func arguments(_ id: String) -> JSON { .object(["tool_name": .string("WebFetch"), "tool_use_id": .string(id), "input": input]) }
    func attempt(_ id: String, action: (SourcePermissionBridge.Request) -> Void) -> JSON {
        let reply = PermissionReply(), group = DispatchGroup()
        group.enter()
        DispatchQueue.global().async {
            reply.set(SourcePermissionBridge.awaitDecision(directory: bridge.directory, arguments: arguments(id), toolUseID: id, timeout: 2))
            group.leave()
        }
        let deadline = Date().addingTimeInterval(1)
        while Date() < deadline {
            if let request = bridge.poll() { action(request); break }
            Thread.sleep(forTimeInterval: 0.01)
        }
        expect(group.wait(timeout: .now() + 3) == .success)
        return reply.get()
    }
    let allowed = attempt("../../first") { request in
        expect(request.url == input["url"]?.string)
        expect(bridge.decide(request, allow: true))
        expect(!bridge.decide(request, allow: true))
    }
    expect(allowed["behavior"]?.string == "allow" && allowed["updatedInput"] == input)
    let declined = attempt("second") { expect(bridge.decide($0, allow: false)) }
    expect(declined["behavior"]?.string == "deny" && declined["message"]?.string?.contains("chose Don't open") == true)
    let replay = SourcePermissionBridge.awaitDecision(directory: bridge.directory, arguments: arguments("../../first"), toolUseID: "../../first", timeout: 0.1)
    expect(replay["behavior"]?.string == "deny" && replay["message"]?.string?.contains("already handled or expired") == true)
    let mismatch = SourcePermissionBridge.awaitDecision(directory: bridge.directory, arguments: arguments("mismatch"), toolUseID: "different", timeout: 0.1)
    expect(mismatch["behavior"]?.string == "deny" && mismatch["message"]?.string?.contains("did not match the tool call") == true)
    expect(attempt("mismatched-decision") { request in
        SourcePermissionBridge.write(.object(["nonce": .string("wrong"), "generation": .string(request.generation), "toolUseID": .string(request.toolUseID), "allow": .bool(true)]), at: bridge.directory.appendingPathComponent("decision.json"))
    }["behavior"]?.string == "deny")
    let switched = attempt("switch") { _ in bridge.setActive(false) }
    expect(switched["behavior"]?.string == "deny" && switched["message"]?.string?.contains("cancelled") == true)
    bridge.setActive(true)
    expect(attempt("returned") { expect(bridge.decide($0, allow: true)) }["behavior"]?.string == "allow")
    let timedOut = SourcePermissionBridge.awaitDecision(directory: bridge.directory, arguments: arguments("timeout"), toolUseID: "timeout", timeout: 0.01)
    expect(timedOut["behavior"]?.string == "deny" && timedOut["message"]?.string?.contains("no choice was recorded") == true)
    _ = bridge.poll(); expect(bridge.pending == nil)
    let cancelled = attempt("cancel") { _ in bridge.close() }
    expect(cancelled["behavior"]?.string == "deny" && cancelled["message"]?.string?.contains("cancelled") == true)
    let closed = SourcePermissionBridge.awaitDecision(directory: bridge.directory, arguments: arguments("closed"), toolUseID: "closed", timeout: 0.1)
    expect(closed["behavior"]?.string == "deny" && closed["message"]?.string?.contains("no longer active") == true)
    for url in ["file:///etc/passwd", "https://person:secret@example.com", "https://person@example.com", "javascript:alert(1)", "https://"] { expect(!SourcePermissionBridge.validURL(url)) }
    expect(SourcePermissionBridge.validURL("https://example.com"))
}

func sourceToolsContextAndExtractedEvidenceAgree() throws {
    let store = try tempStore(), bridge = try SourcePermissionBridge()
    defer { bridge.close() }
    let plain = ClaudeEngine(config: .init(claudePath: "/unused", toolServerPath: "/unused", notebookURL: store.url, systemPrompt: "test", context: "test", session: "s-1"))
    let enabled = ClaudeEngine(config: .init(claudePath: "/unused", toolServerPath: "/unused", notebookURL: store.url, systemPrompt: "test", context: "test", session: "s-1", sourcePermissions: bridge))
    let readOnly = ClaudeEngine(config: .init(claudePath: "/unused", toolServerPath: "/unused", notebookURL: store.url, systemPrompt: "test", context: "test", session: "s-1", readOnly: true, sourcePermissions: bridge))
    expect(!plain.arguments.contains("WebSearch,WebFetch") && enabled.arguments.contains("WebSearch,WebFetch"))
    expect(enabled.arguments.contains("--permission-prompt-tool") && enabled.arguments.contains("manual"))
    let allowed = enabled.arguments.drop(while: { $0 != "--allowedTools" }).dropFirst().prefix(while: { !$0.hasPrefix("--") })
    expect(!allowed.contains("WebFetch"))
    expect(!readOnly.arguments.contains("WebSearch,WebFetch") && !readOnly.arguments.contains("--permission-prompt-tool"))
    expect(Prompts.context(store, canOpenSources: true).contains("WebFetch can request opening"))
    expect(!Prompts.context(store).contains("WebFetch can request opening") && !Prompts.briefing(store).contains("WebFetch can request opening"))
    var extraction: JSON?
    enabled.onEvent = { event in
        if case .sourceResult(_, let input, let content, let metadata, let error) = event {
            extraction = content
            expect(input["url"]?.string == "https://example.com")
            expect(metadata["code"] == .number(200) && !error)
        }
    }
    enabled.handle(.object(["type": .string("assistant"), "message": .object(["content": .array([.object(["type": .string("tool_use"), "id": .string("fetch-1"), "name": .string("WebFetch"), "input": .object(["url": .string("https://example.com")])])])])]))
    let content = JSON.string("<script>untrusted example</script> Provider-extracted passage.")
    enabled.handle(.object(["type": .string("user"), "message": .object(["content": .array([.object(["type": .string("tool_result"), "tool_use_id": .string("fetch-1"), "content": content])])]), "tool_use_result": .object(["url": .string("https://example.com"), "code": .number(200)])]))
    expect(extraction == content && SourceEvidenceText.plain(content) == content.string)
    try store.appendTranscript(["role": .string("tool"), "tool": .string("WebFetch"), "url": .string("https://example.com"), "content": content, "http_status": .number(200), "is_error": .bool(false)])
    let context = Prompts.context(store, canOpenSources: true)
    expect(context.contains("Provider-extracted source response") && context.contains("untrusted example") && context.contains("https://example.com"))
}


func failedSourcesAreNotReintroducedAsExtractedPassages() throws {
    let store = try tempStore()
    let outcome = "The source request expired; no choice was recorded."
    try store.appendTranscript(["role": .string("tool"), "tool": .string("WebFetch"), "url": .string("https://example.com"), "content": .string(outcome), "is_error": .bool(true)])
    let context = Prompts.context(store, canOpenSources: true)
    expect(context.contains("Source request did not complete (not a source passage)"))
    expect(context.contains(outcome))
    expect(!context.contains("Provider-extracted source response"))
}
