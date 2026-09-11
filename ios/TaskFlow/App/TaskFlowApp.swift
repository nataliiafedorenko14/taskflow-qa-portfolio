import SwiftUI
import UIKit

@main
struct TaskFlowApp: App {
    @StateObject private var state = AppState()
    private let animationsDisabled: Bool

    init() {
        animationsDisabled = ProcessInfo.processInfo.environment["UITEST_DISABLE_ANIMATIONS"] == "1"
        if animationsDisabled {
            UIView.setAnimationsEnabled(false)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .transaction { transaction in
                    if animationsDisabled {
                        transaction.animation = nil
                        transaction.disablesAnimations = true
                    }
                }
                .onAppear { Task { await state.bootstrap() } }
                .onOpenURL { url in state.handleDeepLink(url) }
        }
    }
}
