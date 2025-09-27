import SwiftUI
import MapKit

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = HomeViewModel()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 40.8075, longitude: -73.9641),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var showingHandoff = false

    private var hallAnnotations: [DiningHall] {
        viewModel.selectedHall.map { [$0] } ?? []
    }

    var body: some View {
        ZStack(alignment: .top) {
            mapLayer
            VStack(spacing: 20) {
                headerCard
                Spacer()
                bottomCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .navigationBarHidden(true)
        .background(Color(.systemBackground))
        .sheet(isPresented: $showingHandoff) {
            if let order = viewModel.activeOrder {
                HandoffView(order: order, run: nil)
                    .environmentObject(appState)
            }
        }
        .onChange(of: viewModel.selectedHall) { _, hall in
            guard let hall else { return }
            withAnimation(.easeInOut(duration: 0.6)) {
                region.center = hall.coordinate
            }
            appState.activeDiningHall = hall
            viewModel.subscribeToPool()
        }
        .onChange(of: viewModel.selectedWindow) { _, window in
            appState.activeWindow = window
            viewModel.subscribeToPool()
        }
        .task {
            viewModel.subscribeToPool()
            if let hall = viewModel.selectedHall {
                region.center = hall.coordinate
            }
            if let user = appState.currentUser {
                viewModel.bindOrders(for: user.id)
            }
        }
        .onChange(of: appState.currentUser?.id) { _, newValue in
            guard let newValue else { return }
            viewModel.bindOrders(for: newValue)
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
            userTrackingMode: .constant(.follow),
            annotationItems: hallAnnotations
        ) { hall in
            MapMarker(coordinate: hall.coordinate, tint: .accentColor)
        }
        .ignoresSafeArea()
        .overlay(alignment: .topTrailing) {
            VStack(alignment: .trailing, spacing: 12) {
                if let livePool = viewModel.livePool {
                    pillView(icon: "person.3.fill", title: "Pool", value: "\(livePool.queueSize) waiting")
                    pillView(icon: "clock", title: "ETA", value: "\(Int(max(1, livePool.averageWaitSeconds / 60))) min")
                }
            }
            .padding(.top, 80)
            .padding(.trailing, 16)
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.selectedHall?.name ?? "Select a hall")
                        .font(.headline)
                    Text(viewModel.selectedHall?.campus ?? "Campus")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    Picker("Dining Hall", selection: $viewModel.selectedHall) {
                        ForEach(viewModel.diningHalls, id: \.id) { hall in
                            Text(hall.name).tag(Optional(hall))
                        }
                    }
                } label: {
                    Label("Change", systemImage: "line.3.horizontal.circle")
                        .labelStyle(.iconOnly)
                        .font(.title3)
                        .padding(8)
                        .background(.thinMaterial, in: Circle())
                }
            }

            windowSelector

            if let livePool = viewModel.livePool {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pairs forming now")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(poolSummaryText(livePool))
                            .font(.title3.weight(.semibold))
                    }
                    Spacer()
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(.secondary)
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                }
            } else {
                ProgressView("Fetching live queue…")
                    .font(.footnote)
            }
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 24, y: 12)
    }

    private var windowSelector: some View {
        HStack(spacing: 8) {
            ForEach(ServiceWindowType.allCases.filter { $0 != .current }, id: \.self) { window in
                let isSelected = viewModel.displayWindow == window
                Button {
                    viewModel.selectedWindow = window
                } label: {
                    Text(window.rawValue.capitalized)
                        .font(.subheadline.weight(.semibold))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(isSelected ? Color.accentColor : Color(.systemBackground))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.accentColor.opacity(isSelected ? 0 : 0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var bottomCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let order = viewModel.activeOrder, !order.isTerminal {
                ActiveOrderCard(order: order,
                                hall: viewModel.selectedHall,
                                viewModel: viewModel,
                                showingHandoff: $showingHandoff)
            } else {
                Text("Ready to eat?")
                    .font(.title2.weight(.bold))
                Text(viewModel.orderPitch(for: viewModel.selectedHall))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                priceBreakdown
                orderButtons
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 24, y: -6)
        )
    }

    private var priceBreakdown: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let hall = viewModel.selectedHall {
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
            } else {
                Text("Choose a dining hall to see pricing")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var orderButtons: some View {
        VStack(spacing: 12) {
            Button {
                placeOrder(isSoloFallback: false)
            } label: {
                Text(viewModel.primaryCtaLabel)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(viewModel.isPlacingOrder || appState.currentUser == nil)

            Button {
                placeOrder(isSoloFallback: true)
            } label: {
                Text(viewModel.soloFallbackLabel(for: viewModel.selectedHall))
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .foregroundStyle(Color.accentColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.accentColor, lineWidth: 1.5)
                    )
            }
            .disabled(viewModel.isPlacingOrder || viewModel.selectedHall == nil || !viewModel.canOfferSoloFallback)
            .opacity(viewModel.canOfferSoloFallback ? 1 : 0.4)
        }
    }

    private func placeOrder(isSoloFallback: Bool) {
        guard let user = appState.currentUser else { return }
        Task {
            await viewModel.createOrder(for: user, isSoloFallback: isSoloFallback)
        }
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

    private func poolSummaryText(_ snapshot: LivePoolSnapshot) -> String {
        let waitMinutes = Int(max(1, snapshot.averageWaitSeconds / 60))
        return "\(snapshot.queueSize) waiting · ~\(waitMinutes) min"
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
