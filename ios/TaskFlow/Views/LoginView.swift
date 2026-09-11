import SwiftUI

struct LoginView: View {
    @EnvironmentObject var state: AppState

    @State private var email = "member@test.local"
    @State private var password = ""
    @State private var error: String?
    @State private var isLoading = false
    @State private var showRegister = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("TaskFlow")
                    .font(.largeTitle.bold())
                    .padding(.bottom, 8)

                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("login.emailTextField")

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("login.passwordTextField")

                if let error {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.callout)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("login.errorLabel")
                }

                Button(action: signIn) {
                    if isLoading { ProgressView().tint(.white) } else { Text("Sign In") }
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .disabled(isLoading)
                .accessibilityIdentifier("login.submitButton")

                Button("Create account") { showRegister = true }
                    .accessibilityIdentifier("login.registerButton")

                Spacer()
            }
            .padding()
            .navigationTitle("Sign In")
            .sheet(isPresented: $showRegister) { RegisterView() }
        }
    }

    private func signIn() {
        error = nil
        isLoading = true
        Task {
            do {
                let token = try await state.api.login(email: email, password: password)
                await MainActor.run {
                    state.didAuthenticate(token)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = (error as? LocalizedError)?.errorDescription ?? "Login failed"
                    isLoading = false
                }
            }
        }
    }
}
