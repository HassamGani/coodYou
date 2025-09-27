import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var diningHalls: [DiningHall] = []
    @Published var selectedHall: DiningHall?
    @Published var selectedWindow: ServiceWindowType = .current
    @Published var livePool: LivePoolSnapshot?
    @Published var activeOrder: Order?
    @Published var isPlacingOrder = false
    @Published var errorMessage: String?

    private let orderService = OrderService.shared
    private let manager = FirebaseManager.shared
    private var cancellables: Set<AnyCancellable> = []
    private var ordersTask: Task<Void, Never>?

    init() {
        Task { await loadDiningHalls() }
    }

    deinit {
        ordersTask?.cancel()
        orderService.stopListening()
    }

    var displayWindow: ServiceWindowType {
        selectedWindow == .current ? ServiceWindowType.determineWindow(config: .default) : selectedWindow
    }

    var primaryCtaLabel: String {
        guard let hall = selectedHall else { return "Select a hall" }
        let price = price(for: hall, window: displayWindow, soloFallback: false)
        return String(format: "Request %@ · $%.2f", displayWindow.rawValue.capitalized, price)
    }

    var canOfferSoloFallback: Bool {
        livePool?.queueSize ?? 0 > 0
    }

    func soloFallbackLabel(for hall: DiningHall?) -> String {
        guard let hall else { return "Solo request" }
        let price = soloPrice(for: hall)
        return String(format: "Solo delivery instead · $%.2f", price)
    }

    func soloPrice(for hall: DiningHall?) -> Double {
        guard let hall else { return 0 }
        return price(for: hall, window: displayWindow, soloFallback: true)
    }

    func displayPrice(for hall: DiningHall) -> String {
        let price = price(for: hall, window: displayWindow, soloFallback: false)
        return String(format: "$%.2f", price)
    }

    func splitPriceLabel(for hall: DiningHall) -> String {
        let actual = price(for: hall, window: displayWindow, soloFallback: false) - 0.50
        return String(format: "$%.2f", actual)
    }

    func orderPitch(for hall: DiningHall?) -> String {
        guard let hall else { return "Pick a dining hall to see active dashers and live timing." }
        return "Dashers currently in \(hall.name) can grab your meal in minutes. Pair with a nearby student to split the price."
    }

    func loadDiningHalls() async {
        do {
            let snapshot = try await manager.db.collection("dining_halls").whereField("active", isEqualTo: true).getDocuments()
            let halls = try snapshot.documents.map { doc -> DiningHall in
                let data = doc.data()
                return DiningHall(
                    id: doc.documentID,
                    name: data["name"] as? String ?? "",
                    campus: data["campus"] as? String ?? "",
                    latitude: data["latitude"] as? Double ?? 0,
                    longitude: data["longitude"] as? Double ?? 0,
                    active: data["active"] as? Bool ?? false,
                    price: DiningHallPrice(
                        breakfast: data["price_breakfast"] as? Double ?? 0,
                        lunch: data["price_lunch"] as? Double ?? 0,
                        dinner: data["price_dinner"] as? Double ?? 0
                    ),
                    geofenceRadius: data["geofenceRadius"] as? Double ?? 75
                )
            }
            diningHalls = halls
            if selectedHall == nil {
                selectedHall = halls.first
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func subscribeToPool() {
        guard let hall = selectedHall else { return }
        orderService.startListeningToPool(hallId: hall.id, window: displayWindow)
        cancellables.removeAll()
        orderService.$livePools
            .receive(on: RunLoop.main)
            .sink { [weak self] pools in
                self?.livePool = pools.first
            }
            .store(in: &cancellables)
    }

    func bindOrders(for uid: String) {
        ordersTask?.cancel()
        ordersTask = Task {
            do {
                for try await orders in orderService.subscribeToOrders(uid: uid) {
                    let active = orders
                        .filter { !$0.isTerminal }
                        .sorted(by: { $0.createdAt > $1.createdAt })
                        .first
                    await MainActor.run {
                        self.activeOrder = active
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func createOrder(for user: UserProfile, isSoloFallback: Bool = false) async {
        guard let hall = selectedHall else { return }
        isPlacingOrder = true
        defer { isPlacingOrder = false }

        let price = price(for: hall, window: displayWindow, soloFallback: isSoloFallback)
        let order = Order(
            id: UUID().uuidString,
            userId: user.id,
            hallId: hall.id,
            status: .requested,
            windowType: displayWindow,
            priceCents: Int(price * 100),
            createdAt: Date(),
            pairGroupId: nil,
            meetPoint: nil,
            pinCode: String(UUID().uuidString.prefix(6)),
            isSoloFallback: isSoloFallback
        )

        do {
            try await orderService.createOrder(order)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancelActiveOrder(_ order: Order) async {
        do {
            try await orderService.cancelOrder(orderId: order.id)
            activeOrder = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func price(for hall: DiningHall, window: ServiceWindowType, soloFallback: Bool) -> Double {
        let actualWindow = window == .current ? ServiceWindowType.determineWindow(config: .default) : window
        let basePrice: Double
        switch actualWindow {
        case .breakfast: basePrice = hall.price.breakfast
        case .lunch: basePrice = hall.price.lunch
        case .dinner: basePrice = hall.price.dinner
        case .current: basePrice = hall.price.lunch
        }
        if soloFallback {
            return basePrice * 0.75 + 0.50
        }
        return basePrice / 2 + 0.50
    }
}
