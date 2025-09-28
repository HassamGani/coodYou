import SwiftUI

struct EmailSignInView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        Color.black,
                        Color.black.opacity(0.95),
                        Color.blue.opacity(0.1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Top spacer
                        Spacer()
                            .frame(height: geometry.safeAreaInsets.top + 40)
                        
                        // Header
                        headerSection
                        
                        Spacer()
                            .frame(height: 60)
                        
                        // Form
                        formSection
                        
                        Spacer()
                            .frame(height: 32)
                        
                        // Actions
                        actionSection
                        
                        // Bottom spacer
                        Spacer()
                            .frame(height: geometry.safeAreaInsets.bottom + 40)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .alert(item: Binding(
            get: { errorMessage.map(ErrorMessage.init(value:)) },
            set: { errorMessage = $0?.value }
        )) { message in
            Alert(title: Text("Sign in"), message: Text(message.value), dismissButton: .default(Text("OK")))
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Back button
            HStack {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.white)
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            
            // Title
            VStack(spacing: 12) {
                Text("Welcome back")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Sign in to your CampusDash account")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var formSection: some View {
        VStack(spacing: 24) {
            UberTextField(
                title: "Campus Email",
                placeholder: "UNI@columbia.edu",
                text: $email,
                keyboardType: .emailAddress,
                textContentType: .username,
                autocapitalization: .never,
                disableAutocorrection: true
            )
            
            UberTextField(
                title: "Password",
                placeholder: "Enter your password",
                text: $password,
                isSecure: true,
                textContentType: .password
            )
        }
        .padding(.horizontal, 24)
    }
    
    private var actionSection: some View {
        VStack(spacing: 20) {
            UberButton(
                title: "Sign in",
                isLoading: isLoading,
                isDisabled: !formIsValid || isLoading
            ) {
                Task { await signIn() }
            }
            .padding(.horizontal, 24)
            
            Button("Forgot password?") {
                Task { await sendReset() }
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.white.opacity(0.9))
            .disabled(email.isEmpty)
            .opacity(email.isEmpty ? 0.5 : 1.0)
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
