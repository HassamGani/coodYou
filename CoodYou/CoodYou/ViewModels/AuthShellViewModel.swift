import Combine
import Foundation
import SwiftUI
import UIKit

@MainActor
final class AuthShellViewModel: ObservableObject {
    enum FlowState: Equatable {
        case welcome
        case emailEntry
        case codeEntry
        case creating
        case forgot
        case success
        case error(String)
    }

    enum FocusField: Hashable {
        case email
        case name
        case password
        case signInPassword
        case code(UUID)
    }

    struct Toast: Identifiable, Equatable {
        let id = UUID()
        let message: String
        let style: Style

        enum Style {
            case info
            case warning
            case error
        }
    }

    @Published var state: FlowState = .welcome
    @Published var email: String = ""
    @Published var name: String = ""
    @Published var password: String = ""
    @Published var signInPassword: String = ""
    @Published var codeDigits: [String] = Array(repeating: "", count: 6)
    @Published var isLoading = false
    @Published var toast: Toast?
    @Published var inlineError: String?
    @Published var resendCountdown: Int = 30
    @Published var buttonPhase: ButtonPhase = .idle
    @Published var prefersPasswordSignIn = true

    let service: AuthFlowService
    private var countdownTask: Task<Void, Never>?

    init(service: AuthFlowService = MockAuthFlowService()) {
        self.service = service
    }

    deinit {
        countdownTask?.cancel()
    }

    func handlePrimaryAction() {
        switch state {
        case .welcome, .emailEntry:
            if prefersPasswordSignIn {
                Task { await signInWithPassword() }
            } else {
                Task { await submitEmail() }
            }
        case .codeEntry:
            Task { await verifyCode() }
        case .creating:
            Task { await createAccount() }
        case .forgot:
            Task { await sendReset() }
        case .success:
            break
        case .error:
            state = .welcome
        }
    }

    func goToCreateAccount() {
        withAnimation(.easeInOut(duration: 0.3)) {
            state = .creating
            inlineError = nil
        }
    }

    func goToSignIn() {
        withAnimation(.easeInOut(duration: 0.3)) {
            state = .emailEntry
            inlineError = nil
        }
    }

    func goToForgot() {
        withAnimation(.easeInOut(duration: 0.3)) {
            state = .forgot
            inlineError = nil
        }
    }

    func backToWelcome() {
        withAnimation(.easeInOut(duration: 0.3)) {
            state = .welcome
            inlineError = nil
        }
    }

    func setPasswordSignIn(_ enabled: Bool) {
        withAnimation(.easeInOut(duration: 0.25)) {
            prefersPasswordSignIn = enabled
            inlineError = nil
        }
        if !enabled {
            signInPassword = ""
        }
    }

    func pasteIntoCode(_ string: String) {
        let digits = string.compactMap { $0.wholeNumberValue }.map(String.init)
        guard !digits.isEmpty else { return }
        let limited = digits.prefix(6)
        for (index, value) in limited.enumerated() {
            codeDigits[index] = value
        }
    }

    private func submitEmail() async {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidEmail(trimmed) else {
            inlineError = NSLocalizedString("auth.validation.email", comment: "Invalid email format")
            notifyHaptic(.warning)
            return
        }
        await performLoading { [self] in
            try await self.service.requestCode(for: trimmed)
            self.startCountdown()
            withAnimation(.easeInOut(duration: 0.3)) {
                self.state = .codeEntry
                self.inlineError = nil
            }
            self.notifyHaptic(.light)
        }
    }

    private func signInWithPassword() async {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidEmail(trimmed) else {
            inlineError = NSLocalizedString("auth.validation.email", comment: "Invalid email format")
            notifyHaptic(.warning)
            return
        }
        guard !signInPassword.trimmingCharacters(in: .whitespaces).isEmpty else {
            inlineError = NSLocalizedString("auth.validation.passwordRequired", comment: "Password required")
            notifyHaptic(.warning)
            return
        }

        await performLoading { [self] in
            _ = try await AuthService.shared.signIn(withEmail: trimmed, password: self.signInPassword)
            self.inlineError = nil
            self.signInPassword = ""
            self.notifyHaptic(.success)
            withAnimation(.easeInOut(duration: 0.35)) {
                self.state = .success
            }
        }
    }

    private func verifyCode() async {
        let code = codeDigits.joined()
        guard code.count == 6 else {
            inlineError = NSLocalizedString("auth.validation.codeLength", comment: "Code length")
            notifyHaptic(.warning)
            return
        }

        await performLoading { [self] in
            let result = try await self.service.verifyCode(email: self.email, code: code)
            self.inlineError = nil
            self.notifyHaptic(.success)
            if result.requiresLinking {
                self.toast = Toast(message: NSLocalizedString("auth.toast.linkAccount", comment: "Link account"), style: .info)
            }
            withAnimation(.easeInOut(duration: 0.35)) {
                self.state = .success
            }
        }
    }

    private func createAccount() async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            inlineError = NSLocalizedString("auth.validation.name", comment: "Name required")
            notifyHaptic(.warning)
            return
        }
        guard isValidEmail(trimmedEmail) else {
            inlineError = NSLocalizedString("auth.validation.email", comment: "Invalid email format")
            notifyHaptic(.warning)
            return
        }
        guard !password.isEmpty else {
            inlineError = NSLocalizedString("auth.validation.passwordRequired", comment: "Password required")
            notifyHaptic(.warning)
            return
        }
        guard passwordStrength(password) != .weak else {
            inlineError = NSLocalizedString("auth.validation.passwordWeak", comment: "Password weak")
            notifyHaptic(.warning)
            return
        }
        // Use SchoolService instead of the removed SchoolDirectory helper
        try? await SchoolService.shared.ensureSchoolsLoaded()
        guard let school = await SchoolService.shared.school(forEmail: trimmedEmail) else {
            inlineError = NSLocalizedString("auth.validation.school", comment: "Unsupported school")
            notifyHaptic(.warning)
            return
        }

        let components = splitName(name)

        await performLoading { [self] in
            _ = try await AuthService.shared.register(
                firstName: components.first,
                lastName: components.last,
                email: trimmedEmail,
                password: self.password,
                phoneNumber: nil,
                selectedSchool: school
            )
            self.inlineError = nil
            self.notifyHaptic(.success)
            withAnimation(.easeInOut(duration: 0.35)) {
                self.state = .success
            }
        }
    }

    private func sendReset() async {
        guard isValidEmail(email) else {
            inlineError = NSLocalizedString("auth.validation.email", comment: "Invalid email format")
            notifyHaptic(.warning)
            return
        }
        await performLoading { [self] in
            try await self.service.forgotPassword(email: self.email)
            self.inlineError = nil
            self.toast = Toast(message: NSLocalizedString("auth.toast.resetSent", comment: "Reset sent"), style: .info)
            withAnimation(.easeInOut(duration: 0.3)) {
                self.state = .emailEntry
            }
        }
    }

    private func performLoading(task: @escaping () async throws -> Void) async {
        guard !isLoading else { return }
        isLoading = true
        buttonPhase = .loading
        inlineError = nil
        do {
            try await task()
            buttonPhase = .success
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if case .success = state {
                // keep success phase until shell transitions
            } else {
                buttonPhase = .idle
            }
        } catch {
            inlineError = map(error: error)
            toast = Toast(message: inlineError ?? NSLocalizedString("auth.error.generic", comment: "Generic error"), style: .error)
            buttonPhase = .idle
        }
        isLoading = false
    }

    private func map(error: Error) -> String {
        if let flowError = error as? AuthFlowError {
            return flowError.localizedDescription ?? NSLocalizedString("auth.error.generic", comment: "Generic error")
        }
        return error.localizedDescription
    }

    func resendCode() {
        guard resendCountdown == 0 else { return }
        Task {
            await submitEmail()
        }
    }

    private func startCountdown() {
        countdownTask?.cancel()
        resendCountdown = 30
        countdownTask = Task {
            for second in stride(from: 29, through: 0, by: -1) {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run { [weak self] in
                    self?.resendCountdown = second
                }
                if Task.isCancelled { break }
            }
            await MainActor.run { [weak self] in
                if self?.buttonPhase != .loading {
                    self?.buttonPhase = .idle
                }
            }
        }
    }

    func passwordStrength(_ value: String) -> PasswordStrength {
        let lengthScore = value.count >= 10
        let hasUpper = value.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasLower = value.range(of: "[a-z]", options: .regularExpression) != nil
        let hasNumber = value.range(of: "[0-9]", options: .regularExpression) != nil
        let hasSymbol = value.range(of: "[!@#$%^&*(),.?\\\"{}|<>]", options: .regularExpression) != nil

        let score = [lengthScore, hasUpper, hasLower, hasNumber, hasSymbol].filter { $0 }.count

        switch score {
        case 0...2: return .weak
        case 3...4: return .medium
        default: return .strong
        }
    }

    private func splitName(_ fullName: String) -> (first: String, last: String) {
        let components = fullName
            .split(separator: " ", omittingEmptySubsequences: true)
            .map(String.init)
        guard let first = components.first else { return ("", "") }
        let last = components.dropFirst().joined(separator: " ")
        return (first, last)
    }

    enum PasswordStrength: String {
        case weak
        case medium
        case strong

        var localized: String {
            switch self {
            case .weak: return NSLocalizedString("auth.password.weak", comment: "Weak")
            case .medium: return NSLocalizedString("auth.password.medium", comment: "Medium")
            case .strong: return NSLocalizedString("auth.password.strong", comment: "Strong")
            }
        }

        var tint: Color {
            switch self {
            case .weak: return Theme.current.colors.accentError.light
            case .medium: return Theme.current.colors.accentWarning.light
            case .strong: return Theme.current.colors.accentSuccess.light
            }
        }
    }

    enum ButtonPhase: Equatable {
        case idle
        case loading
        case success
    }

    func handleOAuthSuccess(_ result: AuthFlowServiceResult) {
        inlineError = nil
        notifyHaptic(.success)
        if result.requiresLinking {
            toast = Toast(message: NSLocalizedString("auth.toast.linkAccount", comment: "Link account"), style: .info)
        }
        withAnimation(.easeInOut(duration: 0.35)) {
            state = .success
        }
        buttonPhase = .success
    }

    func handleOAuthFailure(_ error: Error) {
        inlineError = map(error: error)
        toast = Toast(message: inlineError ?? NSLocalizedString("auth.error.generic", comment: "Generic error"), style: .error)
        buttonPhase = .idle
        notifyHaptic(.warning)
    }

    private func isValidEmail(_ value: String) -> Bool {
        guard !value.isEmpty else { return false }
        let pattern = #"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"#
        return value.range(of: pattern, options: .regularExpression) != nil
    }

    private func notifyHaptic(_ type: HapticType) {
        Task { @MainActor in
            switch type {
            case .light:
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            case .warning:
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.warning)
            case .success:
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        }
    }

    enum HapticType {
        case light
        case warning
        case success
    }
}
