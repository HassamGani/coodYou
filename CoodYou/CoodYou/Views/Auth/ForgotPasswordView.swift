import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    @ObservedObject var viewModel: AuthShellViewModel
    let namespace: Namespace.ID
    @FocusState private var focus: AuthShellViewModel.FocusField?

    var body: some View {
        VStack(spacing: theme.spacing.lg) {
            VStack(alignment: .leading, spacing: theme.spacing.sm) {
                Text(NSLocalizedString("auth.forgot.title", comment: "Forgot password"))
                    .font(theme.typography.titleM.font())
                    .foregroundStyle(theme.colors.foregroundPrimary.resolve(for: scheme))
                Text(NSLocalizedString("auth.forgot.subtitle", comment: "Subtitle"))
                    .font(theme.typography.body.font())
                    .foregroundStyle(theme.colors.foregroundSecondary.resolve(for: scheme))
            }

            VStack(spacing: theme.spacing.sm) {
                InputField(titleKey: "auth.field.email", systemImage: "envelope", matchedID: "emailField", namespace: namespace, error: inlineError) {
                    TextField(NSLocalizedString("auth.placeholder.email", comment: "Email"), text: $viewModel.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .focused($focus, equals: .email)
                        .submitLabel(.done)
                        .onSubmit { viewModel.handlePrimaryAction() }
                        .accessibilityIdentifier("auth.emailField")
                        .eraseToAnyView()
                }

                if let inlineError {
                    ValidationMessageView(message: inlineError)
                }
            }

            PrimaryActionButton(titleKey: "auth.cta.reset", phase: viewModel.buttonPhase, isEnabled: !viewModel.email.isEmpty && !viewModel.isLoading) {
                viewModel.handlePrimaryAction()
            }
            .matchedGeometryEffect(id: "primaryButton", in: namespace)

            Button(action: viewModel.goToSignIn) {
                Text(NSLocalizedString("auth.link.backToSignIn", comment: "Back to sign in"))
                    .font(theme.typography.caption.font())
            }
            .buttonStyle(.plain)
            .padding(.top, theme.spacing.sm)
        }
        .task {
            try? await Task.sleep(nanoseconds: 120_000_000)
            focus = .email
        }
    }

    private var inlineError: String? {
        if case .forgot = viewModel.state {
            return viewModel.inlineError
        }
        return nil
    }
}
