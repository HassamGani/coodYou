import SwiftUI

struct OrdersView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = OrdersViewModel()

    var body: some View {
        NavigationStack {
            List {
                if let active = viewModel.activeOrder {
                    Section("Current order") {
                        OrderRow(order: active)
                        // Show cancel button when order is still cancellable
                        if active.status == .requested || active.status == .pooled {
                            HStack {
                                Spacer()
                                Button(role: .destructive) {
                                    Task {
                                        await viewModel.cancelActiveOrder()
                                    }
                                } label: {
                                    if viewModel.isCancelling {
                                        ProgressView()
                                    } else {
                                        Text("Cancel order")
                                    }
                                }
                                Spacer()
                            }
                        }
                    }
                }

                Section("Past orders") {
                    if viewModel.pastOrders.isEmpty {
                        Text("You haven't placed any orders yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.pastOrders) { order in
                            OrderRow(order: order)
                        }
                    }
                }
            }
            .navigationTitle("Orders")
            .listStyle(.insetGrouped)
            .task {
                await viewModel.start(uid: appState.currentUser?.id)
            }
            .refreshable {
                await viewModel.start(uid: appState.currentUser?.id)
            }
            .onChange(of: appState.currentUser?.id) { _, newValue in
                Task { await viewModel.start(uid: newValue) }
            }
        }
    }
}

struct OrderRow: View {
    let order: Order

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(order.lineItems?.map { "\($0.quantity)x \($0.name)" }.joined(separator: ", ") ?? "Order")
                    .font(.subheadline.weight(.semibold))
                timestampView
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "$%.2f", Double(order.priceCents) / 100.0))
                    .font(.subheadline)
                Text(order.status.rawValue.capitalized)
                    .font(.caption)
                    .foregroundStyle(order.isTerminal ? .secondary : Color.accentColor)
            }
        }
        .padding(.vertical, 8)
    }

    private var timestampView: some View {
        Group {
            if order.isTerminal {
                Text(order.createdAt.formatted(date: .abbreviated, time: .shortened))
            } else {
                Text(order.createdAt, style: .relative)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

struct OrdersView_Previews: PreviewProvider {
    static var previews: some View {
        OrdersView()
    }
}
