import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var diningHalls: [DiningHall] = []
    @Published var selectedHall: DiningHall?
    @Published var selectedWindow: ServiceWindowType = .current
    @Published var livePool: LivePoolSnapshot?
    @Published var isPlacingOrder = false
    @Published var errorMessage: String?

    private let orderService = OrderService.shared
    private let manager = FirebaseManager.shared
    private var cancellables: Set<AnyCancellable> = []

    init() {
        Task { await loadDiningHalls() }
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
            selectedHall = halls.first
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func subscribeToPool() {
        guard let hall = selectedHall else { return }
        orderService.startListeningToPool(hallId: hall.id, window: selectedWindow)
        cancellables.removeAll()
        orderService.$livePools
            .receive(on: RunLoop.main)
            .sink { [weak self] pools in
                self?.livePool = pools.first
            }
            .store(in: &cancellables)
    }

    func createOrder(for user: UserProfile, isSoloFallback: Bool = false) async {
        guard let hall = selectedHall else { return }
        isPlacingOrder = true
        defer { isPlacingOrder = false }

        let price = price(for: hall, window: selectedWindow, soloFallback: isSoloFallback)
        let order = Order(
            id: UUID().uuidString,
            userId: user.id,
            hallId: hall.id,
            status: .requested,
            windowType: selectedWindow == .current ? ServiceWindowType.determineWindow(config: .default) : selectedWindow,
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
