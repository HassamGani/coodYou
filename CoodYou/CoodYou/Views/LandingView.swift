import AuthenticationServices
import CryptoKit
import Security
import SwiftUI
import UIKit

struct LandingView: View {
    @State private var showingError: String?
    @State private var isProcessing = false
    @State private var currentNonce: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                heroSection
                actionSection
                Divider()
                    .padding(.horizontal, 32)
                credentialSection
                termsSection
            }
            .padding(.vertical, 40)
        }
        .background(LinearGradient(colors: [.black.opacity(0.85), .blue], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea())
        .alert(item: Binding(
            get: { showingError.map(ErrorMessage.init(value:)) },
            set: { showingError = $0?.value }
        )) { message in
            Alert(title: Text("Authentication"), message: Text(message.value), dismissButton: .default(Text("OK")))
        }
    }

    private var heroSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "tram.fill")
                .font(.system(size: 64))
                .foregroundStyle(.white)
            Text("CampusDash")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.white)
            Text("DoorDash for Columbia and Barnard dining halls. Pair up, grab meals, and get everyone fed fast.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 32)
        }
    }

    private var actionSection: some View {
        VStack(spacing: 16) {
            NavigationLink {
                EmailSignUpView()
            } label: {
                Text("Create an account")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .foregroundColor(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal, 24)

            NavigationLink {
                EmailSignInView()
            } label: {
                Text("Sign in with email")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white.opacity(0.12))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal, 24)
        }
    }

    private var credentialSection: some View {
        VStack(spacing: 16) {
            SignInWithAppleButton(.signIn) { request in
                let nonce = randomNonce()
                currentNonce = nonce
                request.requestedScopes = [.email, .fullName]
                request.nonce = sha256(nonce)
            } onCompletion: { result in
                handleAppleCompletion(result)
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 24)

            Button {
                Task { await handleGoogleSignIn() }
            } label: {
                HStack {
                    Image(systemName: "g.circle")
                    Text("Continue with Google")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white.opacity(0.12))
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal, 24)
            .disabled(isProcessing)
        }
    }

    private var termsSection: some View {
        VStack(spacing: 8) {
            Text("By continuing you agree to our Terms and Privacy Policy.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, 32)
            NavigationLink("Learn more about how CampusDash works") {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("CampusDash combines Uber-style live tracking with DoorDash-style ordering for campus dining halls. The beta is limited to Columbia and Barnard students with .edu email addresses.")
                        Text("You can request meals, fulfill orders for peers, manage payouts, and update your settings from the profile tab once you’re in.")
                        Text("Have questions? Reach out to hello@campusdash.app")
                    }
                    .padding()
                }
                .navigationTitle("About CampusDash")
            }
            .tint(.white)
        }
    }

    private func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
            isProcessing = true
            Task {
                do {
                    _ = try await AuthService.shared.signInWithApple(credential: credential, currentNonce: currentNonce)
                } catch {
                    await MainActor.run { showingError = error.localizedDescription }
                }
                await MainActor.run { isProcessing = false }
            }
        case .failure(let error):
            showingError = error.localizedDescription
        }
    }

    @MainActor
    private func handleGoogleSignIn() async {
        guard let controller = UIApplication.shared.topMostViewController else {
            showingError = "Unable to present Google Sign-In UI."
            return
        }
        isProcessing = true
        do {
            _ = try await AuthService.shared.signInWithGoogle(presenting: controller)
        } catch {
            showingError = error.localizedDescription
        }
        isProcessing = false
    }

    private func randomNonce(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with code \(errorCode)")
                }
                return random
            }

            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}

private extension UIApplication {
    var keyWindow: UIWindow? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }

    var topMostViewController: UIViewController? {
        guard var topController = keyWindow?.rootViewController else { return nil }
        while let presented = topController.presentedViewController {
            topController = presented
        }
        return topController
    }
}
