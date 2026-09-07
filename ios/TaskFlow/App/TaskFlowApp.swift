import SwiftUI

@main
struct TaskFlowApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .onAppear { Task { await state.bootstrap() } }
                .onOpenURL { url in state.handleDeepLink(url) }
        }
    }
}