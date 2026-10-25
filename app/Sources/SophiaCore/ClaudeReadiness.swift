import Foundation
import Darwin

/// Local status is not a model/tool test, billing proof or commercial permission.
public enum ClaudeReadiness: Equatable {
    case missing, unchecked, signedOut, readyToAttempt, unknown
    public static func parse(_ data: Data, exitCode: Int32) -> Self {
        struct Status: Decodable {
            let loggedIn: Bool
            let authMethod: String?
            let apiProvider: String?
            let apiKeySource: String?
        }
        guard let s = try? JSONDecoder().decode(Status.self, from: data) else { return .unknown }
        if !s.loggedIn { return .signedOut }
        guard exitCode == 0, s.authMethod == "claude.ai", s.apiProvider == "firstParty",
              s.apiKeySource == nil || s.apiKeySource == "none" else { return .unknown }
        return .readyToAttempt
    }
}

/// Exact executable and isolated process context, reusable by later route checks.
public struct ClaudeStatusConfiguration {
    public let executable: String
    public let directory: URL
    public let environment: [String: String]
    public init(executable: String, directory: URL, environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.executable = executable; self.directory = directory
        var clean = environment
        for key in ClaudeEngine.droppedEnvironment { clean.removeValue(forKey: key) }
        for key in clean.keys where key.hasPrefix("SOPHIA_") { clean.removeValue(forKey: key) }
        clean["PATH"] = (clean["PATH"] ?? "") + ":/usr/bin:/bin:/usr/sbin:/sbin"
        self.environment = clean
    }
}

public enum ClaudeStatusCheck {
    /// Run off the main queue. Raw output is capped, parsed through an allowlist, then discarded.
    public static func run(_ config: ClaudeStatusConfiguration, timeout: TimeInterval = 5) -> ClaudeReadiness {
        let p = Process(), pipe = Pipe()
        p.executableURL = URL(fileURLWithPath: config.executable)
        p.arguments = ["--setting-sources", "", "auth", "status", "--json"]
        p.currentDirectoryURL = config.directory; p.environment = config.environment
        p.standardInput = FileHandle.nullDevice; p.standardOutput = pipe; p.standardError = FileHandle.nullDevice
        let reader = pipe.fileHandleForReading
        defer { try? reader.close(); try? pipe.fileHandleForWriting.close() }
        guard fcntl(reader.fileDescriptor, F_SETFL, O_NONBLOCK) != -1 else { return .unknown }
        do { try p.run() } catch { return .unknown }
        try? pipe.fileHandleForWriting.close()
        var data = Data(), bytes = [UInt8](repeating: 0, count: 4096), failed = false
        let deadline = Date().addingTimeInterval(max(0.01, timeout))
        while true {
            let count = Darwin.read(reader.fileDescriptor, &bytes, bytes.count)
            if count > 0 {
                if data.count + count > 65_536 { failed = true; break }
                data.append(contentsOf: bytes.prefix(count))
            } else if count == 0 { break }
            else if errno != EAGAIN && errno != EWOULDBLOCK { failed = true; break }
            if Date() >= deadline { failed = true; break }
            if count < 0 { usleep(10_000) }
        }
        while p.isRunning && Date() < deadline { usleep(10_000) }
        if p.isRunning {
            failed = true; p.terminate()
            let grace = Date().addingTimeInterval(0.2)
            while p.isRunning && Date() < grace { usleep(10_000) }
            if p.isRunning { Darwin.kill(p.processIdentifier, SIGKILL) }
        }
        p.waitUntilExit()
        return failed ? .unknown : ClaudeReadiness.parse(data, exitCode: p.terminationStatus)
    }
}
