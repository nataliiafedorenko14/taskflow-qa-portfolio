import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var fullName = ""
    @State private var password = ""
    @State private var error: String?
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("register.emailTextField")
                    TextField("Full name", text: $fullName)
                        .accessibilityIdentifier("register.nameTextField")
                    SecureField("Password (min 6)", text: $password)
                        .accessibilityIdentifier("register.passwordTextField")
                }
                if let error {
                    Section { Text(error).foregroundStyle(.red)
                        .accessibilityIdentifier("register.errorLabel") }
                }
                Section {
                    Button(action: register) {
                        if isLoading { ProgressView().tint(.white) } else { Text("Register") }
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .disabled(isLoading || email.isEmpty || password.count < 6)
                    .accessibilityIdentifier("register.submitButton")
                }
            }
            .navigationTitle("Create Account")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }

    private func register() {
        error = nil
        isLoading = true
        Task {
            do {
                let user = try await state.api.register(email: email, password: password, fullName: fullName)
                // Auto-login after registering.
                let token = try await state.api.login(email: email, password: password)
                await MainActor.run {
                    state.didAuthenticate(token)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = (error as? LocalizedError)?.errorDescription ?? "Registration failed"
                    isLoading = false
                }
            }
        }
    }
}