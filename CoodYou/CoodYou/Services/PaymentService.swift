import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

@MainActor
final class PaymentService: ObservableObject {
    static let shared = PaymentService()

    private let manager = FirebaseManager.shared

    private init() {}

    func loadPaymentMethods(for uid: String) async throws -> [PaymentMethod] {
        let snapshot = try await manager.db
            .collection("users")
            .document(uid)
            .collection("paymentMethods")
            .order(by: "createdAt", descending: false)
            .getDocuments()
        return try snapshot.documents.map { document in
            try document.data(as: PaymentMethod.self)
        }
    }

    func observePaymentMethods(for uid: String) -> AsyncThrowingStream<[PaymentMethod], Error> {
        let collection = manager.db
            .collection("users")
            .document(uid)
            .collection("paymentMethods")
        return AsyncThrowingStream { continuation in
            let listener = collection.addSnapshotListener { snapshot, error in
                if let error {
                    continuation.finish(throwing: error)
                } else if let snapshot {
                    do {
                        let methods = try snapshot.documents.map { try $0.data(as: PaymentMethod.self) }
                        continuation.yield(methods)
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

    func addPaymentMethod(_ method: PaymentMethod, for uid: String) async throws {
        let document = manager.db
            .collection("users")
            .document(uid)
            .collection("paymentMethods")
            .document(method.id)
        try document.setData(from: method)

        if method.isDefault {
            try await setDefaultPaymentMethod(method.id, for: uid)
        }
    }

    func setDefaultPaymentMethod(_ methodId: String?, for uid: String) async throws {
        let updateValue: Any
        if let methodId {
            updateValue = methodId
        } else {
            updateValue = FieldValue.delete()
        }
        try await manager.db.collection("users").document(uid).updateData([
            "defaultPaymentMethodId": updateValue
        ])
    }

    func deletePaymentMethod(_ methodId: String, for uid: String) async throws {
        let document = manager.db
            .collection("users")
            .document(uid)
            .collection("paymentMethods")
            .document(methodId)
        try await document.delete()
    }
}
