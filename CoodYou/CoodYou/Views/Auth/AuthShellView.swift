import SwiftUI
import UIKit

struct AuthShellView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicType
    @Environment(\.theme) private var theme
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: AuthShellViewModel
    @Namespace private var geometryNamespace
    @State private var showTerms = false
    @State private var showPrivacy = false
    @State private var isKeyboardVisible = false

    init(service: AuthFlowService = MockAuthFlowService()) {
        _viewModel = StateObject(wrappedValue: AuthShellViewModel(service: service))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                theme.colors.backgroundBase.resolve(for: colorScheme)
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: theme.spacing.xl) {
                        header
                        Divider()
                            .background(Color.primary.opacity(0.08))
                            .opacity(viewModel.state != .welcome ? 0 : 1)
                        content
                        LegalFooterView(showTerms: $showTerms, showPrivacy: $showPrivacy)
                            .padding(.top, theme.spacing.lg)
                    }
                    .padding(.horizontal, layoutHorizontalPadding(for: proxy.size))
                    .padding(.top, theme.spacing.xl)
                    .padding(.bottom, theme.spacing.xl + (isKeyboardVisible ? theme.spacing.xl : 0))
                    .frame(minHeight: proxy.size.height, alignment: .top)
                }
                .scrollDismissesKeyboard(.interactively)

                if let toast = viewModel.toast {
                    ToastBanner(toast: toast)
                        .padding(.top, proxy.safeAreaInsets.top + theme.spacing.md)
                        .padding(.horizontal, theme.spacing.lg)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                isKeyboardVisible = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                isKeyboardVisible = false
            }
        }
        .task(id: viewModel.toast?.id) {
            guard let toastID = viewModel.toast?.id else { return }
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if toastID == viewModel.toast?.id {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.toast = nil
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.state)
        .sheet(isPresented: $showTerms) {
            LegalSheetView(titleKey: "auth.legal.terms")
        }
        .sheet(isPresented: $showPrivacy) {
            LegalSheetView(titleKey: "auth.legal.privacy")
        }
        .onChange(of: viewModel.state) { _, newValue in
            if newValue == .success {
                Task { await finalizeSessionTransition() }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            BrandMark()
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            Text(NSLocalizedString("auth.headline", comment: "Headline"))
                .font(theme.typography.titleXL.font())
                .foregroundStyle(theme.colors.foregroundPrimary.resolve(for: colorScheme))
                .multilineTextAlignment(.leading)
                .matchedGeometryEffect(id: "headline", in: geometryNamespace)
            Text(NSLocalizedString("auth.subheadline", comment: "Sub headline"))
                .font(theme.typography.body.font())
                .foregroundStyle(theme.colors.foregroundSecondary.resolve(for: colorScheme))
                .padding(.trailing, theme.spacing.md)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .welcome, .emailEntry:
            WelcomeSignInView(
                viewModel: viewModel,
                namespace: geometryNamespace,
                onGoogle: handleGoogle
            )
        case .codeEntry:
            CodeEntryView(viewModel: viewModel, namespace: geometryNamespace)
        case .creating:
            CreateAccountView(viewModel: viewModel, namespace: geometryNamespace)
        case .forgot:
            ForgotPasswordView(viewModel: viewModel, namespace: geometryNamespace)
        case .success:
            SuccessStateView()
        case .error(let message):
            ErrorStateView(message: message)
        }
    }

    private func layoutHorizontalPadding(for size: CGSize) -> CGFloat {
        switch size.width {
        case ..<360: return theme.spacing.md
        case ..<440: return theme.spacing.lg
        default: return theme.spacing.xl
        }
    }
    
    private func handleGoogle() {
        guard let presenter = topViewController() else {
            viewModel.handleOAuthFailure(AuthFlowError.serverError)
            return
        }
        Task {
            await MainActor.run { viewModel.isLoading = true }
            do {
                let profile = try await AuthService.shared.signInWithGoogle(presenting: presenter)
                await MainActor.run {
                    viewModel.isLoading = false
                    let isNew = profile.completedRuns == 0
                    viewModel.handleOAuthSuccess(AuthFlowServiceResult(isNewUser: isNew, requiresLinking: false))
                }
            } catch {
                await MainActor.run {
                    viewModel.isLoading = false
                    viewModel.handleOAuthFailure(error)
                }
            }
        }
    }

    private func topViewController(controller: UIViewController? = nil) -> UIViewController? {
        let controller = controller ?? UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.rootViewController

        if let navigation = controller as? UINavigationController {
            return topViewController(controller: navigation.visibleViewController)
        }
        if let tab = controller as? UITabBarController {
            return topViewController(controller: tab.selectedViewController)
        }
        if let presented = controller?.presentedViewController {
            return topViewController(controller: presented)
        }
        return controller
    }

    private func finalizeSessionTransition() async {
        if FirebaseManager.shared.auth.currentUser == nil {
            return
        }
        await appState.refreshSession()
    }
}

private struct SuccessStateView: View {
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: theme.spacing.lg) {
            CheckmarkSuccess()
            Text(NSLocalizedString("auth.success.title", comment: "Success"))
                .font(theme.typography.titleM.font())
                .foregroundStyle(theme.colors.foregroundPrimary.resolve(for: scheme))
            Text(NSLocalizedString("auth.success.subtitle", comment: "Success subtitle"))
                .font(theme.typography.body.font())
                .foregroundStyle(theme.colors.foregroundSecondary.resolve(for: scheme))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(theme.spacing.xl)
        .themedBackground(Theme.current.colors.backgroundBase)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.control, style: .continuous))
    }
}

private struct ErrorStateView: View {
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    let message: String

    var body: some View {
        VStack(spacing: theme.spacing.sm) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32, weight: .regular))
                .foregroundStyle(theme.colors.accentWarning.resolve(for: scheme))
            Text(message)
                .font(theme.typography.body.font())
                .foregroundStyle(theme.colors.foregroundSecondary.resolve(for: scheme))
                .multilineTextAlignment(.center)
        }
        .padding(theme.spacing.lg)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: theme.radius.control, style: .continuous))
    }
}

private struct BrandMark: View {
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: theme.spacing.sm) {
            Circle()
                .fill(theme.colors.accentPrimary.resolve(for: scheme))
                .frame(width: 18, height: 18)
                .overlay(
                    Circle()
                        .stroke(theme.colors.accentPrimary.resolve(for: scheme).opacity(0.3), lineWidth: 1)
                )
            Text("CoodYou")
                .font(theme.typography.titleM.font())
                .foregroundStyle(theme.colors.foregroundPrimary.resolve(for: scheme))
        }
        .accessibilityLabel(Text(NSLocalizedString("auth.brand", comment: "Brand name")))
    }
}

private struct LegalSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    let titleKey: String

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(NSLocalizedString("auth.legal.placeholder", comment: "Legal placeholder"))
                    .font(theme.typography.body.font())
                    .foregroundStyle(theme.colors.foregroundSecondary.resolve(for: scheme))
                    .padding(theme.spacing.lg)
            }
            .navigationTitle(Text(NSLocalizedString(titleKey, comment: "Title")))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .imageScale(.medium)
                    }
                    .keyboardShortcut(.cancelAction)
                }
            }
        }
    }
}

struct AuthShellView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AuthShellView()
                .environment(\.theme, .current)
                .environmentObject(AppState())
            AuthShellView()
                .environment(\.theme, .current)
                .environment(\.locale, Locale(identifier: "ar"))
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark)
                .environmentObject(AppState())
            AuthShellView()
                .environment(\.theme, .current)
                .environment(\.dynamicTypeSize, .accessibility5)
                .environmentObject(AppState())
        }
    }
}
