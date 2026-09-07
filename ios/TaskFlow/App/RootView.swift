import SwiftUI

/// Decides which top-level screen to show based on auth/bootstrap state.
struct RootView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Group {
            if state.isBootstrapping {
                LaunchView()
            } else if state.isLoggedIn {
                MainTabView()
            } else {
                LoginView()
            }
        }
    }
}

struct LaunchView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("TaskFlow")
                .font(.headline)
                .accessibilityIdentifier("launch.title")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Tab bar: Projects / Notifications / Profile.
struct MainTabView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        TabView {
            ProjectsListView()
                .tabItem { Label("Projects", systemImage: "folder") }
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.circle") }
        }
        // Open a task deep link if pending.
        .sheet(item: Binding(
            get: { state.pendingTaskId.map(TaskLinkIdentifier.init) },
            set: { state.pendingTaskId = $0?.id }
        )) { ident in
            TaskDetailView(taskId: ident.id)
        }
    }
}

/// Identifiable wrapper so a plain Int can drive a `.sheet(item:)`.
struct TaskLinkIdentifier: Identifiable {
    let id: Int
}