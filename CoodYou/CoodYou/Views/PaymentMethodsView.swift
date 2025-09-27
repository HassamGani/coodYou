import SwiftUI

struct PaymentMethodsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showingAddSheet = false
    @State private var errorMessage: String?
    @State private var isSettingDefault = false

    private var defaultMethodId: String? {
        appState.currentUser?.defaultPaymentMethodId
    }

    var body: some View {
        List {
            if appState.paymentMethods.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "creditcard")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No payment methods yet")
                        .font(.headline)
                    Text("Add Apple Pay, Stripe, PayPal, Cash App, or a saved card to pay classmates or receive refunds.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ForEach(appState.paymentMethods, id: \.id) { method in
                    PaymentMethodRow(method: method, isDefault: method.id == defaultMethodId)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { Task { await delete(method) } } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            if method.id != defaultMethodId {
                                Button {
                                    Task { await setDefault(method) }
                                } label: {
                                    Label("Default", systemImage: "star.fill")
                                }
                                .tint(.yellow)
                            }
                        }
                }
            }
        }
        .navigationTitle("Payment methods")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddPaymentMethodSheet()
        }
        .alert(item: Binding(
            get: { errorMessage.map(ErrorMessage.init(value:)) },
            set: { errorMessage = $0?.value }
        )) { message in
            Alert(title: Text("Payment methods"), message: Text(message.value), dismissButton: .default(Text("OK")))
        }
    }

    @MainActor
    private func delete(_ method: PaymentMethod) async {
        guard let uid = appState.currentUser?.id else { return }
        do {
            try await PaymentService.shared.deletePaymentMethod(method.id, for: uid)
            if method.id == defaultMethodId {
                let nextDefault = appState.paymentMethods.first { $0.id != method.id }
                try await PaymentService.shared.setDefaultPaymentMethod(nextDefault?.id, for: uid)
                await MainActor.run {
                    appState.currentUser?.defaultPaymentMethodId = nextDefault?.id
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func setDefault(_ method: PaymentMethod) async {
        guard let uid = appState.currentUser?.id else { return }
        if isSettingDefault { return }
        isSettingDefault = true
        do {
            try await PaymentService.shared.setDefaultPaymentMethod(method.id, for: uid)
            await MainActor.run {
                appState.currentUser?.defaultPaymentMethodId = method.id
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isSettingDefault = false
    }
}

private struct PaymentMethodRow: View {
    let method: PaymentMethod
    let isDefault: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(method.displayName, systemImage: icon)
                    .font(.headline)
                Spacer()
                if isDefault {
                    Text("Default")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.2), in: Capsule())
                }
            }
            if let details = method.details, !details.isEmpty {
                Text(details)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let last4 = method.last4 {
                Text("•••• \(last4)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 12)
    }

    private var icon: String {
        switch method.type {
        case .stripeCard, .card:
            return "creditcard.fill"
        case .applePay:
            return "apple.logo"
        case .paypal:
            return "p.circle.fill"
        case .cashApp:
            return "dollarsign.circle.fill"
        }
    }
}
