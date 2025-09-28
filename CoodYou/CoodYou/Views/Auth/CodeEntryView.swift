import SwiftUI
import UIKit

struct CodeEntryView: View {
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var viewModel: AuthShellViewModel
    let namespace: Namespace.ID
    @State private var rawCode = ""
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(spacing: theme.spacing.lg) {
            VStack(alignment: .leading, spacing: theme.spacing.sm) {
                Text(NSLocalizedString("auth.code.title", comment: "Enter code"))
                    .font(theme.typography.titleM.font())
                    .foregroundStyle(theme.colors.foregroundPrimary.resolve(for: scheme))
                    .matchedGeometryEffect(id: "headline", in: namespace)
                Text(String(format: NSLocalizedString("auth.code.subtitle", comment: "Subtitle"), viewModel.email))
                    .font(theme.typography.body.font())
                    .foregroundStyle(theme.colors.foregroundSecondary.resolve(for: scheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: theme.spacing.md) {
                HiddenCodeField(code: $rawCode)
                    .focused($isFieldFocused)
                    .frame(height: 0)
                    .opacity(0)

                HStack(spacing: theme.spacing.sm) {
                    ForEach(0..<6, id: \.self) { index in
                        codeCell(for: index)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    isFieldFocused = true
                }

                if let inlineError = inlineError {
                    ValidationMessageView(message: inlineError)
                }
            }

            PrimaryActionButton(titleKey: "auth.cta.verify", phase: viewModel.buttonPhase, isEnabled: rawCode.count == 6 && !viewModel.isLoading) {
                viewModel.handlePrimaryAction()
            }
            .matchedGeometryEffect(id: "primaryButton", in: namespace)

            VStack(spacing: theme.spacing.sm) {
                Button(action: viewModel.resendCode) {
                    Text(resendLabel)
                        .font(theme.typography.caption.font())
                        .foregroundStyle(theme.colors.foregroundSecondary.resolve(for: scheme))
                }
                .disabled(viewModel.resendCountdown > 0)
                .buttonStyle(.plain)

                HStack(spacing: theme.spacing.sm) {
                    Button(action: openMailApp) {
                        Label(NSLocalizedString("auth.code.openMail", comment: "Open email"), systemImage: "envelope.open")
                            .font(theme.typography.caption.font())
                    }
                    .buttonStyle(.plain)

                    Button(action: pasteCodeFromClipboard) {
                        Label(NSLocalizedString("auth.code.paste", comment: "Paste"), systemImage: "doc.on.clipboard")
                            .font(theme.typography.caption.font())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onAppear {
            rawCode = viewModel.codeDigits.joined()
            isFieldFocused = true
        }
        .onChange(of: rawCode) { newValue in
            syncCode(from: newValue)
        }
        .task(id: viewModel.codeDigits) {
            let joined = viewModel.codeDigits.joined()
            if joined != rawCode {
                rawCode = joined
            }
        }
    }

    private var inlineError: String? {
        if case .codeEntry = viewModel.state {
            return viewModel.inlineError
        }
        return nil
    }

    private func codeCell(for index: Int) -> some View {
        let value = viewModel.codeDigits[index]
        return Text(value)
            .font(.system(size: 24, weight: .semibold, design: .rounded))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(codeBackground)
            .clipShape(RoundedRectangle(cornerRadius: theme.radius.control, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: theme.radius.control, style: .continuous)
                    .stroke(borderColor(for: index), lineWidth: 1.5)
            )
            .animation(reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.7), value: value)
    }

    private var codeBackground: some View {
        RoundedRectangle(cornerRadius: theme.radius.control, style: .continuous)
            .fill(.thinMaterial)
    }

    private func borderColor(for index: Int) -> Color {
        if let inlineError, !inlineError.isEmpty {
            return theme.colors.accentError.resolve(for: scheme)
        }
        if index == rawCode.count {
            return theme.colors.accentPrimary.resolve(for: scheme)
        }
        return theme.colors.foregroundSecondary.resolve(for: scheme).opacity(0.12)
    }

    private func syncCode(from newValue: String) {
        let digits = newValue.compactMap { $0.wholeNumberValue }.map(String.init).prefix(6)
        var updated = Array(repeating: "", count: 6)
        for (index, char) in digits.enumerated() {
            updated[index] = char
        }
        viewModel.codeDigits = updated
        if digits.count != newValue.count {
            rawCode = digits.joined()
        }
    }

    private var resendLabel: String {
        if viewModel.resendCountdown > 0 {
            return String(format: NSLocalizedString("auth.code.resendIn", comment: "Resend in"), viewModel.resendCountdown)
        }
        return NSLocalizedString("auth.code.resend", comment: "Resend")
    }

    private func openMailApp() {
        guard let url = URL(string: "message://"), UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    private func pasteCodeFromClipboard() {
        if let string = UIPasteboard.general.string {
            viewModel.pasteIntoCode(string)
        }
    }
}

private struct HiddenCodeField: UIViewRepresentable {
    @Binding var code: String

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField(frame: .zero)
        field.keyboardType = .numberPad
        field.textContentType = .oneTimeCode
        field.addTarget(context.coordinator, action: #selector(Coordinator.textChanged), for: .editingChanged)
        field.isHidden = true
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != code {
            uiView.text = code
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(code: $code)
    }

    final class Coordinator: NSObject {
        var code: Binding<String>

        init(code: Binding<String>) {
            self.code = code
        }

        @objc func textChanged(sender: UITextField) {
            code.wrappedValue = sender.text ?? ""
        }
    }
}
