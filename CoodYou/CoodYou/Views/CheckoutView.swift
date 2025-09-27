import SwiftUI

struct CheckoutView: View {
    let hall: DiningHall
    @ObservedObject var viewModel: HomeViewModel
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            List {
                Section(header: Text("Selected items")) {
                    if items.isEmpty {
                        Text("Your order is empty. Add items from the menu to continue.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(items) { item in
                            Text(item.name)
                        }
                        .onDelete { indexSet in
                            let currentItems = items
                            for index in indexSet {
                                viewModel.removeFromCart(currentItems[index])
                            }
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
            }
            .listStyle(.insetGrouped)

            VStack(spacing: 12) {
                if appState.currentUser == nil {
                    Text("Sign in to place an order.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Button {
                    placeOrder()
                } label: {
                    Text("Confirm order • \(viewModel.displayPrice(for: hall))")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(appState.currentUser == nil || items.isEmpty ? Color.gray.opacity(0.3) : Color.accentColor)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .disabled(appState.currentUser == nil || items.isEmpty || viewModel.isPlacingOrder)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(Color(.systemBackground).ignoresSafeArea())
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.selectedHall = hall
        }
    }

    private var items: [CartItem] {
        viewModel.cartItems(for: hall)
    }

    private func placeOrder() {
        guard let user = appState.currentUser else { return }
        Task {
            await viewModel.createOrder(for: user)
            if !viewModel.hasCart(for: hall) {
                dismiss()
            }
        }
    }
}
