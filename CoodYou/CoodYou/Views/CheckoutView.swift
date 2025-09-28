import SwiftUI

struct CheckoutView: View {
    let hall: DiningHall
    @ObservedObject var viewModel: HomeViewModel
    @EnvironmentObject private var appState: AppState
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @Environment(\.dismiss) private var dismiss
    @State private var deliveryNote: String = ""
    @State private var showingAddPayment: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            List {
                Section(header: Text("Selected items")) {
                    if items.isEmpty {
                        Text("Your order is empty. Add items from the menu to continue.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(lineItems) { item in
                            HStack {
                                Text(item.name)
                                Spacer()
                                if item.quantity > 1 {
                                    Text("×\(item.quantity)")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            let current = lineItems
                            for index in indexSet {
                                let item = current[index]
                                viewModel.removeLineItem(item, from: hall)
                            }
                            deliveryNote = viewModel.cartNote(for: hall)
                        }
                    }
                }

                Section(header: Text("Summary")) {
                    HStack {
                        Text("Split meal price")
                        Spacer()
                        Text(viewModel.splitPriceLabel(for: hall))
                    }
                    HStack {
                        Text("CampusDash fee")
                        Spacer()
                        Text("$0.50")
                    }
                    Divider()
                    HStack {
                        Text("You pay today")
                            .font(.headline)
                        Spacer()
                        Text(viewModel.displayPrice(for: hall))
                            .font(.headline)
                    }
                }

                Section(header: Text("Pickup")) {
                    Text("Meet your dasher near \(hall.name) — we’ll coordinate the exact handoff point once a dasher accepts.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section(header: Text("Dasher instructions")) {
                    TextField("Add extra details (allergies, meet-up notes)…", text: $deliveryNote, axis: .vertical)
                        .textInputAutocapitalization(.sentences)
                        .lineLimit(3...8)
                    Text("Optional: keep it concise so your dasher can scan it quickly.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .listStyle(.insetGrouped)

            VStack(spacing: 12) {
                if !networkMonitor.isConnected {
                    HStack {
                        Image(systemName: "wifi.slash")
                            .foregroundColor(.orange)
                        Text("No internet connection")
                            .font(.footnote)
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal)
                }
                
                if appState.currentUser == nil {
                    Text("Sign in to place an order.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Button {
                    confirmButtonTapped()
                } label: {
                    HStack {
                        if viewModel.isPlacingOrder {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                            Text("Placing order...")
                                .font(.headline)
                        } else {
                            Text("Confirm order • \(viewModel.displayPrice(for: hall))")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isOrderingDisabled ? Color.gray.opacity(0.3) : Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .disabled(isOrderingDisabled)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(Color(.systemBackground).ignoresSafeArea())
            .overlay {
                if viewModel.isPlacingOrder {
                    ZStack {
                        Color.black.opacity(0.35).ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.2)
                            Text("Searching for dashers...")
                                .foregroundColor(.white)
                                .font(.headline)
                        }
                        .padding(24)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.selectedHall = hall
            deliveryNote = viewModel.cartNote(for: hall)
        }
        .sheet(isPresented: $showingAddPayment) {
            AddPaymentMethodSheet()
                .environmentObject(appState)
        }
        .onChange(of: deliveryNote) { note in
            viewModel.updateCartNote(note, for: hall)
        }
        .onDisappear {
            viewModel.updateCartNote(deliveryNote, for: hall)
        }
    }

    private var items: [CartItem] {
        viewModel.cartItems(for: hall)
    }

    private var lineItems: [OrderLineItem] {
        viewModel.draftLineItems(for: hall)
    }
    
    private var isOrderingDisabled: Bool {
        appState.currentUser == nil || 
        items.isEmpty || 
        viewModel.isPlacingOrder || 
        !networkMonitor.isConnected
    }

    private func placeOrder() {
        guard let user = appState.currentUser else { return }
        viewModel.updateCartNote(deliveryNote, for: hall)
        Task {
            await viewModel.createOrder(for: user)
            await MainActor.run {
                if !viewModel.hasCart(for: hall) {
                    // Success - show confirmation and dismiss
                    dismiss()
                }
                // Error handling is already managed by HomeViewModel.errorMessage
            }
        }
    }

    private func confirmButtonTapped() {
        // If user has no saved payment methods, prompt to add one first
        if appState.paymentMethods.isEmpty {
            showingAddPayment = true
            return
        }
        placeOrder()
    }

}
