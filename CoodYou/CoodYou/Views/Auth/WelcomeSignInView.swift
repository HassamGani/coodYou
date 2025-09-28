import SwiftUI

struct WelcomeSignInView: View {
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    @ObservedObject var viewModel: AuthShellViewModel
    let namespace: Namespace.ID
    let onGoogle: () -> Void
    @FocusState private var focus: AuthShellViewModel.FocusField?

    var body: some View {
        VStack(spacing: theme.spacing.lg) {
            OAuthButtonsView(
                isDisabled: viewModel.isLoading,
                onGoogleTapped: onGoogle
            )

            DividerLabel(textKey: "auth.divider.or")

            VStack(spacing: theme.spacing.sm) {
                InputField(titleKey: "auth.field.email", systemImage: "envelope", matchedID: "emailField", namespace: namespace, error: inlineError) {
                    TextField(NSLocalizedString("auth.placeholder.email", comment: "Email"), text: $viewModel.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .focused($focus, equals: .email)
                        .submitLabel(.go)
                        .onSubmit { viewModel.handlePrimaryAction() }
                        .accessibilityIdentifier("auth.emailField")
                        .eraseToAnyView()
                }

                if viewModel.prefersPasswordSignIn {
                    InputField(titleKey: "auth.field.password", systemImage: "lock", error: inlineError) {
                        SecureField(NSLocalizedString("auth.placeholder.password", comment: "Password"), text: $viewModel.signInPassword)
                            .textContentType(.password)
                            .focused($focus, equals: .signInPassword)
                            .submitLabel(.go)
                            .onSubmit { viewModel.handlePrimaryAction() }
                            .accessibilityIdentifier("auth.passwordField")
                            .eraseToAnyView()
                    }
                }

                if let inlineError {
                    ValidationMessageView(message: inlineError)
                }
            }

            PrimaryActionButton(titleKey: viewModel.prefersPasswordSignIn ? "auth.cta.signIn" : "auth.cta.continue", phase: viewModel.buttonPhase, isEnabled: primaryButtonEnabled) {
                viewModel.handlePrimaryAction()
            }
            .matchedGeometryEffect(id: "primaryButton", in: namespace)

            VStack(spacing: theme.spacing.xs) {
                Button(action: viewModel.goToCreateAccount) {
                    Text(NSLocalizedString("auth.link.create", comment: "Create account"))
                        .font(theme.typography.body.font())
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text(NSLocalizedString("auth.accessibility.create", comment: "Create account hint")))

                Button(action: viewModel.goToForgot) {
                    Text(NSLocalizedString("auth.link.forgot", comment: "Forgot password"))
                        .font(theme.typography.caption.font())
                        .foregroundStyle(theme.colors.foregroundSecondary.resolve(for: scheme))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, theme.spacing.sm)

            Button(action: { viewModel.setPasswordSignIn(!viewModel.prefersPasswordSignIn) }) {
                Text(viewModel.prefersPasswordSignIn ? NSLocalizedString("auth.link.useEmailCode", comment: "Use email code") : NSLocalizedString("auth.link.usePassword", comment: "Use password"))
                    .font(theme.typography.caption.font())
                    .foregroundStyle(theme.colors.foregroundSecondary.resolve(for: scheme))
            }
            .buttonStyle(.plain)
        }
        .task {
            try? await Task.sleep(nanoseconds: 120_000_000)
            focus = .email
        }
    }

    private var inlineError: String? {
        switch viewModel.state {
        case .welcome, .emailEntry:
            return viewModel.inlineError
        default:
            return nil
        }
    }

    private var primaryButtonEnabled: Bool {
        if viewModel.prefersPasswordSignIn {
            return !viewModel.email.isEmpty && !viewModel.signInPassword.isEmpty && !viewModel.isLoading
        }
        return !viewModel.email.isEmpty && !viewModel.isLoading
    }
}
