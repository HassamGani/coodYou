import SwiftUI

struct EmailSignInView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Email") {
                TextField("UNI@columbia.edu", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.username)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                SecureField("Password", text: $password)
                    .textContentType(.password)
            }

            Section {
                Button {
                    Task { await signIn() }
                } label: {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("Sign in")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(!formIsValid || isLoading)

                Button("Forgot password?") {
                    Task { await sendReset() }
                }
                .disabled(email.isEmpty)
            }
        }
        .navigationTitle("Sign in")
        .alert(item: Binding(
            get: { errorMessage.map(ErrorMessage.init(value:)) },
            set: { errorMessage = $0?.value }
        )) { message in
            Alert(title: Text("Sign in"), message: Text(message.value), dismissButton: .default(Text("OK")))
        }
    }

    private var formIsValid: Bool {
        !email.isEmpty && !password.isEmpty
    }

    private func signIn() async {
        guard formIsValid else { return }
        isLoading = true
        do {
            _ = try await AuthService.shared.signIn(
                withEmail: email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func sendReset() async {
        guard !email.isEmpty else { return }
        do {
            try await AuthService.shared.sendPasswordReset(
                to: email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            )
            errorMessage = "Reset link sent to your campus inbox."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
