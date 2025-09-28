import Foundation
import Foundation
import FirebaseFirestore

@MainActor
final class OrdersViewModel: ObservableObject {
    @Published var pastOrders: [Order] = []
    @Published var activeOrder: Order?
    @Published var errorMessage: String?
    @Published var isCancelling: Bool = false

    private var listener: ListenerRegistration?
    private var notificationObserver: NSObjectProtocol?

    /// Start listening for orders for the given user id. Pass `nil` to clear listeners.
    func start(uid: String?) async {
        listener?.remove()
        guard let uid = uid else {
            self.pastOrders = []
            self.activeOrder = nil
            return
        }

        let query = FirebaseManager.shared.db.collection("orders")
            .whereField("userId", isEqualTo: uid)
            .order(by: "createdAt", descending: true)

        listener = query.addSnapshotListener { [weak self] (snapshot: QuerySnapshot?, error: Error?) in
            guard let self = self else { return }
            if let error = error {
                Task { @MainActor in self.errorMessage = error.localizedDescription }
                return
            }
            guard let snapshot = snapshot else { return }
            do {
                var orders = try snapshot.documents.map { try $0.data(as: Order.self) }
                // Defensive de-duplication in case the snapshot contains duplicate docs
                let unique = Dictionary(uniqueKeysWithValues: orders.map { ($0.id, $0) }).map { $0.value }
                orders = unique.sorted { $0.createdAt > $1.createdAt }

                #if DEBUG
                // Log statuses so we can observe why cancelled orders appear where they shouldn't
                let statusLog = orders.map { "\($0.id):\($0.status.rawValue)" }.joined(separator: ", ")
                print("[DEBUG][OrdersViewModel] snapshot orders count=\(orders.count) statuses=[\(statusLog)]")
                #endif

                Task { @MainActor in
                    // Past orders are terminal statuses (paid/closed/cancelled/expired/etc.)
                    self.pastOrders = orders.filter { $0.isTerminal }

                    // Active order must explicitly exclude any cancelled-like statuses; this is defensive
                    let activeCandidates = orders.filter { order in
                        switch order.status {
                        case .cancelledBuyer, .cancelledDasher, .paid, .closed, .expired, .disputed:
                            return false
                        default:
                            return true
                        }
                    }
                    self.activeOrder = activeCandidates.sorted { $0.createdAt > $1.createdAt }.first
                }
            } catch {
                Task { @MainActor in self.errorMessage = error.localizedDescription }
            }
        }
    }

    init() {
        // Observe immediate cancel notifications so the Orders UI reflects the cancellation
        notificationObserver = NotificationCenter.default.addObserver(forName: .orderWasCancelled, object: nil, queue: .main) { [weak self] note in
            guard let self = self else { return }
            if let orderId = note.userInfo?["orderId"] as? String {
                // If the cancelled order was our active order, move it into pastOrders immediately.
                if self.activeOrder?.id == orderId {
                    if let act = self.activeOrder {
                        self.pastOrders.insert(act, at: 0)
                    }
                    self.activeOrder = nil
                }
            }
        }
    }

    deinit {
        listener?.remove()
        if let obs = notificationObserver { NotificationCenter.default.removeObserver(obs) }
    }

    /// Cancel the currently active order (if any).
    func cancelActiveOrder() async {
        guard let orderId = activeOrder?.id else { return }
        isCancelling = true
        defer { isCancelling = false }
        do {
            try await OrderService.shared.cancelOrder(orderId: orderId)
        } catch {
            Task { @MainActor in
                self.errorMessage = error.localizedDescription
            }
        }
    }
}
