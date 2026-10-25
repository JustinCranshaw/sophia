// Compile with Sources/Sophia/AlmanacNotifications.swift; this never constructs an OS client.
import Foundation

private final class ControlledNotifications: AlmanacNotificationClient {
    var status: AlmanacNotificationPermission = .notDetermined
    var requests = 0
    var posts: [String] = []
    var removed: [String] = []
    var grant: ((Bool, Error?) -> Void)?
    var postError: Error?
    func permission(_ completion: @escaping (AlmanacNotificationPermission) -> Void) { completion(status) }
    func requestPermission(_ completion: @escaping (Bool, Error?) -> Void) { requests += 1; grant = completion }
    func post(entryID: String, completion: @escaping (Error?) -> Void) { posts.append(entryID); completion(postError) }
    func removePending(entryID: String) { removed.append(entryID) }
}

@main
struct AlmanacNotificationChecks {
    static func settle() {
        let end = Date().addingTimeInterval(0.03)
        while Date() < end { RunLoop.main.run(mode: .default, before: end) }
    }
    static func main() {
        let suite = "Sophia.AlmanacNotificationChecks." + UUID().uuidString
        let preferences = UserDefaults(suiteName: suite)!
        defer { preferences.removePersistentDomain(forName: suite) }
        let client = ControlledNotifications()
        let model = AlmanacNotifications(preferences: preferences, key: "fixture", client: client)
        settle()
        precondition(!model.enabled && client.requests == 0 && client.posts.isEmpty)
        model.entrySaved(id: "not-opted-in"); settle()
        precondition(client.requests == 0 && client.posts.isEmpty)

        client.status = .denied
        model.enable(); settle()
        precondition(!model.enabled && client.requests == 0 && model.problem != nil)

        client.status = .notDetermined
        model.enable(); model.enable(); settle()
        precondition(client.requests == 1 && model.requesting && client.posts.isEmpty)
        // An outstanding OS prompt must not re-enable after an explicit Disable.
        model.disable(); client.grant?(true, nil); settle()
        precondition(!model.enabled)

        model.enable(); settle()
        client.status = .allowed; client.grant?(true, nil); settle()
        precondition(model.enabled && client.posts.isEmpty)
        model.entrySaved(id: "entry-1"); model.entrySaved(id: "entry-1"); settle()
        precondition(client.posts == ["entry-1"])
        // Reopening the same Library cannot announce the saved entry again.
        let reopened = AlmanacNotifications(preferences: preferences, key: "fixture", client: client)
        settle(); reopened.entrySaved(id: "entry-1"); settle()
        precondition(client.posts == ["entry-1"])

        client.postError = NSError(domain: "ControlledNotificationFailure", code: 1)
        reopened.entrySaved(id: "entry-2"); settle()
        precondition(reopened.problem != nil)
        reopened.entrySaved(id: "entry-2"); settle()
        precondition(client.posts == ["entry-1", "entry-2"])
        reopened.disable(); reopened.entrySaved(id: "entry-3"); settle()
        precondition(client.posts == ["entry-1", "entry-2"] && client.removed == ["entry-2"])
        // Existing permission may change independently; a new save must check it again.
        client.status = .allowed; reopened.enable(); settle()
        client.status = .denied; reopened.entrySaved(id: "entry-4"); settle()
        precondition(client.posts == ["entry-1", "entry-2"] && reopened.permission == .denied)
        print("Almanac controlled notification checks passed; no OS permission or delivery attempted.")
    }
}
