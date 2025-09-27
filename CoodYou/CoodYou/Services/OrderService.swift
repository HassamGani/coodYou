import Foundation
import FirebaseFirestore

final class OrderService: ObservableObject {
    static let shared = OrderService()
    private let manager = FirebaseManager.shared
    private var listener: ListenerRegistration?

    @Published private(set) var livePools: [LivePoolSnapshot] = []

    private init() {}

    func startListeningToPool(hallId: String, window: ServiceWindowType) {
        stopListening()
        listener = manager.db.collection("hallPools")
            .document("\(hallId)_\(window.rawValue)")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let data = try? snapshot?.data(as: LivePoolSnapshot.self), error == nil else {
                    return
                }
                Task { @MainActor in
                    self?.livePools = [data]
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    func createOrder(_ order: Order) async throws {
        let document = manager.db.collection("orders").document(order.id)
        try document.setData(from: order)
        let callable = manager.functions.httpsCallable("queueOrder")
        _ = try await callable.call(["orderId": order.id])
    }

    func cancelOrder(orderId: String) async throws {
        let callable = manager.functions.httpsCallable("cancelOrder")
        _ = try await callable.call(["orderId": orderId])
    }

    func subscribeToOrders(uid: String) -> AsyncThrowingStream<[Order], Error> {
        let query = manager.db.collection("orders").whereField("userId", isEqualTo: uid)
        return AsyncThrowingStream { continuation in
            let listener = query.addSnapshotListener { snapshot, error in
                if let error {
                    continuation.finish(throwing: error)
                } else if let snapshot {
                    do {
                        let orders = try snapshot.documents.map { doc in
                            try doc.data(as: Order.self)
                        }
                        continuation.yield(orders)
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
            }

            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }
}
