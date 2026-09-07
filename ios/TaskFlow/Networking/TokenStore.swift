import Foundation

/// Persists the auth token (UserDefaults keeps it across app launches, which is
/// what the "data survives relaunch" UI test asserts).
final class TokenStore: ObservableObject {
    static let shared = TokenStore()

    private let key = "taskflow.token"
    @Published private(set) var token: String?

    init() {
        token = UserDefaults.standard.string(forKey: key)
    }

    func save(_ token: String) {
        self.token = token
        UserDefaults.standard.set(token, forKey: key)
    }

    func clear() {
        token = nil
        UserDefaults.standard.removeObject(forKey: key)
    }
}
