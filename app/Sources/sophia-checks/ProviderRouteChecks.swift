import Foundation
@testable import SophiaCore

/// Disposable fake CLI: status and stream-json protocols only, never an actual provider.
private struct RouteFixture {
    let store: NotebookStore
    let executable: URL
    let control: URL
    let events: URL
    let inputs: URL
    static let ready: JSONObject = ["loggedIn": .bool(true), "authMethod": .string("claude.ai"), "apiProvider": .string("firstParty")]
    init() throws {
        store = try tempStore()
        executable = store.url.appendingPathComponent("fake-claude")
        control = store.url.appendingPathComponent("fixture-control.json")
        events = store.url.appendingPathComponent("fixture-events.jsonl")
        inputs = store.url.appendingPathComponent("fixture-inputs.jsonl")
        let script = """
        #!/usr/bin/python3 -I
        import json, os, sys, time
        from pathlib import Path
        control = Path(\(JSON.string(control.path).line))
        events = Path(\(JSON.string(events.path).line))
        inputs = Path(\(JSON.string(inputs.path).line))
        args = sys.argv[1:]
        mode = 'status' if any(args[i:i+2] == ['auth','status'] for i in range(len(args))) else 'inference'
        previous = [json.loads(s) for s in events.read_text().splitlines()] if events.exists() else []
        count = sum(r['mode'] == 'status' for r in previous)
        def option(name):
            return args[args.index(name)+1] if name in args and args.index(name)+1 < len(args) else None
        settings = json.loads(option('--settings') or '{}')
        event = {'mode':mode, 'cwd':os.getcwd(), 'restricted':'--restricted' in args,
                 'emptySources':option('--setting-sources') == '',
                 'webFetchAsk':settings.get('permissions',{}).get('ask') == ['WebFetch'],
                 'contextSeen':any('AUTH_CONTEXT_SENTINEL' in a for a in args),
                 'credentialEnvironmentPresent':any(k in os.environ for k in ['ANTHROPIC_API_KEY','ANTHROPIC_AUTH_TOKEN','ANTHROPIC_BASE_URL','CLAUDE_CODE_OAUTH_TOKEN']),
                 'appEnvironmentPresent':any(k.startswith('SOPHIA_') for k in os.environ)}
        with events.open('a') as f: f.write(json.dumps(event)+'\\n')
        if mode == 'status':
            c = json.loads(control.read_text())
            delays = c.get('delays', [])
            time.sleep(delays[min(count,len(delays)-1)] if delays else c.get('delay',0))
            statuses = c.get('statuses', [])
            status = statuses[min(count,len(statuses)-1)] if statuses else c.get('status',{})
            raw = c.get('raw', json.dumps(status))
            sys.stdout.write(' '*c.get('padding',0)+raw)
            sys.stdout.flush()
            sys.exit(c.get('exit',0))
        print(json.dumps({'type':'system','subtype':'init','apiKeySource':'none','session_id':'fixture','tools':[],'model':'fixture-not-a-provider'}),flush=True)
        for line in sys.stdin:
            with inputs.open('a') as f: f.write(line)
            print(json.dumps({'type':'assistant','message':{'content':[{'type':'text','text':'Synthetic fixture reply.'}]}}),flush=True)
            print(json.dumps({'type':'result','is_error':False,'session_id':'fixture'}),flush=True)
        """
        try script.write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
        try configure()
    }
    func configure(_ values: JSONObject = [:]) throws {
        var c = values
        if c["status"] == nil { c["status"] = .object(Self.ready) }
        try JSON.object(c).line.write(to: control, atomically: true, encoding: .utf8)
    }
    func records(_ file: URL) -> [JSONObject] {
        ((try? String(contentsOf: file, encoding: .utf8)) ?? "").split(separator: "\n").compactMap { JSON.parse(String($0))?.object }
    }
    func engine(readOnly: Bool = false, permissions: SourcePermissionBridge? = nil) -> ClaudeEngine {
        ClaudeEngine(config: .init(claudePath: executable.path, toolServerPath: "/unused-fixture", notebookURL: store.url,
                                   systemPrompt: "AUTH_SYSTEM_SENTINEL", context: "AUTH_CONTEXT_SENTINEL", session: "s-fixture",
                                   readOnly: readOnly, sourcePermissions: permissions))
    }
}

private func routeWait(_ timeout: TimeInterval = 6, until predicate: () -> Bool) {
    let deadline = Date().addingTimeInterval(timeout)
    while !predicate() && Date() < deadline { _ = RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.01)) }
    expect(predicate())
}
private func routeSettle(_ seconds: TimeInterval) {
    let end = Date().addingTimeInterval(seconds)
    while Date() < end { _ = RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.01)) }
}

func providerRouteGuardWithholdsEveryDeniedOrFailedStatus() throws {
    let denied: [JSONObject] = [
        ["loggedIn": .bool(false)],
        ["loggedIn": .bool(true)],
        ["loggedIn": .number(1), "authMethod": .string("claude.ai"), "apiProvider": .string("firstParty")],
        ["loggedIn": .bool(true), "authMethod": .string("api_key"), "apiProvider": .string("firstParty")],
        ["loggedIn": .bool(true), "authMethod": .string("api_key_helper"), "apiProvider": .string("firstParty")],
        ["loggedIn": .bool(true), "authMethod": .string("oauth_token"), "apiProvider": .string("firstParty")],
        ["loggedIn": .bool(true), "authMethod": .string("third_party"), "apiProvider": .string("bedrock")],
        ["loggedIn": .bool(true), "authMethod": .string("claude.ai"), "apiProvider": .string("vertex")],
        ["loggedIn": .bool(true), "authMethod": .string("claude.ai"), "apiProvider": .string("firstParty"), "apiKeySource": .string("environment")]
    ]
    let cases = denied.map { ["status": JSON.object($0)] } + [["exit": .number(7)], ["raw": .string("not JSON")], ["padding": .number(70_000)], ["delay": .number(6)]]
    for c in cases {
        let f = try RouteFixture(), e = f.engine()
        var blocked = false
        e.onEvent = { if case .routeBlocked = $0 { blocked = true } }
        try f.configure(c)
        try e.start()
        expect(f.records(f.events).isEmpty) // start alone launches neither status nor inference.
        let start = Date()
        e.send("AUTH_REQUEST_SENTINEL")
        expect(Date().timeIntervalSince(start) < 0.5)
        routeWait(until: { blocked })
        expect(!e.isRunning && f.records(f.inputs).isEmpty)
        let events = f.records(f.events)
        expect(!events.isEmpty && events.allSatisfy { $0.str("mode") == "status" && $0["contextSeen"] == .bool(false) })
        e.cancel()
    }
}

func providerRouteGuardAllowsOnceWithIdenticalProcessContext() throws {
    let f = try RouteFixture(), permissions = try SourcePermissionBridge(), e = f.engine(permissions: permissions)
    var replies = 0
    e.onEvent = { if case .turnDone = $0 { replies += 1 } }
    try e.start(); e.send("Exact allowed question\nincluding its second line.")
    routeWait(until: { replies == 1 })
    let input = f.records(f.inputs)
    expect(input.count == 1 && input[0]["message"]?["content"] == .string("Exact allowed question\nincluding its second line."))
    let events = f.records(f.events)
    expect(events.map { $0.str("mode") } == ["status", "inference"])
    expect(Set(events.compactMap { $0.str("cwd") }).count == 1)
    expect(events.allSatisfy { $0.str("cwd") == f.store.url.resolvingSymlinksInPath().path && $0["restricted"] == .bool(true) && $0["emptySources"] == .bool(true) && $0["webFetchAsk"] == .bool(true) && $0["credentialEnvironmentPresent"] == .bool(false) && $0["appEnvironmentPresent"] == .bool(false) })
    expect(events[0]["contextSeen"] == .bool(false) && events[1]["contextSeen"] == .bool(true))
    e.cancel(); routeSettle(0.1)
    expect(!FileManager.default.fileExists(atPath: permissions.directory.path))
}

func providerRouteGuardRechecksReusedAndInternalRequests() throws {
    for internalRequest in [false, true] {
        let f = try RouteFixture(), e = f.engine(readOnly: internalRequest)
        var replies = 0, blocked = 0
        e.onEvent = { event in
            if case .turnDone = event { replies += 1 }
            if case .routeBlocked = event { blocked += 1 }
        }
        try e.start(); e.send("First permitted request")
        routeWait(until: { replies == 1 })
        try f.configure(["status": .object(["loggedIn": .bool(false)])])
        e.send("Second request must be withheld")
        routeWait(until: { blocked == 1 })
        expect(f.records(f.inputs).count == 1 && replies == 1 && !e.isRunning)
        expect(f.records(f.events).filter { $0.str("mode") == "status" }.count == 2)
        e.cancel(); routeSettle(0.1)
    }
}

func providerRouteGuardCannotFlushAfterStopOrCancel() throws {
    for cancel in [false, true] {
        let f = try RouteFixture(), permissions = try SourcePermissionBridge(), e = f.engine(permissions: permissions)
        try f.configure(["delay": .number(0.3)])
        var stopped = 0
        e.onEvent = { if case .exited(_, _, true) = $0 { stopped += 1 } }
        try e.start(); e.send("This request is abandoned")
        routeWait(until: { !f.records(f.events).isEmpty })
        if cancel { e.cancel() } else { e.stop() }
        routeSettle(0.7)
        expect(stopped == 1 && !e.isRunning && f.records(f.inputs).isEmpty)
        expect(f.records(f.events).allSatisfy { $0.str("mode") == "status" })
        expect(!FileManager.default.fileExists(atPath: permissions.directory.path))
    }
}

func providerRouteGuardRetainsSavedRetryAndFailedCheckpointEvidence() throws {
    let f = try RouteFixture(), e = f.engine(readOnly: true)
    let q = try f.store.appendTranscript(["role": .string("person"), "page": .string(""), "session": .string("s-1"), "text": .string("The exact saved question.")])
    let before = try Data(contentsOf: f.store.url.appendingPathComponent("transcript.jsonl"))
    var failed = false
    e.onEvent = { if case .routeBlocked = $0 { failed = true } }
    try f.configure(["status": .object(["loggedIn": .bool(false)])])
    try e.start(); e.send("Private checkpoint input must be withheld")
    routeWait(until: { failed })
    _ = try f.store.finishCheckpoint("", failed: true, through: q.str("id")!, entries: Set([q.str("id")!]), session: "s-1", catchUp: false)
    expect(f.store.unnotedMessages.contains { $0["id"] == q["id"] })
    expect(f.store.unansweredQuestion(in: "") == q)
    expect(try Data(contentsOf: f.store.url.appendingPathComponent("transcript.jsonl")) == before)
    try f.configure()
    let retry = f.engine()
    var complete = false
    retry.onEvent = { if case .turnDone = $0 { complete = true } }
    try retry.start(); retry.send(f.store.unansweredQuestion(in: "")!.str("text")!)
    routeWait(until: { complete })
    expect(f.records(f.inputs).count == 1 && f.records(f.inputs)[0]["message"]?["content"] == q["text"])
    expect(f.store.transcript.filter(NotebookStore.isPersonMessage).count == 1 && f.store.pageFiles.isEmpty)
    retry.cancel(); routeSettle(0.1)
}

func providerRouteGuardDoesNotStrandBufferedRequestFailure() throws {
    let f = try RouteFixture(), e = f.engine()
    try f.configure(["statuses": .array([.object(RouteFixture.ready), .object(["loggedIn": .bool(false)])]), "delays": .array([.number(0), .number(0.3)])])
    var blocked = false
    e.onEvent = { if case .routeBlocked = $0 { blocked = true } }
    try e.start(); e.send("First queued payload"); e.send("Second queued payload")
    routeWait(until: { blocked })
    expect(!e.isRunning && f.records(f.events).filter { $0.str("mode") == "status" }.count == 2)
    expect(f.records(f.inputs).count == 1 && f.records(f.inputs)[0]["message"]?["content"] == .string("First queued payload"))
    e.cancel(); routeSettle(0.1)
}
