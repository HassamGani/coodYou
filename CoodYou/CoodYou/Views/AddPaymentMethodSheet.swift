import PassKit
import SwiftUI

struct AddPaymentMethodSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: PaymentMethodType = .applePay
    @State private var nickname = ""
    @State private var last4 = ""
    @State private var paypalEmail = ""
    @State private var cashTag = ""
    @State private var isDefault = true
    @State private var errorMessage: String?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Payment type") {
                    Picker("Type", selection: $selectedType) {
                        ForEach(PaymentMethodType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                switch selectedType {
                case .applePay:
                    Section(header: Text("Apple Pay"), footer: Text("Double-click the side button to confirm and add Apple Pay as your express checkout option.")) {
                        ApplePayButton { await addApplePayMethod() }
                            .frame(height: 50)
                            .padding(.vertical, 12)
                    }
                case .stripeCard, .card:
                    Section("Card details") {
                        TextField("Card nickname", text: $nickname)
                        TextField("Last 4 digits", text: $last4)
                            .keyboardType(.numberPad)
                    }
                case .paypal:
                    Section("PayPal") {
                        TextField("PayPal email", text: $paypalEmail)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    }
                case .cashApp:
                    Section("Cash App") {
                        TextField("$Cashtag", text: $cashTag)
                            .autocapitalization(.none)
                    }
                }

                if selectedType != .applePay {
                    Section {
                        Toggle("Set as default", isOn: $isDefault)
                    }
                }
            }
            .navigationTitle("Add payment")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if selectedType == .applePay {
                        EmptyView()
                    } else {
                        Button {
                            Task { await saveManualMethod() }
                        } label: {
                            if isSaving {
                                ProgressView()
                            } else {
                                Text("Save")
                            }
                        }
                        .disabled(isSaving || !formIsValid)
                    }
                }
            }
            .alert(item: Binding(
                get: { errorMessage.map(ErrorMessage.init(value:)) },
                set: { errorMessage = $0?.value }
            )) { message in
                Alert(title: Text("Payment"), message: Text(message.value), dismissButton: .default(Text("OK")))
            }
        }
        .presentationDetents([.medium, .large])
        .task {
            isDefault = appState.paymentMethods.isEmpty
        }
    }

    private var formIsValid: Bool {
        switch selectedType {
        case .applePay:
            return true
        case .stripeCard, .card:
            return !nickname.isEmpty && last4.count == 4
        case .paypal:
            return paypalEmail.contains("@")
        case .cashApp:
            return cashTag.starts(with: "$")
        }
    }

    @MainActor
    private func saveManualMethod() async {
        guard let uid = appState.currentUser?.id else { return }
        guard formIsValid else { return }
        isSaving = true
        do {
            let method = PaymentMethod(
                id: UUID().uuidString,
                userId: uid,
                type: selectedType,
                displayName: nickname.isEmpty ? selectedType.displayName : nickname,
                details: detailText,
                last4: selectedType == .card || selectedType == .stripeCard ? last4 : nil,
                isDefault: shouldSetDefault,
                createdAt: Date()
            )
            try await PaymentService.shared.addPaymentMethod(method, for: uid)
            if shouldSetDefault {
                appState.currentUser?.defaultPaymentMethodId = method.id
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }

    private var shouldSetDefault: Bool {
        if !appState.paymentMethods.isEmpty {
            return isDefault
        }
        return true
    }

    private var detailText: String? {
        switch selectedType {
        case .applePay:
            return "Express checkout enabled"
        case .stripeCard, .card:
            return nickname.isEmpty ? "Saved card" : nickname
        case .paypal:
            return paypalEmail
        case .cashApp:
            return cashTag
        }
    }

    @MainActor
    private func addApplePayMethod() async {
        guard let uid = appState.currentUser?.id else { return }
        let coordinator = ApplePayCoordinator()
        do {
            let payment = try await coordinator.present()
            let displayGivenName = payment.billingContact?.name?.givenName ?? ""
            let method = PaymentMethod(
                id: UUID().uuidString,
                userId: uid,
                type: .applePay,
                displayName: "Apple Pay",
                details: displayGivenName.isEmpty ? "Linked via Apple Pay" : "Linked for \(displayGivenName)",
                last4: nil,
                isDefault: true,
                createdAt: Date()
            )
            try await PaymentService.shared.addPaymentMethod(method, for: uid)
            await MainActor.run {
                appState.currentUser?.defaultPaymentMethodId = method.id
            }
            dismiss()
        } catch ApplePayCoordinator.Error.cancelled {
            // silently ignore
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ApplePayButton: UIViewRepresentable {
    let action: () async -> Void

    func makeUIView(context: Context) -> PKPaymentButton {
        let button = PKPaymentButton(paymentButtonType: .plain, paymentButtonStyle: .black)
        button.addTarget(context.coordinator, action: #selector(Coordinator.didTap), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: PKPaymentButton, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    final class Coordinator: NSObject {
        let action: () async -> Void

        init(action: @escaping () async -> Void) {
            self.action = action
        }

        @objc func didTap() {
            Task { await action() }
        }
    }
}

private final class ApplePayCoordinator: NSObject, PKPaymentAuthorizationControllerDelegate {
    enum Error: Swift.Error, LocalizedError {
        case unavailable
        case cancelled

        var errorDescription: String? {
            switch self {
            case .unavailable:
                return "Apple Pay is not available on this device."
            case .cancelled:
                return "Apple Pay was cancelled."
            }
        }
    }

    private var continuation: CheckedContinuation<PKPayment, Swift.Error>?

    func present() async throws -> PKPayment {
        guard PKPaymentAuthorizationController.canMakePayments() else {
            throw Error.unavailable
        }

        let request = PKPaymentRequest()
        request.merchantIdentifier = "merchant.com.campusdash"
        request.supportedNetworks = [.visa, .masterCard, .amex]
        request.merchantCapabilities = [.capability3DS]
        request.countryCode = "US"
        request.currencyCode = "USD"
        request.paymentSummaryItems = [
            PKPaymentSummaryItem(label: "CampusDash Express", amount: NSDecimalNumber(string: "0.00"))
        ]

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let controller = PKPaymentAuthorizationController(paymentRequest: request)
            controller.delegate = self
            controller.present { presented in
                if !presented {
                    continuation.resume(throwing: Error.unavailable)
                    self.continuation = nil
                }
            }
        }
    }

    func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        controller.dismiss {
            if let continuation = self.continuation {
                continuation.resume(throwing: Error.cancelled)
                self.continuation = nil
            }
        }
    }

    func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController,
                                         didAuthorizePayment payment: PKPayment,
                                         handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
        completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
        continuation?.resume(returning: payment)
        continuation = nil
    }
}
