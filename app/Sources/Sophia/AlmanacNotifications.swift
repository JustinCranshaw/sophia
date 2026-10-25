import Foundation
import Combine
import UserNotifications

enum AlmanacNotificationPermission: Equatable {
    case notDetermined, allowed, denied, unavailable
}

/// Injectable so verification never needs to change the person's macOS notification permission.
protocol AlmanacNotificationClient {
    func permission(_ completion: @escaping (AlmanacNotificationPermission) -> Void)
    func requestPermission(_ completion: @escaping (Bool, Error?) -> Void)
    func post(entryID: String, completion: @escaping (Error?) -> Void)
    func removePending(entryID: String)
}

struct SystemAlmanacNotificationClient: AlmanacNotificationClient {
    private var center: UNUserNotificationCenter? { Bundle.main.bundleIdentifier == nil ? nil : .current() }
    func permission(_ completion: @escaping (AlmanacNotificationPermission) -> Void) {
        guard let center else { completion(.unavailable); return }
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined: completion(.notDetermined)
            case .authorized, .provisional: completion(.allowed)
            case .denied: completion(.denied)
            @unknown default: completion(.unavailable)
            }
        }
    }
    func requestPermission(_ completion: @escaping (Bool, Error?) -> Void) {
        guard let center else { completion(false, Self.unbundled); return }
        center.requestAuthorization(options: [.alert], completionHandler: completion)
    }
    func post(entryID: String, completion: @escaping (Error?) -> Void) {
        guard let center else { completion(Self.unbundled); return }
        let content = UNMutableNotificationContent()
        content.title = "Sophia’s Almanac"
        content.body = "A new entry is ready to read."
        // No topic, source notebook title, path, or generated material goes to the lock screen.
        content.userInfo = ["almanacEntryID": entryID]
        center.add(UNNotificationRequest(identifier: Self.identifier(entryID), content: content, trigger: nil), withCompletionHandler: completion)
    }
    func removePending(entryID: String) {
        center?.removePendingNotificationRequests(withIdentifiers: [Self.identifier(entryID)])
    }
    private static func identifier(_ entryID: String) -> String { "Sophia.Almanac." + entryID }
    private static var unbundled: Error { NSError(domain: "Sophia.Almanac", code: 1, userInfo: [NSLocalizedDescriptionKey: "Run the packaged Sophia app to use notifications."]) }
}

/// Notification intent is separate from Almanac generation consent and never enables itself.
/// The caller invokes entrySaved only for the worker's newly verified durable save event.
final class AlmanacNotifications: ObservableObject {
    @Published private(set) var enabled: Bool
    @Published private(set) var permission: AlmanacNotificationPermission = .notDetermined
    @Published private(set) var requesting = false
    @Published private(set) var problem: String?
    private let client: AlmanacNotificationClient
    private let preferences: UserDefaults
    private let enabledKey: String
    private let attemptedKey: String
    private var revision = 0

    init(preferences: UserDefaults, key: String, client: AlmanacNotificationClient = SystemAlmanacNotificationClient()) {
        self.preferences = preferences; self.client = client
        enabledKey = key + ".enabled"; attemptedKey = key + ".lastAttemptedEntry"
        enabled = preferences.bool(forKey: enabledKey)
        refresh()
    }

    func refresh() {
        let token = revision
        client.permission { [weak self] value in
            DispatchQueue.main.async {
                guard let self, self.revision == token else { return }
                self.permission = value
            }
        }
    }

    /// The only path that may ask macOS for permission: an explicit in-app button.
    func enable() {
        guard !requesting else { return }
        revision += 1; let token = revision
        requesting = true; problem = nil
        client.permission { [weak self] status in
            DispatchQueue.main.async {
                guard let self, self.revision == token else { return }
                self.permission = status
                switch status {
                case .allowed: self.finishEnable(true, error: nil, token: token)
                case .notDetermined:
                    self.client.requestPermission { [weak self] granted, error in
                        DispatchQueue.main.async { self?.finishEnable(granted, error: error, token: token) }
                    }
                case .denied:
                    self.finishEnable(false, error: nil, token: token)
                case .unavailable:
                    self.finishEnable(false, error: nil, token: token)
                    self.problem = "Notification permission could not be checked. Entries can still be prepared and read."
                }
            }
        }
    }

    private func finishEnable(_ granted: Bool, error: Error?, token: Int) {
        guard revision == token else { return }
        requesting = false; enabled = granted && error == nil
        preferences.set(enabled, forKey: enabledKey)
        if let error {
            permission = .unavailable
            problem = "Notifications could not be enabled: \(error.localizedDescription) Entries can still be prepared and read."
        } else if granted {
            permission = .allowed
        } else {
            permission = .denied
            problem = "Notifications are off in macOS. Entries can still be prepared and read."
        }
    }

    func disable() {
        revision += 1; requesting = false; enabled = false; problem = nil
        preferences.set(false, forKey: enabledKey)
        if let entry = preferences.string(forKey: attemptedKey) { client.removePending(entryID: entry) }
    }

    func entrySaved(id: String) {
        guard enabled, !id.isEmpty, preferences.string(forKey: attemptedKey) != id else { return }
        let token = revision
        client.permission { [weak self] status in
            DispatchQueue.main.async {
                guard let self, self.enabled, self.revision == token,
                      self.preferences.string(forKey: self.attemptedKey) != id else { return }
                self.permission = status
                guard status == .allowed else { return }
                // Record the attempt first: an error/relaunch must not repeatedly announce one entry.
                self.preferences.set(id, forKey: self.attemptedKey)
                self.client.post(entryID: id) { [weak self] error in
                    DispatchQueue.main.async {
                        guard let self, self.revision == token else { return }
                        if error != nil { self.problem = "The entry was saved, but its notification could not be submitted." }
                    }
                }
            }
        }
    }
}
