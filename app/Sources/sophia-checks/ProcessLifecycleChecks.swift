import Foundation
import Darwin
@testable import SophiaCore

private func lifecycleWait(_ seconds: TimeInterval = 5, until condition: () -> Bool) -> Bool {
    let deadline = Date().addingTimeInterval(seconds)
    while !condition() && Date() < deadline { _ = RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.01)) }
    return condition()
}

func ownedProcessCleanupPreservesGraceAndStopsKnownChildren() throws {
    let store = try tempStore()
    let script = store.url.appendingPathComponent("controlled-process.py")
    try """
    import os,sys,json,time,subprocess,signal
    from pathlib import Path
    folder=Path(sys.argv[1]); mode=sys.argv[2]
    if mode=='graceful':
        sys.stdin.read(); (folder/'graceful').write_text('EOF'); sys.exit(0)
    signal.signal(signal.SIGTERM,signal.SIG_IGN)
    code="import os,time,signal,pathlib; signal.signal(signal.SIGTERM,signal.SIG_IGN); time.sleep(1); pathlib.Path("+repr(str(folder/'child-late'))+").write_text('late'); time.sleep(30)"
    child=subprocess.Popen(['/usr/bin/python3','-I','-c',code],stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    (folder/'owned.json').write_text(json.dumps({'parent':os.getpid(),'child':child.pid}))
    if mode=='early-exit': time.sleep(0.15); sys.exit(0)
    sys.stdin.read()
    if mode=='orphan': sys.exit(0)
    time.sleep(1); (folder/'parent-late').write_text('late'); time.sleep(30)
    """.write(to: script, atomically: true, encoding: .utf8)
    for mode in ["graceful", "ignore", "orphan", "early-exit"] {
        let folder = store.url.appendingPathComponent(mode)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let p = Process(), input = Pipe()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/python3"); p.arguments = ["-I", script.path, folder.path, mode]
        p.standardInput = input; p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        let owned = try OwnedClaudeProcess.launch(p)
        var child: OwnedClaudeProcess.Identity?
        defer { child?.signal(SIGKILL) } // Exact captured fixture identity, even after a failed assertion.
        if mode != "graceful" {
            expect(lifecycleWait { FileManager.default.fileExists(atPath: folder.appendingPathComponent("owned.json").path) })
            let ids = try JSONDecoder().decode(JSON.self, from: Data(contentsOf: folder.appendingPathComponent("owned.json")))
            if case .number(let pid) = ids["child"] { child = OwnedClaudeProcess.Identity.read(pid_t(pid)) }
            expect(child != nil)
        }
        if mode == "early-exit" {
            // No EOF/Stop: the root exits unexpectedly while its known child lives.
            expect(lifecycleWait { !p.isRunning && child?.alive != true })
            try input.fileHandleForWriting.close()
        } else {
            owned.stop(grace: 0.1)
            try input.fileHandleForWriting.close()
            expect(lifecycleWait { !p.isRunning && child?.alive != true })
        }
        if mode == "graceful" { expect(FileManager.default.fileExists(atPath: folder.appendingPathComponent("graceful").path)) }
        else {
            _ = lifecycleWait(1.1) { false }
            expect(!FileManager.default.fileExists(atPath: folder.appendingPathComponent("child-late").path))
            expect(!FileManager.default.fileExists(atPath: folder.appendingPathComponent("parent-late").path))
        }
    }
}

func ownedProcessSignalsRequireMatchingBirthIdentity() throws {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/bin/sleep"); p.arguments = ["5"]
    try p.run()
    defer { if p.isRunning { p.terminate() }; p.waitUntilExit() }
    guard let real = OwnedClaudeProcess.Identity.read(p.processIdentifier) else { expect(false); return }
    let stale = OwnedClaudeProcess.Identity(pid: real.pid, started: real.started + 1, microseconds: real.microseconds, uid: real.uid)
    stale.signal(SIGTERM)
    expect(real.alive && p.isRunning)
}

/// Must run last: models the one-way AppKit Quit gate in this check process.
func pendingStatusQuitCannotLaunchOrLeaveItsOwnedProcess() throws {
    let store = try tempStore(), fixture = try tempStore()
    let executable = fixture.url.appendingPathComponent("fake-claude")
    let marker = fixture.url.appendingPathComponent("status-started"), inference = fixture.url.appendingPathComponent("inference-launched")
    try """
    #!/usr/bin/python3 -I
    import sys,time,signal
    from pathlib import Path
    if 'auth' in sys.argv:
        Path(\(JSON.string(marker.path).line)).write_text('started')
        signal.signal(signal.SIGTERM,signal.SIG_IGN)
        time.sleep(30)
        print('{"loggedIn":true,"authMethod":"claude.ai","apiProvider":"firstParty"}')
    else:
        Path(\(JSON.string(inference.path).line)).write_text(sys.stdin.read())
    """.write(to: executable, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
    let e = ClaudeEngine(config: .init(claudePath: executable.path, toolServerPath: "/unused", notebookURL: store.url, systemPrompt: "PRIVATE_CONTEXT", context: "PRIVATE_CONTEXT", session: "s-1"))
    try e.start(); e.send("PRIVATE_QUESTION")
    expect(lifecycleWait { FileManager.default.fileExists(atPath: marker.path) })
    e.stop()
    var finished = false
    OwnedClaudeProcess.finishForApplicationTermination { finished = true }
    expect(lifecycleWait(5.5) { finished })
    expect(!FileManager.default.fileExists(atPath: inference.path))
    let denied = Process(); denied.executableURL = URL(fileURLWithPath: "/bin/true")
    expectThrows { try OwnedClaudeProcess.launch(denied) }
    expect(!denied.isRunning)
}

func cancelledEngineDropsLateOutputAndRetiresSourceBridge() throws {
    let store = try tempStore(), executable = store.url.appendingPathComponent("fake-claude")
    let late = store.url.appendingPathComponent("late-output")
    try """
    #!/usr/bin/python3 -I
    import sys,time,json,signal
    from pathlib import Path
    if 'auth' in sys.argv:
        print('{"loggedIn":true,"authMethod":"claude.ai","apiProvider":"firstParty"}'); sys.exit(0)
    sys.stdin.readline()
    signal.signal(signal.SIGTERM,signal.SIG_IGN)
    print(json.dumps({'type':'system','subtype':'init','apiKeySource':'none','session_id':'s-fixture','tools':[]}),flush=True)
    print(json.dumps({'type':'stream_event','event':{'delta':{'type':'text_delta','text':'before'}}}),flush=True)
    time.sleep(1)
    Path(\(JSON.string(late.path).line)).write_text('late')
    print(json.dumps({'type':'assistant','message':{'content':[{'type':'text','text':'late'}]}}),flush=True)
    time.sleep(30)
    """.write(to: executable, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
    let bridge = try SourcePermissionBridge()
    let e = ClaudeEngine(config: .init(claudePath: executable.path, toolServerPath: "/unused", notebookURL: store.url, systemPrompt: "fixture", context: "fixture", session: "s-1", sourcePermissions: bridge))
    var texts: [String] = [], stopped = false
    e.onEvent = { event in
        switch event {
        case .textDelta(let text), .assistantText(let text): texts.append(text)
        case .exited(_, _, let requested): stopped = requested
        default: break
        }
    }
    try e.start(); e.send("fixture question")
    expect(lifecycleWait { texts == ["before"] })
    e.cancel()
    e.consume(Data("{\"type\":\"stream_event\",\"event\":{\"delta\":{\"type\":\"text_delta\",\"text\":\"already queued late output\"}}}\n".utf8))
    expect(!FileManager.default.fileExists(atPath: bridge.directory.path))
    expect(lifecycleWait { stopped && e.process == nil })
    _ = lifecycleWait(1.1) { false }
    expect(texts == ["before"] && !FileManager.default.fileExists(atPath: late.path))
}


func shutdownInterruptionKeepsSavedRetryButExplicitStopDoesNot() throws {
    let store = try tempStore()
    let text = "Keep my exact question: cafe\u{301} and ∑."
    let question = try store.appendTranscript(["role": .string("person"), "text": .string(text), "page": .string("")])
    try store.appendTranscript(["role": .string("sophia"), "text": .string("Saved partial explanation"), "page": .string("")])
    try store.appendTranscript(["role": .string("client"), "purpose": .string("interrupted"), "page": .string("")])
    let reopened = try NotebookStore(url: store.url)
    expect(reopened.unansweredQuestion(in: "")?["id"] == question["id"])
    expect(reopened.unansweredQuestion(in: "")?.str("text")?.utf8.elementsEqual(text.utf8) == true)
    expect(reopened.hasPartialReply(to: question))
    expect(reopened.transcript.filter { $0["id"] == question["id"] }.count == 1)
    try reopened.appendTranscript(["role": .string("client"), "purpose": .string("stopped"), "page": .string("")])
    expect(reopened.unansweredQuestion(in: "") == nil)
}

func controlledProtocolFailuresKeepTheirActualOutcome() throws {
    let store = try tempStore()
    for mode in ["malformed-then-valid", "rate-limit", "offline", "unexpected-exit"] {
        let executable = store.url.appendingPathComponent(mode)
        try """
        #!/usr/bin/python3 -I
        import sys,json
        if 'auth' in sys.argv:
            print('{"loggedIn":true,"authMethod":"claude.ai","apiProvider":"firstParty"}'); sys.exit(0)
        sys.stdin.readline()
        mode=\(JSON.string(mode).line)
        if mode=='offline': print('Controlled missing network fixture',file=sys.stderr,flush=True); sys.exit(7)
        if mode=='unexpected-exit': sys.exit(9)
        if mode=='malformed-then-valid': print('not stream JSON',flush=True)
        print(json.dumps({'type':'result','is_error':mode=='rate-limit','result':'Controlled rate limit fixture' if mode=='rate-limit' else ''}),flush=True)
        sys.stdin.read()
        """.write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
        let engine = ClaudeEngine(config: .init(claudePath: executable.path, toolServerPath: "/unused", notebookURL: store.url, systemPrompt: "fixture", context: "fixture", session: "s-1"))
        var result: Bool?, reason: String?, exit: (Int32, String, Bool)?
        engine.onEvent = { event in
            switch event {
            case .turnDone(let error, let message, _): result = error; reason = message
            case .exited(let code, let stderr, let stopped): exit = (code, stderr, stopped)
            default: break
            }
        }
        try engine.start(); engine.send("Controlled failure fixture")
        expect(lifecycleWait { result != nil || exit != nil })
        if mode == "malformed-then-valid" { expect(result == false) }
        if mode == "rate-limit" { expect(result == true && reason == "Controlled rate limit fixture") }
        if mode == "offline" { expect(exit?.0 == 7 && exit?.1.contains("Controlled missing network fixture") == true && exit?.2 == false) }
        if mode == "unexpected-exit" { expect(exit?.0 == 9 && exit?.2 == false) }
        engine.cancel()
    }
}
