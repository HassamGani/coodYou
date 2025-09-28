import SwiftUI

struct ToastBanner: View {
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let toast: AuthShellViewModel.Toast

    var body: some View {
        HStack(spacing: theme.spacing.sm) {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .semibold))
            Text(toast.message)
                .font(theme.typography.caption.font())
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, theme.spacing.lg)
        .padding(.vertical, theme.spacing.md)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.control, style: .continuous))
        .shadow(color: Color.black.opacity(scheme == .dark ? 0.3 : 0.12), radius: 18, y: 12)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(reduceMotion ? .default : .spring(response: 0.45, dampingFraction: 0.82), value: toast.id)
        .accessibilityElement()
        .accessibilityLabel(Text(toast.message))
    }

    private var iconName: String {
        switch toast.style {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.octagon"
        }
    }

    private var background: some View {
        let borderColor: Color
        switch toast.style {
        case .info: borderColor = theme.colors.accentPrimary.resolve(for: scheme)
        case .warning: borderColor = theme.colors.accentWarning.resolve(for: scheme)
        case .error: borderColor = theme.colors.accentError.resolve(for: scheme)
        }
        return RoundedRectangle(cornerRadius: theme.radius.control, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: theme.radius.control, style: .continuous)
                    .stroke(borderColor.opacity(0.35), lineWidth: 1)
            )
    }
}
