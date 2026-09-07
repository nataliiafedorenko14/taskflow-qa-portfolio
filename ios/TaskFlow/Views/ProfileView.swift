import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var state: AppState

    @State private var networkMode: NetworkMode = .normal
    @State private var statusMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                if let user = state.user {
                    Section("Account") {
                        LabeledRow("Name", user.fullName)
                        LabeledRow("Email", user.email)
                        LabeledRow("Role", user.role.label)
                    }
                }
                Section("Session") {
                    Button("Log out", role: .destructive) { state.logout() }
                        .accessibilityIdentifier("profile.logoutButton")
                }
                Section("Developer") {
                    Text("Network mode").font(.headline)
                    ForEach(NetworkMode.allCases) { mode in
                        Button {
                            networkMode = mode
                            applyMode(mode)
                        } label: {
                            HStack {
                                Text(mode.label)
                                Spacer()
                                if networkMode == mode { Image(systemName: "checkmark") }
                            }
                        }
                        .accessibilityIdentifier("profile.networkMode.\(mode.rawValue)")
                    }

                    Button("Reset server database") { resetDB() }
                        .accessibilityIdentifier("profile.resetDBButton")
                }
                if let statusMessage {
                    Section { Text(statusMessage).foregroundStyle(.secondary) }
                }
            }
            .navigationTitle("Profile")
        }
    }

    private func applyMode(_ mode: NetworkMode) {
        Task {
            do {
                if mode == .normal {
                    try await state.api.resetNetworkMode()
                } else {
                    try await state.api.setNetworkMode(mode)
                }
                await MainActor.run { statusMessage = "Network mode: \(mode.label)" }
            } catch {
                await MainActor.run {
                    statusMessage = (error as? LocalizedError)?.errorDescription ?? "Failed"
                }
            }
        }
    }

    private func resetDB() {
        Task {
            do {
                try await state.api.resetDatabase()
                await MainActor.run { statusMessage = "Database reset" }
            } catch {
                await MainActor.run {
                    statusMessage = (error as? LocalizedError)?.errorDescription ?? "Failed"
                }
            }
        }
    }
}

struct LabeledRow: View {
    let label: String
    let value: String
    init(_ label: String, _ value: String) { self.label = label; self.value = value }
    var body: some View {
        HStack { Text(label); Spacer(); Text(value).foregroundStyle(.secondary) }
    }
}