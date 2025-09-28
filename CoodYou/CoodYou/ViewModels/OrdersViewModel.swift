import Foundation
import FirebaseFirestore

@MainActor
final class OrdersViewModel: ObservableObject {
    @Published var pastOrders: [Order] = []
    @Published var activeOrder: Order?
    @Published var errorMessage: String?

    private var listener: ListenerRegistration?

    func start() async {
        guard let uid = AppState.shared.currentUser?.id else {
            await MainActor.run { self.pastOrders = []; self.activeOrder = nil }
            return
        }
        listener?.remove()
        let query = FirebaseManager.shared.db.collection("orders")
            .whereField("userId", isEqualTo: uid)
            .order(by: "createdAt", descending: true)

        listener = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error {
                Task { @MainActor in self.errorMessage = error.localizedDescription }
                return
            }
            guard let snapshot else { return }
            do {
                let orders = try snapshot.documents.map { try $0.data(as: Order.self) }
                Task { @MainActor in
                    self.pastOrders = orders.filter { $0.isTerminal }
                    self.activeOrder = orders.filter { !$0.isTerminal }.sorted { $0.createdAt > $1.createdAt }.first
                }
            } catch {
                Task { @MainActor in self.errorMessage = error.localizedDescription }
            }
        }
    }

    deinit {
        listener?.remove()
    }
}
