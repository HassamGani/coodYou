import SwiftUI

struct LegalFooterView: View {
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    @Binding var showTerms: Bool
    @Binding var showPrivacy: Bool

    var body: some View {
        VStack(spacing: theme.spacing.xs) {
            Text(NSLocalizedString("auth.legal.disclaimer", comment: "Legal disclaimer"))
                .font(theme.typography.caption.font())
                .foregroundStyle(theme.colors.foregroundSecondary.resolve(for: scheme))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            HStack(spacing: theme.spacing.md) {
                Button(action: { showTerms = true }) {
                    Text(NSLocalizedString("auth.legal.terms", comment: "Terms"))
                        .underline()
                }
                Button(action: { showPrivacy = true }) {
                    Text(NSLocalizedString("auth.legal.privacy", comment: "Privacy"))
                        .underline()
                }
            }
            .font(theme.typography.caption.font())
            .foregroundStyle(theme.colors.foregroundSecondary.resolve(for: scheme))
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
        }
        .padding(.vertical, theme.spacing.sm)
    }
}
