import SwiftUI

struct PrimaryActionButton: View {
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let titleKey: String
    let phase: AuthShellViewModel.ButtonPhase
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(NSLocalizedString(titleKey, comment: "Primary action"))
                .font(theme.typography.body.font())
                .frame(maxWidth: .infinity)
                .padding(.vertical, theme.spacing.md)
                .contentShape(Rectangle())
        }
        .buttonStyle(PrimaryButtonStyle(theme: theme, scheme: scheme, phase: phase, reduceMotion: reduceMotion, isEnabled: isEnabled))
        .disabled(!isEnabled)
        .accessibilityIdentifier("auth.primaryButton")
        .accessibilityHint(phase == .loading ? Text(NSLocalizedString("auth.accessibility.loading", comment: "Loading")) : Text(""))
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    let theme: Theme
    let scheme: ColorScheme
    let phase: AuthShellViewModel.ButtonPhase
    let reduceMotion: Bool
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        let background = isEnabled ? theme.colors.accentPrimary.resolve(for: scheme) : theme.colors.foregroundSecondary.resolve(for: scheme).opacity(0.3)
        let foreground = isEnabled ? Color.white : theme.colors.foregroundPrimary.resolve(for: scheme).opacity(0.65)

        return configuration.label
            .foregroundStyle(foreground)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: theme.radius.control, style: .continuous))
            .overlay(alignment: .center) {
                switch phase {
                case .loading:
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(foreground)
                case .success:
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(foreground)
                        .transition(.scale.combined(with: .opacity))
                        .symbolEffect(.bounce, options: .repeating) // respects reduce motion automatically
                default:
                    EmptyView()
                }
            }
            .opacity(phase == .loading ? 0.8 : 1)
            .scaleEffect(scale(for: configuration.isPressed))
            .animation(animation(for: configuration.isPressed), value: configuration.isPressed)
            .animation(.spring(response: 0.35, dampingFraction: 0.78), value: phase)
    }

    private func scale(for pressed: Bool) -> CGFloat {
        if reduceMotion { return 1 }
        if phase == .success { return 1.02 }
        return pressed ? 0.95 : 1
    }

    private func animation(for pressed: Bool) -> Animation {
        if reduceMotion { return .default }
        return .spring(response: 0.25, dampingFraction: 0.8)
    }
}

struct OAuthButtonsView: View {
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    let isDisabled: Bool
    let onGoogleTapped: () -> Void

    var body: some View {
        Button(action: onGoogleTapped) {
            HStack(spacing: theme.spacing.md) {
                GoogleGlyph()
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("auth.oauth.google", comment: "Continue with Google"))
                        .font(theme.typography.body.font())
                        .foregroundStyle(theme.colors.foregroundPrimary.resolve(for: scheme))
                    Text(NSLocalizedString("auth.oauth.googleSubtitle", comment: "Use your Google account"))
                        .font(theme.typography.caption.font())
                        .foregroundStyle(theme.colors.foregroundSecondary.resolve(for: scheme))
                }
                Spacer()
            }
            .padding(.vertical, theme.spacing.md)
            .padding(.horizontal, theme.spacing.lg)
        }
        .buttonStyle(GoogleButtonStyle(theme: theme, scheme: scheme, disabled: isDisabled))
        .disabled(isDisabled)
    }
}

private struct GoogleButtonStyle: ButtonStyle {
    let theme: Theme
    let scheme: ColorScheme
    let disabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: theme.radius.control, style: .continuous)
                    .fill(Color.white.opacity(scheme == .dark ? 0.12 : 1))
                    .shadow(color: Color.black.opacity(0.08), radius: 18, y: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.radius.control, style: .continuous)
                    .stroke(theme.colors.foregroundSecondary.resolve(for: scheme).opacity(0.15), lineWidth: 1)
            )
            .opacity(disabled ? 0.5 : 1)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

struct GoogleGlyph: View {
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let lineWidth = size.width * 0.22
            ZStack {
                Circle()
                    .trim(from: 0.0, to: 0.25)
                    .stroke(Color(red: 234/255, green: 67/255, blue: 53/255), lineWidth: lineWidth)
                    .rotationEffect(.degrees(-45))
                Circle()
                    .trim(from: 0.25, to: 0.5)
                    .stroke(Color(red: 251/255, green: 188/255, blue: 5/255), lineWidth: lineWidth)
                    .rotationEffect(.degrees(-45))
                Circle()
                    .trim(from: 0.5, to: 0.75)
                    .stroke(Color(red: 52/255, green: 168/255, blue: 83/255), lineWidth: lineWidth)
                    .rotationEffect(.degrees(-45))
                Circle()
                    .trim(from: 0.75, to: 1.0)
                    .stroke(Color(red: 66/255, green: 133/255, blue: 244/255), lineWidth: lineWidth)
                    .rotationEffect(.degrees(-45))

                Path { path in
                    let width = size.width
                    let height = size.height
                    path.move(to: CGPoint(x: width * 0.45, y: height * 0.5))
                    path.addLine(to: CGPoint(x: width * 0.75, y: height * 0.5))
                    path.addLine(to: CGPoint(x: width * 0.75, y: height * 0.62))
                    path.addLine(to: CGPoint(x: width * 0.55, y: height * 0.62))
                }
                .stroke(Color(red: 66/255, green: 133/255, blue: 244/255), lineWidth: lineWidth)
            }
        }
        .frame(width: 28, height: 28)
    }
}

struct DividerLabel: View {
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    let textKey: String

    var body: some View {
        HStack(alignment: .center, spacing: theme.spacing.sm) {
            line
            Text(NSLocalizedString(textKey, comment: "Divider label"))
                .font(theme.typography.caption.font())
                .foregroundStyle(theme.colors.foregroundSecondary.resolve(for: scheme))
            line
        }
    }

    private var line: some View {
        Rectangle()
            .fill(theme.colors.foregroundSecondary.resolve(for: scheme).opacity(0.2))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }
}

struct ValidationMessageView: View {
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    let message: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: theme.spacing.xs) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 14, weight: .semibold))
            Text(message)
                .font(theme.typography.caption.font())
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(theme.colors.accentError.resolve(for: scheme))
        .padding(.top, theme.spacing.xs)
        .transition(.opacity.combined(with: .scale))
        .accessibilityIdentifier("auth.inlineError")
        .accessibilityHint(Text(message))
    }
}

struct InputField: View {
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let titleKey: String
    let systemImage: String
    let matchedID: String?
    let namespace: Namespace.ID?
    let error: String?
    let content: () -> AnyView

    init(titleKey: String, systemImage: String, matchedID: String? = nil, namespace: Namespace.ID? = nil, error: String?, @ViewBuilder content: @escaping () -> some View) {
        self.titleKey = titleKey
        self.systemImage = systemImage
        self.matchedID = matchedID
        self.namespace = namespace
        self.error = error
        self.content = { AnyView(content()) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            HStack(alignment: .center, spacing: theme.spacing.sm) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .regular))
                Text(NSLocalizedString(titleKey, comment: "Field label"))
                    .font(theme.typography.caption.font())
                    .foregroundStyle(theme.colors.foregroundSecondary.resolve(for: scheme))
            }
            .opacity(0.9)
            content()
                .frame(height: 44)
        }
        .padding(.horizontal, theme.spacing.md)
        .padding(.vertical, theme.spacing.sm)
        .background(fieldBackground)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.control, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radius.control, style: .continuous)
                .stroke(borderColor, lineWidth: error == nil ? 1 : 1.5)
        )
        .ifLet(namespace, matchedID) { view, info in
            view.matchedGeometryEffect(id: info.id, in: info.namespace)
        }
        .animation(reduceMotion ? .none : .easeInOut(duration: 0.2), value: error)
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: theme.radius.control, style: .continuous)
            .fill(.regularMaterial)
            .shadow(color: Color.black.opacity(scheme == .dark ? 0.25 : 0.06), radius: 12, y: 6)
    }

    private var borderColor: Color {
        if error != nil {
            return theme.colors.accentError.resolve(for: scheme).opacity(0.8)
        }
        return theme.colors.foregroundSecondary.resolve(for: scheme).opacity(0.12)
    }
}

struct PasswordStrengthBar: View {
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    let strength: AuthShellViewModel.PasswordStrength

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(theme.colors.foregroundSecondary.resolve(for: scheme).opacity(0.12))
                Capsule()
                    .fill(strength.tint)
                    .frame(width: geometry.size.width * widthMultiplier)
                    .animation(.easeOut(duration: 0.3), value: strength)
            }
        }
        .frame(height: 6)
        .accessibilityLabel(Text(strength.localized))
    }

    private var widthMultiplier: CGFloat {
        switch strength {
        case .weak: return 0.33
        case .medium: return 0.66
        case .strong: return 1
        }
    }
}

private extension View {
    @ViewBuilder
    func ifLet<Value, Content: View>(_ value: Value?, _ id: String?, transform: (Self, (namespace: Value, id: String)) -> Content) -> some View {
        if let value, let id {
            transform(self, (value, id))
        } else {
            self
        }
    }
}

extension View {
    func eraseToAnyView() -> AnyView { AnyView(self) }
}

struct CheckmarkSuccess: View {
    @State private var animate = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            Circle()
                .stroke(theme.colors.accentSuccess.resolve(for: scheme).opacity(0.3), lineWidth: 12)
            Circle()
                .trim(from: 0, to: animate ? 1 : 0)
                .stroke(theme.colors.accentSuccess.resolve(for: scheme), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? .default : .spring(response: 0.45, dampingFraction: 0.7).delay(0.1), value: animate)
            Image(systemName: "checkmark")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(theme.colors.accentSuccess.resolve(for: scheme))
                .scaleEffect(animate ? 1 : 0.5)
                .opacity(animate ? 1 : 0)
                .animation(reduceMotion ? .default : .spring(response: 0.4, dampingFraction: 0.6).delay(0.4), value: animate)
        }
        .frame(width: 96, height: 96)
        .onAppear {
            animate = true
        }
    }
}
