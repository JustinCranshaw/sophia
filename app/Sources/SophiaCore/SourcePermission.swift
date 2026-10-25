import Foundation

/// One engine's temporary handshake with Claude Code's WebFetch permission callback.
/// The callback never fetches anything; only the provider's built-in tool can do that.
public final class SourcePermissionBridge {
    public struct Request: Equatable {
        public let nonce: String, generation: String, toolUseID: String, url: String
        public let input: JSON
        var record: JSON { .object(["nonce": .string(nonce), "generation": .string(generation), "toolUseID": .string(toolUseID), "url": .string(url), "input": input]) }
        init?(_ value: JSON) {
            guard let nonce = value["nonce"]?.string, let generation = value["generation"]?.string,
                  let toolUseID = value["toolUseID"]?.string, let url = value["url"]?.string,
                  let input = value["input"], input["url"]?.string == url, SourcePermissionBridge.validURL(url) else { return nil }
            self.nonce = nonce; self.generation = generation; self.toolUseID = toolUseID; self.url = url; self.input = input
        }
    }
    public let directory: URL
    public private(set) var pending: Request?
    private var generation = UUID().uuidString
    private var active = true
    private var closed = false
    private var delivered: Set<String> = []

    public init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("sophia-source-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        writeState()
    }
    deinit { close() }
    public static func validURL(_ text: String) -> Bool {
        guard let u = URLComponents(string: text), ["http", "https"].contains(u.scheme?.lowercased() ?? ""),
              let host = u.host, !host.isEmpty, u.user == nil, u.password == nil else { return false }
        return true
    }
    private func writeState() {
        Self.write(.object(["generation": .string(generation), "active": .bool(active), "closed": .bool(closed)]), at: directory.appendingPathComponent("state.json"))
    }
    public func setActive(_ value: Bool) {
        guard !closed, value != active else { return }
        active = value; generation = UUID().uuidString; pending = nil; writeState()
    }
    public func poll() -> Request? {
        if let pending, Self.read(directory.appendingPathComponent("outcome.json"))?["nonce"]?.string == pending.nonce { self.pending = nil }
        guard !closed, active, let value = Self.read(directory.appendingPathComponent("request.json")),
              let request = Request(value), request.generation == generation, !delivered.contains(request.nonce),
              Self.read(directory.appendingPathComponent("outcome.json"))?["nonce"]?.string != request.nonce else { return nil }
        delivered.insert(request.nonce); pending = request
        return request
    }
    @discardableResult
    public func decide(_ request: Request, allow: Bool) -> Bool {
        guard !closed, active, pending == request, request.generation == generation,
              Self.read(directory.appendingPathComponent("outcome.json"))?["nonce"]?.string != request.nonce else { return false }
        Self.write(.object(["nonce": .string(request.nonce), "generation": .string(generation), "toolUseID": .string(request.toolUseID), "allow": .bool(allow)]), at: directory.appendingPathComponent("decision.json"))
        pending = nil
        return true
    }
    public func close() {
        guard !closed else { return }
        closed = true; active = false; pending = nil; writeState()
        try? FileManager.default.removeItem(at: directory)
    }
    static func read(_ file: URL) -> JSON? {
        guard let data = try? Data(contentsOf: file) else { return nil }
        return try? JSONDecoder().decode(JSON.self, from: data)
    }
    static func write(_ value: JSON, at file: URL) {
        try? Data(value.line.utf8).write(to: file, options: .atomic)
    }
    /// Called only by the approval-only MCP process. Fixed filenames never derive from tool input.
    public static func awaitDecision(directory: URL, arguments: JSON, toolUseID: String, timeout: TimeInterval = 120) -> JSON {
        func deny(_ reason: String) -> JSON {
            .object(["behavior": .string("deny"), "message": .string(reason + " No source content was returned for this request. Do not retry it without a fresh request from the person.")])
        }
        guard arguments["tool_name"]?.string == "WebFetch", !toolUseID.isEmpty,
              arguments["tool_use_id"]?.string == toolUseID,
              let input = arguments["input"], let url = input["url"]?.string, validURL(url) else {
            return deny("The permission callback or source URL was invalid or did not match the tool call.")
        }
        guard let state = read(directory.appendingPathComponent("state.json")), state["active"]?.bool == true, state["closed"]?.bool == false,
              let generation = state["generation"]?.string else { return deny("The source request is no longer active; its conversation or connection ended.") }
        // Reusing a tool-use id is never a second approval request.
        var used = read(directory.appendingPathComponent("used.json"))?.array ?? []
        guard !used.contains(.string(toolUseID)) else { return deny("This source request was already handled or expired; reusing it is not allowed.") }
        used.append(.string(toolUseID)); write(.array(used), at: directory.appendingPathComponent("used.json"))
        let nonce = UUID().uuidString
        defer { write(.object(["nonce": .string(nonce)]), at: directory.appendingPathComponent("outcome.json")) }
        try? FileManager.default.removeItem(at: directory.appendingPathComponent("decision.json"))
        write(.object(["nonce": .string(nonce), "generation": .string(generation), "toolUseID": .string(toolUseID), "url": .string(url), "input": input]), at: directory.appendingPathComponent("request.json"))
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            guard let current = read(directory.appendingPathComponent("state.json")), current["generation"]?.string == generation,
                  current["active"]?.bool == true, current["closed"]?.bool == false else { return deny("The source request was cancelled because its conversation became inactive or the connection ended.") }
            if let decision = read(directory.appendingPathComponent("decision.json")) {
                guard decision["nonce"]?.string == nonce, decision["generation"]?.string == generation,
                      decision["toolUseID"]?.string == toolUseID, let allow = decision["allow"]?.bool else { return deny("The source decision did not match this request; access was refused.") }
                return allow ? .object(["behavior": .string("allow"), "updatedInput": input]) : deny("The person chose Don't open for this source.")
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        return deny("The source request expired while waiting for a decision; no choice was recorded.")
    }
}


public enum SourceEvidenceText {
    public static func plain(_ content: JSON) -> String {
        if let text = content.string { return text }
        if let blocks = content.array { return blocks.compactMap { $0["text"]?.string }.joined(separator: "\n") }
        return content.line
    }
}
