import Foundation
import SwiftUI

/// App-wide observable state: the API client, the signed-in user, deep links.
@MainActor
final class AppState: ObservableObject {

    @Published var api: APIClient
    @Published private(set) var user: User?
    @Published var isBootstrapping: Bool = true
    @Published var bootstrapError: String?
    @Published var pendingTaskId: Int?

    private let tokenStore: TokenStore

    init(tokenStore: TokenStore = .shared) {
        self.tokenStore = tokenStore
        self.api = APIClient(tokenStore: tokenStore)
    }

    // MARK: - Auth lifecycle

    func bootstrap() async {
        let env = ProcessInfo.processInfo.environment
        // UI-test hook: start each test run from a known, logged-out baseline.
        if env["UITEST_FRESH"] == "1" {
            tokenStore.clear()
            try? await api.resetNetworkMode()
            try? await api.resetDatabase()
        } else if env["UITEST_LOGOUT"] == "1" {
            tokenStore.clear()
        }
        guard let token = tokenStore.token else {
            isBootstrapping = false
            return
        }
        do {
            let me = try await api.me()
            await MainActor.run { self.user = me }
        } catch {
            await MainActor.run {
                self.bootstrapError = (error as? LocalizedError)?.errorDescription
                    ?? "Session expired, please sign in."
                tokenStore.clear()
            }
        }
        await MainActor.run { self.isBootstrapping = false }
    }

    func didAuthenticate(_ token: Token) {
        tokenStore.save(token.accessToken)
        user = token.user
    }

    func logout() {
        tokenStore.clear()
        user = nil
    }

    var isLoggedIn: Bool { tokenStore.token != nil && user != nil }

    // MARK: - Deep links (taskflow://task/{id})

    func handleDeepLink(_ url: URL) {
        guard url.scheme == "taskflow" else { return }
        if url.host == "task" {
            let comps = url.pathComponents.dropFirst() // drop leading "/"
            if let first = comps.first, let id = Int(first) {
                pendingTaskId = id
            }
        }
    }
}
