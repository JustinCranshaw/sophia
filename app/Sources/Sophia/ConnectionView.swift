import SwiftUI
import SophiaCore

final class ConnectionState: ObservableObject {
    @Published private(set) var acknowledged: Bool
    @Published private(set) var status: ClaudeReadiness
    @Published private(set) var checking = false
    @Published var detailsShown = false
    private let preferences: UserDefaults
    private static let key = "connectionInformationAcknowledged"
    var isStatusFixture: Bool { Self.fixtureStatus != nil }
    private static var fixtureStatus: ClaudeReadiness? {
        #if DEBUG
        guard ProcessInfo.processInfo.environment["SOPHIA_UX_HARNESS"] != nil else { return nil }
        switch ProcessInfo.processInfo.environment["SOPHIA_UX_CONNECTION_STATUS"] {
        case "missing": return .missing
        case "unknown": return .unknown
        case "signed-out": return .signedOut
        default: return nil
        }
        #else
        return nil
        #endif
    }
    init() {
        #if DEBUG
        if let fixture = ProcessInfo.processInfo.environment["SOPHIA_UX_HARNESS"] {
            preferences = UserDefaults(suiteName: "Sophia.ConnectionFixture." + Data(fixture.utf8).base64EncodedString())!
        } else { preferences = .standard }
        #else
        preferences = .standard
        #endif
        acknowledged = preferences.bool(forKey: Self.key)
        status = Self.fixtureStatus ?? (ClaudeEngine.locateClaude() == nil ? .missing : .unchecked)
    }
    func acknowledge() {
        preferences.set(true, forKey: Self.key); acknowledged = true
        // No deferred return, checkpoint or provider request is started here.
    }
    func recheck() {
        guard !checking else { return }
        if let fixture = Self.fixtureStatus { status = fixture; return }
        guard let executable = ClaudeEngine.locateClaude() else { status = .missing; return }
        checking = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent("sophia-status-" + UUID().uuidString)
            let result: ClaudeReadiness
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                defer { try? FileManager.default.removeItem(at: dir) }
                result = ClaudeStatusCheck.run(.init(executable: executable, directory: dir))
            } catch { result = .unknown }
            DispatchQueue.main.async { self?.status = result; self?.checking = false }
        }
    }
}

struct ConnectionView: View {
    @ObservedObject var connection: ConnectionState
    var compact = false
    private var statusText: String {
        switch connection.status {
        case .missing: return "Claude Code not found"
        case .unchecked: return "Claude Code installed · status not checked"
        case .signedOut: return "Claude Code reports signed out"
        case .readyToAttempt: return "Claude installation/login status ready to attempt a request"
        case .unknown: return "Claude installation/login status could not be verified for this route"
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Connection & data").font(.headline)
            Text("Your notebooks stay on this Mac. No Sophia account is needed. Sophia uses your Claude account through installed Claude Code. Questions, Finish for now, and later returns can send relevant notebook context. Research can search the web; opening a source asks permission.")
                .font(.callout).fixedSize(horizontal: false, vertical: true)
            Text("Claude access and usage are separate from Sophia. Check your Claude plan’s limits and charges.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if !compact {
                Text("About you is personal background shared across your notebooks, not an account. After you dismiss this information, a later return can prepare a briefing or catch-up notes automatically; dismissal itself starts nothing. This development build intends to use your Claude account through Claude Code, excluding API-key and alternate-provider environment overrides. Installation/login status is not a successful request, billing proof, or commercial permission, and does not guarantee every notebook’s effective route.")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            if connection.isStatusFixture { Text("Synthetic status fixture — not this Mac’s login result").font(.caption) }
            Text(connection.checking ? "Checking local Claude status…" : statusText).font(.callout.weight(.medium))
            HStack {
                Button("Recheck local status", action: connection.recheck).disabled(connection.checking)
                Link("Claude Code setup", destination: NotebookSession.setupURL)
                Spacer()
                if compact { Button("Details") { connection.detailsShown = true } }
                Button(connection.acknowledged ? "Close" : "Keep reading") {
                    connection.acknowledge(); connection.detailsShown = false
                }
            }
            Text("Reading and drafts work without a connection. Recheck sends no notebook content. Keep reading starts no request.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.padding(16)
    }
}
