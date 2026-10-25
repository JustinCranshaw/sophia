import Foundation
@testable import SophiaCore

func localConnectionStatusIsAllowlistedAndRouteSpecific() throws {
    func parsed(_ text: String, _ exit: Int32 = 0) -> ClaudeReadiness { ClaudeReadiness.parse(Data(text.utf8), exitCode: exit) }
    expect(parsed(#"{"loggedIn":true,"authMethod":"claude.ai","apiProvider":"firstParty","email":"do-not-retain@example.invalid","organizationId":"private"}"#) == .readyToAttempt)
    expect(parsed(#"{"loggedIn":false}"#, 1) == .signedOut)
    for text in ["{}", "bad", #"{"loggedIn":1}"#, #"{"loggedIn":true}"#,
                 #"{"loggedIn":true,"authMethod":"api_key","apiProvider":"firstParty"}"#,
                 #"{"loggedIn":true,"authMethod":"claude.ai","apiProvider":"vertex"}"#,
                 #"{"loggedIn":true,"authMethod":"claude.ai","apiProvider":"firstParty","apiKeySource":"environment"}"#] {
        expect(parsed(text) == .unknown)
    }
    expect(parsed(#"{"loggedIn":true,"authMethod":"claude.ai","apiProvider":"firstParty"}"#, 1) == .unknown)
}

func localConnectionProcessIsBoundedAndScrubbed() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("sophia-status-check-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let executable = root.appendingPathComponent("fake-claude")
    expect(ClaudeStatusConfiguration(executable: "/unused", directory: root, environment: [:]).environment["PATH"] == "/usr/bin:/bin:/usr/sbin:/sbin")
    expect(ClaudeStatusConfiguration(executable: "/unused", directory: root, environment: ["PATH": ":/known::"]).environment["PATH"] == "/known:/usr/bin:/bin:/usr/sbin:/sbin")
    func run(_ script: String, timeout: TimeInterval = 1) throws -> ClaudeReadiness {
        try ("#!/bin/sh\n" + script).write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
        return ClaudeStatusCheck.run(.init(executable: executable.path, directory: root,
                                          environment: ["PATH": "/usr/bin:/bin", "ANTHROPIC_API_KEY": "fixture-secret", "SOPHIA_LIBRARY": "private"]), timeout: timeout)
    }
    expect(try run("[ -z \"$ANTHROPIC_API_KEY\" ] && [ -z \"$SOPHIA_LIBRARY\" ] && [ \"$1\" = --restricted ] && [ \"$2\" = --setting-sources ] && [ -z \"$3\" ] && [ \"$4\" = auth ] && [ \"$5\" = status ] && [ \"$6\" = --json ] || exit 2\nprintf '%s' '{\"loggedIn\":true,\"authMethod\":\"claude.ai\",\"apiProvider\":\"firstParty\"}'") == .readyToAttempt)
    expect(try run("printf '%s' '{\"loggedIn\":false}'; exit 1") == .signedOut)
    expect(try run("printf '%s' 'not JSON'; exit 1") == .unknown)
    let ready = #"{"loggedIn":true,"authMethod":"claude.ai","apiProvider":"firstParty"}"#
    func padded(_ size: Int) -> String {
        "printf '%s' '\(ready)'; head -c \(size - ready.utf8.count) /dev/zero | tr '\\000' ' '"
    }
    expect(try run(padded(65_536)) == .readyToAttempt)
    expect(try run(padded(70_000)) == .unknown)
    let start = Date()
    expect(try run("exec sleep 5", timeout: 0.05) == .unknown)
    expect(Date().timeIntervalSince(start) < 2)
    expect(ClaudeStatusCheck.run(.init(executable: root.appendingPathComponent("missing").path, directory: root)) == .unknown)
    let config = ClaudeStatusConfiguration(executable: executable.path, directory: root,
                                          environment: Dictionary(uniqueKeysWithValues: ClaudeEngine.droppedEnvironment.map { ($0, "fixture") }))
    expect(ClaudeEngine.droppedEnvironment.allSatisfy { config.environment[$0] == nil })
    expect(config.executable == executable.path && config.directory == root)
}
