import Foundation

/// Runs the person's installed, unmodified Claude Code binary in headless mode as Sophia.
/// The person signs in through Claude Code's own login; this class never handles credentials.
/// See spikes/claude-headless/README.md for the flags and what they were shown to do.
public final class ClaudeEngine {
    public enum Event {
        case started(session: String, apiKeySource: String, tools: [String], model: String)
        case textDelta(String)
        case assistantText(String)
        case toolUse(id: String, name: String, input: JSON)
        case toolResult(id: String)
        case sourcePermission(SourcePermissionBridge.Request?)
        case sourceResult(id: String, input: JSON, content: JSON, metadata: JSON, isError: Bool)
        case turnDone(isError: Bool, message: String?, session: String?)
        case routeBlocked(ClaudeReadiness)
        case exited(code: Int32, stderr: String, stopRequested: Bool)
    }

    public struct Config {
        public var claudePath: String
        public var toolServerPath: String
        public var notebookURL: URL
        public var systemPrompt: String
        public var context: String
        public var page: String
        public var session: String
        public var readOnly: Bool
        public var sourcePermissions: SourcePermissionBridge?
        public init(claudePath: String, toolServerPath: String, notebookURL: URL, systemPrompt: String, context: String, session: String, page: String = "", readOnly: Bool = false, sourcePermissions: SourcePermissionBridge? = nil) {
            self.claudePath = claudePath; self.toolServerPath = toolServerPath; self.notebookURL = notebookURL
            self.systemPrompt = systemPrompt; self.context = context; self.page = page; self.session = session; self.readOnly = readOnly; self.sourcePermissions = readOnly ? nil : sourcePermissions
        }
    }

    public var onEvent: (Event) -> Void = { _ in }
    public private(set) var isRunning = false
    public private(set) var stopRequested = false

    let config: Config
    let processConfiguration: ClaudeStatusConfiguration
    private var outgoing: [Data] = []
    private var checkID: UUID?
    var process: Process?
    var stdin: FileHandle?
    var buffer = Data()
    var stderrText = ""
    private var sourceTimer: DispatchSourceTimer?
    private var sourceUses: [String: JSON] = [:]
    public var pendingSource: SourcePermissionBridge.Request? { config.sourcePermissions?.pending }
    public func setSourceAccessActive(_ active: Bool) {
        config.sourcePermissions?.setActive(active)
        onEvent(.sourcePermission(nil))
    }
    public func decideSource(_ request: SourcePermissionBridge.Request, allow: Bool) {
        _ = config.sourcePermissions?.decide(request, allow: allow)
        onEvent(.sourcePermission(nil))
    }
    private func closeSources() {
        sourceTimer?.cancel(); sourceTimer = nil; config.sourcePermissions?.close(); onEvent(.sourcePermission(nil))
    }

    public init(config: Config) {
        self.config = config
        let settings = config.sourcePermissions == nil ? nil : JSON.object(["permissions": .object(["ask": .array([.string("WebFetch")])])]).line
        processConfiguration = ClaudeStatusConfiguration(executable: config.claudePath, directory: config.notebookURL, settings: settings)
    }

    /// A connection failure must not overwrite the only copy of a page-edit recovery draft.
    public static func routeFailureMessage(_ status: ClaudeReadiness, retaining prior: String?) -> String {
        let message = status == .signedOut
            ? "Sign in to Claude Code with your claude.ai account, then choose Retry. This request was not sent."
            : "Sophia couldn't verify the intended claude.ai connection. Check Connection & Data, then choose Retry. This request was not sent."
        guard let prior else { return message }
        return prior.contains(message) ? prior : prior + "\n\n" + message
    }

    /// Credentials and alternate routes that must never reach the child process,
    /// so usage can't silently move from the subscription to separately billed API usage.
    static let droppedEnvironment = ["ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN", "ANTHROPIC_BASE_URL",
                                     "CLAUDE_CODE_USE_BEDROCK", "CLAUDE_CODE_USE_VERTEX", "CLAUDE_CODE_OAUTH_TOKEN",
                                     "CLAUDECODE", "CLAUDE_CODE_ENTRYPOINT", "OPENAI_API_KEY", "CODEX_API_KEY"]

    /// Internal requests may read evidence, but cannot mutate it before validation finishes.
    static let readingTools = ["mcp__sophia__read_page", "mcp__sophia__recall"]
    static let writingTools = ["mcp__sophia__write_page", "mcp__sophia__set_goal", "mcp__sophia__set_chapter", "mcp__sophia__note", "mcp__sophia__set_memory", "mcp__sophia__about_you", "mcp__sophia__link"]

    public var arguments: [String] {
        var servers: JSONObject = ["sophia": .object([
            "command": .string(config.toolServerPath),
            "args": .array([.string(config.notebookURL.path), .string(config.session), .string(config.page)])
        ])]
        if let permissions = config.sourcePermissions {
            servers["source_permissions"] = .object(["command": .string(config.toolServerPath), "args": .array([.string("--source-permissions"), .string(permissions.directory.path)])])
        }
        let mcp = JSON.object(["mcpServers": .object(servers)]).line
        var args = processConfiguration.isolationArguments + ["-p", "--input-format", "stream-json", "--output-format", "stream-json", "--verbose",
                    "--include-partial-messages",
                    "--tools", config.readOnly ? "" : (config.sourcePermissions == nil ? "WebSearch" : "WebSearch,WebFetch"),
                    "--strict-mcp-config", "--mcp-config", mcp,
                    "--allowedTools"]
        if config.readOnly {
            args += Self.readingTools + ["--disallowedTools"] + Self.writingTools
        } else {
            // Preserve the user-turn allowlist and its order.
            args += ["mcp__sophia__read_page", "mcp__sophia__write_page", "mcp__sophia__set_goal", "mcp__sophia__set_chapter", "mcp__sophia__note", "mcp__sophia__set_memory", "mcp__sophia__recall", "mcp__sophia__about_you", "mcp__sophia__link", "WebSearch"]
        }
        if config.sourcePermissions != nil {
            args += ["--permission-prompt-tool", "mcp__source_permissions__approve", "--permission-prompts", "host", "--permission-mode", "manual"]
        }
        args += ["--system-prompt", config.systemPrompt, "--append-system-prompt", config.context]
        return args
    }

    /// Preparing an engine launches nothing. Every send is checked before content delivery.
    public func start() throws {
        guard !isRunning, process == nil else { return }
        stopRequested = false
        isRunning = true
    }

    private func launchProcess() throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: processConfiguration.executable)
        p.arguments = arguments
        p.currentDirectoryURL = processConfiguration.directory
        p.environment = processConfiguration.environment
        let inPipe = Pipe(), outPipe = Pipe(), errPipe = Pipe()
        p.standardInput = inPipe; p.standardOutput = outPipe; p.standardError = errPipe
        outPipe.fileHandleForReading.readabilityHandler = { [weak self] h in
            let data = h.availableData
            DispatchQueue.main.async { [weak self, weak p] in
                guard let self, let p, self.process === p else { return }
                self.consume(data)
            }
        }
        errPipe.fileHandleForReading.readabilityHandler = { [weak self] h in
            let s = String(decoding: h.availableData, as: UTF8.self)
            DispatchQueue.main.async { [weak self, weak p] in
                guard let self, let p, self.process === p else { return }
                self.stderrText += s
            }
        }
        p.terminationHandler = { [weak self] proc in
            DispatchQueue.main.async {
                outPipe.fileHandleForReading.readabilityHandler = nil
                errPipe.fileHandleForReading.readabilityHandler = nil
                guard let self, self.process === proc else { return }
                self.isRunning = false; self.process = nil; self.stdin = nil
                self.checkID = nil; self.outgoing.removeAll()
                self.closeSources()
                self.onEvent(.exited(code: proc.terminationStatus, stderr: self.stderrText, stopRequested: self.stopRequested))
            }
        }
        try p.run()
        process = p
        stdin = inPipe.fileHandleForWriting
        isRunning = true
        if let permissions = config.sourcePermissions {
            let timer = DispatchSource.makeTimerSource(queue: .main)
            timer.schedule(deadline: .now(), repeating: .milliseconds(100))
            timer.setEventHandler { [weak self] in
                guard let self else { return }
                let before = permissions.pending
                _ = permissions.poll()
                if before != permissions.pending { self.onEvent(.sourcePermission(permissions.pending)) }
            }
            sourceTimer = timer; timer.resume()
        }
    }

    public func send(_ text: String) {
        guard isRunning, !stopRequested else { return }
        let msg = JSON.object(["type": .string("user"), "message": .object(["role": .string("user"), "content": .string(text)])]).line
        outgoing.append(Data((msg + "\n").utf8))
        checkNextMessage()
    }

    private func checkNextMessage() {
        guard isRunning, !stopRequested, checkID == nil, !outgoing.isEmpty else { return }
        let id = UUID(), configuration = processConfiguration
        checkID = id
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let status = ClaudeStatusCheck.run(configuration)
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isRunning, !self.stopRequested, self.checkID == id else { return }
                self.checkID = nil
                guard status == .readyToAttempt else { self.fail(.routeBlocked(status)); return }
                do {
                    if self.process == nil { try self.launchProcess() }
                    guard let input = self.stdin, self.process?.isRunning == true else {
                        self.fail(.exited(code: 1, stderr: "Claude Code closed before this request could be delivered.", stopRequested: false)); return
                    }
                    try input.write(contentsOf: self.outgoing[0])
                    self.outgoing.removeFirst()
                    self.checkNextMessage()
                } catch {
                    self.fail(.exited(code: 1, stderr: "Couldn't start or deliver this request to Claude Code.", stopRequested: false))
                }
            }
        }
    }

    private func fail(_ event: Event) {
        checkID = nil; outgoing.removeAll(); isRunning = false
        closeSources()
        try? stdin?.close(); stdin = nil
        let old = process; process = nil
        if old?.isRunning == true { old?.terminate() }
        onEvent(event)
    }

    /// Closes input so Claude Code can finish and save the session, then terminates it if it hasn't exited.
    public func stop() {
        let wasRunning = isRunning
        stopRequested = true; isRunning = false
        checkID = nil; outgoing.removeAll()
        closeSources()
        try? stdin?.close()
        stdin = nil
        guard let p = process, p.isRunning else {
            if wasRunning { onEvent(.exited(code: 0, stderr: "", stopRequested: true)) }
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { if p.isRunning { p.terminate() } }
    }

    /// Ends the current reply immediately.
    public func cancel() {
        let wasRunning = isRunning
        stopRequested = true; isRunning = false
        checkID = nil; outgoing.removeAll()
        closeSources()
        try? stdin?.close()
        stdin = nil
        if process?.isRunning == true { process?.terminate() }
        else if wasRunning { onEvent(.exited(code: 0, stderr: "", stopRequested: true)) }
    }

    func consume(_ data: Data) {
        buffer.append(data)
        while let nl = buffer.firstIndex(of: 0x0A) {
            let line = buffer[buffer.startIndex..<nl]
            buffer.removeSubrange(buffer.startIndex...nl)
            guard let ev = try? JSONDecoder().decode(JSON.self, from: Data(line)) else { continue }
            handle(ev)
        }
    }

    func handle(_ ev: JSON) {
        switch ev["type"]?.string {
        case "system" where ev["subtype"]?.string == "init":
            onEvent(.started(session: ev["session_id"]?.string ?? "",
                             apiKeySource: ev["apiKeySource"]?.string ?? "unknown",
                             tools: (ev["tools"]?.array ?? []).compactMap(\.string),
                             model: ev["model"]?.string ?? ""))
        case "stream_event":
            if let delta = ev["event"]?["delta"], delta["type"]?.string == "text_delta", let t = delta["text"]?.string {
                onEvent(.textDelta(t))
            }
        case "assistant":
            for block in ev["message"]?["content"]?.array ?? [] {
                switch block["type"]?.string {
                case "text": if let t = block["text"]?.string, !t.isEmpty { onEvent(.assistantText(t)) }
                case "tool_use":
                    let id = block["id"]?.string ?? "", name = block["name"]?.string ?? ""
                    if name == "WebFetch", config.sourcePermissions != nil { sourceUses[id] = block["input"] ?? .null }
                    onEvent(.toolUse(id: id, name: name, input: block["input"] ?? .null))
                default: break
                }
            }
        case "user":
            for block in ev["message"]?["content"]?.array ?? [] where block["type"]?.string == "tool_result" {
                if let id = block["tool_use_id"]?.string {
                    if let input = sourceUses.removeValue(forKey: id) {
                        onEvent(.sourceResult(id: id, input: input, content: block["content"] ?? .null, metadata: ev["tool_use_result"] ?? .null, isError: block["is_error"]?.bool ?? false))
                    }
                    onEvent(.toolResult(id: id))
                }
            }
        case "result":
            let isError = ev["is_error"]?.bool ?? false
            onEvent(.turnDone(isError: isError, message: isError ? (ev["result"]?.string ?? ev["subtype"]?.string) : nil,
                              session: ev["session_id"]?.string))
        default:
            break
        }
    }

    /// The official Claude Code binary. Wrappers on PATH (for example terminal integrations)
    /// may add their own settings, so the installer's location is preferred.
    public static func locateClaude() -> String? {
        #if DEBUG
        // Exercise the real missing-install UX without touching the person's installation or login.
        let env = ProcessInfo.processInfo.environment
        if let harness = env["SOPHIA_UX_HARNESS"],
           env["SOPHIA_LIBRARY"]?.hasPrefix(harness + "/") == true,
           env["SOPHIA_UX_NO_CLAUDE"] == "1" { return nil }
        #endif
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [ProcessInfo.processInfo.environment["SOPHIA_CLAUDE"],
                          home + "/.local/bin/claude", home + "/.claude/local/claude",
                          "/opt/homebrew/bin/claude", "/usr/local/bin/claude"].compactMap { $0 }
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}
