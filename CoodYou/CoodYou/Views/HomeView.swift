import SwiftUI
import MapKit

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = HomeViewModel()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 40.8075, longitude: -73.9641),
        span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
    )
    @State private var showingHandoff = false
    @State private var detailHall: DiningHall?
    @State private var checkoutHall: DiningHall?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                mapLayer
                VStack(spacing: 20) {
                    if let order = viewModel.activeOrder, !order.isTerminal {
                        ActiveOrderCard(order: order,
                                        hall: viewModel.selectedHall,
                                        viewModel: viewModel,
                                        showingHandoff: $showingHandoff)
                            .padding(.horizontal, 20)
                    }
                    hallDirectoryCard
                        .padding(.horizontal, 20)
                    Spacer()
                }
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .navigationTitle("CampusDash")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingHandoff) {
            if let order = viewModel.activeOrder {
                HandoffView(order: order, run: nil)
                    .environmentObject(appState)
            }
        }
        .sheet(item: $detailHall) { hall in
            NavigationStack {
                DiningHallDetailView(hall: hall,
                                     viewModel: viewModel,
                                     checkoutHall: $checkoutHall)
                    .navigationTitle(hall.name)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Close") { detailHall = nil }
                        }
                    }
            }
        }
        .sheet(item: $checkoutHall) { hall in
            NavigationStack {
                CheckoutView(hall: hall, viewModel: viewModel)
                    .environmentObject(appState)
                    .navigationTitle("Checkout")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { checkoutHall = nil }
                        }
                    }
            }
        }
        .task {
            if let user = appState.currentUser {
                viewModel.bindOrders(for: user.id)
            }
            viewModel.subscribeToPool()
            if let hall = viewModel.selectedHall {
                region.center = hall.coordinate
            }
        }
        .onChange(of: appState.currentUser?.id) { _, newValue in
            guard let newValue else { return }
            viewModel.bindOrders(for: newValue)
        }
        .onChange(of: viewModel.selectedHall) { _, hall in
            guard let hall else { return }
            withAnimation(.easeInOut(duration: 0.4)) {
                region.center = hall.coordinate
            }
            viewModel.subscribeToPool()
        }
        .alert(item: Binding(
            get: { viewModel.errorMessage.map(ErrorMessage.init(value:)) },
            set: { viewModel.errorMessage = $0?.value }
        )) { message in
            Alert(title: Text("Error"), message: Text(message.value), dismissButton: .default(Text("OK")))
        }
    }

    private var mapLayer: some View {
        Map(
            coordinateRegion: $region,
            interactionModes: [.zoom, .pan],
            showsUserLocation: true,
            annotationItems: viewModel.selectedHall.map { [$0] } ?? []
        ) { hall in
            MapAnnotation(coordinate: hall.coordinate) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 20, height: 20)
                    
                    Image(systemName: "fork.knife")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .ignoresSafeArea()
        .overlay(alignment: .topTrailing) {
            if let livePool = viewModel.livePool {
                VStack(alignment: .trailing, spacing: 12) {
                    pillView(icon: "person.3.fill", title: "Pool", value: "\(livePool.queueSize) waiting")
                    let minutes = max(1, Int(livePool.averageWaitSeconds / 60))
                    pillView(icon: "clock", title: "ETA", value: "~\(minutes) min")
                }
                .padding(.top, 80)
                .padding(.trailing, 16)
            }
        }
    }

    private var hallDirectoryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Dining halls")
                        .font(.title3.weight(.semibold))
                    Text("Tap a hall to explore the live menu and start an order.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(viewModel.sortedHalls) { hall in
                        Button {
                            viewModel.selectedHall = hall
                            detailHall = hall
                        } label: {
                            hallRow(for: hall)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 380)
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 20, y: 10)
    }

    private func hallRow(for hall: DiningHall) -> some View {
        let status = viewModel.status(for: hall)
        return HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(hall.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(hall.affiliation == .columbia ? "Columbia" : "Barnard")
                        .font(.caption.weight(.semibold))
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(hall.affiliation == .columbia ? Color.blue.opacity(0.15) : Color.purple.opacity(0.15), in: Capsule())
                        .foregroundStyle(hall.affiliation == .columbia ? Color.blue : Color.purple)
                }
                if let current = status.currentPeriodName {
                    Text(current)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                Text(status.statusMessage ?? (status.isOpen ? "Open" : "Closed"))
                    .font(.footnote)
                    .foregroundStyle(status.isOpen ? .green : .secondary)
                Text(hall.address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.9))
        )
    }

    private func pillView(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct ActiveOrderCard: View {
    let order: Order
    let hall: DiningHall?
    @ObservedObject var viewModel: HomeViewModel
    @Binding var showingHandoff: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Order in progress")
                        .font(.headline)
                    Text(order.status.buyerFacingLabel)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let hall {
                    Text(hall.name)
                        .font(.caption)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color.accentColor.opacity(0.1), in: Capsule())
                }
            }

            ProgressView(value: order.status.progressValue)
                .tint(.accentColor)

            if !order.pinCode.isEmpty && order.status != .requested && order.status != .pooled {
                HStack {
                    Label("Pickup PIN", systemImage: "key.fill")
                    Spacer()
                    Text(order.pinCode)
                        .font(.title3.weight(.semibold))
                }
            }

            Button {
                showingHandoff = true
            } label: {
                Text("View status & chat")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            Button(role: .destructive) {
                Task { await viewModel.cancelActiveOrder(order) }
            } label: {
                Text("Cancel request")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .foregroundStyle(.red)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.red.opacity(0.8), lineWidth: 1.5)
                    )
            }
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 20, y: 10)
    }
}

private extension OrderStatus {
    var progressValue: Double {
        switch self {
        case .requested: return 0.1
        case .pooled: return 0.25
        case .readyToAssign: return 0.4
        case .claimed: return 0.6
        case .inProgress: return 0.8
        case .delivered, .paid, .closed: return 1
        case .expired, .cancelledBuyer, .cancelledDasher, .disputed: return 0.5
        }
    }
}
