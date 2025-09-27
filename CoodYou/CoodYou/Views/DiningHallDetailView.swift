import SwiftUI

struct DiningHallDetailView: View {
    let hall: DiningHall
    @ObservedObject var viewModel: HomeViewModel
    @Binding var checkoutHall: DiningHall?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                menuContent
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 80)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .task {
            await viewModel.loadMenuIfNeeded(for: hall)
            viewModel.selectedHall = hall
        }
        .safeAreaInset(edge: .bottom) {
            if viewModel.hasCart(for: hall) {
                checkoutBar
            }
        }
    }

    private var header: some View {
        let status = viewModel.status(for: hall)
        return VStack(alignment: .leading, spacing: 8) {
            Text(status.currentPeriodName ?? "Service window")
                .font(.title3.weight(.semibold))
            if let range = status.periodRangeText {
                Text(range)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text(status.statusMessage ?? (status.isOpen ? "Open" : "Closed"))
                .font(.footnote)
                .foregroundStyle(status.isOpen ? .green : .secondary)
        }
    }

    @ViewBuilder
    private var menuContent: some View {
        if viewModel.isLoadingMenu(for: hall), viewModel.menu(for: hall) == nil {
            ProgressView("Fetching menu…")
                .frame(maxWidth: .infinity, alignment: .center)
        } else if let error = viewModel.menuError(for: hall) {
            ContentUnavailableView("Menu unavailable", systemImage: "exclamationmark.triangle", description: Text(error))
        } else if let menu = viewModel.menu(for: hall) {
            if menu.isComingSoon {
                ContentUnavailableView("Coming soon", systemImage: "sparkles", description: Text("This dining hall will publish menus here shortly."))
            } else if menu.stations.isEmpty {
                ContentUnavailableView("No items", systemImage: "leaf", description: Text("We couldn’t find items for the current meal period."))
            } else {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(menu.stations) { station in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(station.name)
                                .font(.headline)
                            ForEach(station.items) { item in
                                MenuItemRow(item: item, addAction: {
                                    viewModel.addToCart(item: item, hall: hall)
                                })
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color(.systemBackground))
                        )
                    }
                }
            }
        } else {
            ContentUnavailableView("Menu unavailable", systemImage: "exclamationmark.triangle", description: Text("Please try again later."))
        }
    }

    private var checkoutBar: some View {
        VStack(spacing: 12) {
            Divider()
            HStack {
                Text("\(viewModel.cartCount(for: hall)) item(s) ready")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    checkoutHall = hall
                } label: {
                    Text("Checkout")
                        .font(.headline)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 24)
                        .frame(maxWidth: .infinity)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .background(.ultraThinMaterial)
    }
}

private struct MenuItemRow: View {
    let item: DiningHallMenu.MenuItem
    let addAction: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.subheadline)
            }
            Spacer()
            Button(action: addAction) {
                Text("Add to order")
                    .font(.footnote.weight(.semibold))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Color.accentColor.opacity(0.1), in: Capsule())
            }
        }
        .padding(.vertical, 6)
    }
}
