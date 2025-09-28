import AuthenticationServices
import CryptoKit
import Security
import SwiftUI
import UIKit

struct LandingView: View {
    @State private var showingError: String?
    @State private var isProcessing = false
    @State private var currentNonce: String?
    @State private var animateGradient = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dynamic gradient background
                LinearGradient(
                    colors: [
                        Color.black,
                        Color.black.opacity(0.95),
                        Color.blue.opacity(0.3),
                        Color.black.opacity(0.8)
                    ],
                    startPoint: animateGradient ? .topLeading : .bottomTrailing,
                    endPoint: animateGradient ? .bottomTrailing : .topLeading
                )
                .ignoresSafeArea()
                .onAppear {
                    withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                        animateGradient.toggle()
                    }
                }
                
                // Content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Top spacer for status bar
                        Spacer()
                            .frame(height: geometry.safeAreaInsets.top + 60)
                        
                        heroSection
                        
                        Spacer()
                            .frame(height: max(60, geometry.size.height * 0.1))
                        
                        mainActionSection
                        
                        Spacer()
                            .frame(height: 40)
                        
                        socialLoginSection
                        
                        Spacer()
                            .frame(height: 32)
                        
                        alternativeActionsSection
                        
                        Spacer()
                            .frame(height: 40)
                        
                        termsSection
                        
                        // Bottom spacer
                        Spacer()
                            .frame(height: geometry.safeAreaInsets.bottom + 20)
                    }
                }
            }
        }
        .alert(item: Binding(
            get: { showingError.map(ErrorMessage.init(value:)) },
            set: { showingError = $0?.value }
        )) { message in
            Alert(title: Text("Authentication"), message: Text(message.value), dismissButton: .default(Text("OK")))
        }
    }

    private var heroSection: some View {
        VStack(spacing: 24) {
            // App icon with glow effect
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.2), Color.clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 80
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "tram.fill")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(.white)
                    .shadow(color: .white.opacity(0.3), radius: 10)
            }
            
            VStack(spacing: 12) {
                Text("CampusDash")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                
                Text("Campus dining, delivered instantly")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                
                Text("Pair up with students, grab meals from Columbia & Barnard dining halls")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .lineLimit(2)
            }
        }
    }

    private var mainActionSection: some View {
        VStack(spacing: 16) {
            NavigationLink {
                EmailSignUpView()
            } label: {
                HStack {
                    Text("Get started")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                )
            }
            .padding(.horizontal, 24)
            .scaleEffect(isProcessing ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isProcessing)
        }
    }

    private var socialLoginSection: some View {
        VStack(spacing: 16) {
            // Divider with "or" text
            HStack {
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 1)
                
                Text("or")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 16)
                
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 1)
            }
            .padding(.horizontal, 24)
            
            VStack(spacing: 12) {
                // Apple Sign In Button
                SignInWithAppleButton(.signIn) { request in
                    let nonce = randomNonce()
                    currentNonce = nonce
                    request.requestedScopes = [.email, .fullName]
                    request.nonce = sha256(nonce)
                } onCompletion: { result in
                    handleAppleCompletion(result)
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                .padding(.horizontal, 24)
                .disabled(isProcessing)
                .opacity(isProcessing ? 0.6 : 1.0)

                // Google Sign In Button
                Button {
                    Task { await handleGoogleSignIn() }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "globe")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                        
                        Text("Continue with Google")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
                .padding(.horizontal, 24)
                .disabled(isProcessing)
                .opacity(isProcessing ? 0.6 : 1.0)
                .scaleEffect(isProcessing ? 0.98 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isProcessing)
            }
        }
    }
    
    private var alternativeActionsSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 24) {
                NavigationLink {
                    EmailSignInView()
                } label: {
                    Text("Sign in with email")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .underline()
                }
                
                Text("•")
                    .foregroundColor(.white.opacity(0.5))
                
                NavigationLink("Learn more") {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("About CampusDash")
                                .font(.system(size: 28, weight: .bold))
                                .padding(.bottom, 8)
                            
                            VStack(alignment: .leading, spacing: 16) {
                                FeatureRow(
                                    icon: "bolt.fill",
                                    title: "Instant Delivery",
                                    description: "Get meals from dining halls in minutes with live tracking"
                                )
                                
                                FeatureRow(
                                    icon: "person.2.fill",
                                    title: "Pair & Save",
                                    description: "Match with nearby students to split delivery costs"
                                )
                                
                                FeatureRow(
                                    icon: "building.2.fill",
                                    title: "Campus Exclusive",
                                    description: "Limited to Columbia and Barnard students with .edu emails"
                                )
                                
                                FeatureRow(
                                    icon: "creditcard.fill",
                                    title: "Easy Payments",
                                    description: "Secure payments with Apple Pay, cards, and more"
                                )
                            }
                            
                            Divider()
                                .padding(.vertical, 8)
                            
                            Text("Questions? Reach out to hello@campusdash.app")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        .padding(24)
                    }
                    .navigationTitle("About")
                    .navigationBarTitleDisplayMode(.large)
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .underline()
            }
        }
    }

    private var termsSection: some View {
        Text("By continuing you agree to our Terms and Privacy Policy.")
            .font(.system(size: 14, weight: .regular))
            .foregroundColor(.white.opacity(0.6))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
    }

    @MainActor
    private func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
            isProcessing = true
            Task {
                do {
                    _ = try await AuthService.shared.signInWithApple(credential: credential, currentNonce: currentNonce)
                } catch {
                    showingError = error.localizedDescription
                }
                isProcessing = false
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
        
        for _ in 0..<length {
            var random: UInt8 = 0
            let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if errorCode != errSecSuccess {
                // Fallback to a simpler random method instead of crashing
                result.append(charset.randomElement() ?? "0")
                continue
            }
            
            // Use modulo to ensure we stay within charset bounds
            let index = Int(random) % charset.count
            result.append(charset[index])
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

// MARK: - Feature Row Component
private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}
