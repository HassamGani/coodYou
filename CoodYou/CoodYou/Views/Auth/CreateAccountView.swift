import SwiftUI

struct CreateAccountView: View {
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    @ObservedObject var viewModel: AuthShellViewModel
    let namespace: Namespace.ID
    @FocusState private var focus: AuthShellViewModel.FocusField?

    var body: some View {
        VStack(spacing: theme.spacing.lg) {
            VStack(spacing: theme.spacing.sm) {
                InputField(titleKey: "auth.field.name", systemImage: "person", matchedID: nil, namespace: nil, error: nameError) {
                    TextField(NSLocalizedString("auth.placeholder.name", comment: "Name"), text: $viewModel.name)
                        .textContentType(.name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .focused($focus, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focus = .email }
                        .accessibilityIdentifier("auth.nameField")
                        .eraseToAnyView()
                }

                InputField(titleKey: "auth.field.email", systemImage: "envelope", matchedID: "emailField", namespace: namespace, error: emailError) {
                    TextField(NSLocalizedString("auth.placeholder.email", comment: "Email"), text: $viewModel.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .focused($focus, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { submitFromEmail() }
                        .accessibilityIdentifier("auth.emailField")
                        .eraseToAnyView()
                }

                VStack(spacing: theme.spacing.xs) {
                    InputField(titleKey: "auth.field.password", systemImage: "lock", matchedID: nil, namespace: nil, error: passwordError) {
                        SecureField(NSLocalizedString("auth.placeholder.password", comment: "Password"), text: $viewModel.password)
                            .textContentType(.newPassword)
                            .focused($focus, equals: .password)
                            .submitLabel(.done)
                            .onSubmit { viewModel.handlePrimaryAction() }
                            .accessibilityIdentifier("auth.passwordField")
                            .eraseToAnyView()
                    }
                    PasswordStrengthBar(strength: viewModel.passwordStrength(viewModel.password))
                        .frame(height: 6)
                    Text(viewModel.passwordStrength(viewModel.password).localized)
                        .font(theme.typography.caption.font())
                        .foregroundStyle(theme.colors.foregroundSecondary.resolve(for: scheme))
                }
                .transition(.move(edge: .top).combined(with: .opacity))

                if let inlineError = viewModel.inlineError {
                    ValidationMessageView(message: inlineError)
                }
            }

            PrimaryActionButton(titleKey: "auth.cta.create", phase: viewModel.buttonPhase, isEnabled: !viewModel.name.isEmpty && !viewModel.email.isEmpty && !viewModel.isLoading) {
                viewModel.handlePrimaryAction()
            }
            .matchedGeometryEffect(id: "primaryButton", in: namespace)

            Button(action: viewModel.goToSignIn) {
                Text(NSLocalizedString("auth.link.haveAccount", comment: "Have account"))
                    .font(theme.typography.body.font())
            }
            .buttonStyle(.plain)
        }
        .task {
            try? await Task.sleep(nanoseconds: 120_000_000)
            focus = .name
        }
    }

    private var nameError: String? {
        viewModel.inlineError?.contains(NSLocalizedString("auth.validation.name", comment: "Name required")) == true ? viewModel.inlineError : nil
    }

    private var emailError: String? {
        viewModel.inlineError?.contains(NSLocalizedString("auth.validation.email", comment: "Invalid email format")) == true ? viewModel.inlineError : nil
    }

    private var passwordError: String? {
        if let inlineError = viewModel.inlineError {
            if inlineError.contains(NSLocalizedString("auth.validation.passwordWeak", comment: "Password weak")) || inlineError.contains(NSLocalizedString("auth.validation.passwordRequired", comment: "Password required")) {
                return inlineError
            }
        }
        return nil
    }

    private func submitFromEmail() {
        focus = .password
    }
}
