import Foundation
import FirebaseFirestore

final class PaymentService {
    static let shared = PaymentService()
    private let manager = FirebaseManager.shared
    
    private init() {}
    
    // MARK: - Observe Payment Methods
    func observePaymentMethods(for userId: String) -> AsyncThrowingStream<[PaymentMethod], Error> {
        AsyncThrowingStream { continuation in
            let listener = manager.db.collection("users")
                .document(userId)
                .collection("paymentMethods")
                .order(by: "createdAt", descending: false)
                .addSnapshotListener { snapshot, error in
                    if let error = error {
                        continuation.finish(throwing: error)
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        continuation.yield([])
                        return
                    }
                    
                    do {
                        let methods = try documents.compactMap { doc -> PaymentMethod? in
                            try doc.data(as: PaymentMethod.self)
                        }
                        continuation.yield(methods)
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
            
            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }
    
    // MARK: - Add Payment Method
    func addPaymentMethod(_ method: PaymentMethod, for userId: String) async throws {
        let docRef = manager.db.collection("users")
            .document(userId)
            .collection("paymentMethods")
            .document(method.id)
        
        try await docRef.setData(from: method)
    }
    
    // MARK: - Delete Payment Method
    func deletePaymentMethod(_ methodId: String, for userId: String) async throws {
        let docRef = manager.db.collection("users")
            .document(userId)
            .collection("paymentMethods")
            .document(methodId)
        
        try await docRef.delete()
    }
    
    // MARK: - Set Default Payment Method
    func setDefaultPaymentMethod(_ methodId: String?, for userId: String) async throws {
        let userRef = manager.db.collection("users").document(userId)
        
        if let methodId = methodId {
            try await userRef.updateData(["defaultPaymentMethodId": methodId])
        } else {
            try await userRef.updateData(["defaultPaymentMethodId": FieldValue.delete()])
        }
    }
    
    // MARK: - Get Payment Methods
    func getPaymentMethods(for userId: String) async throws -> [PaymentMethod] {
        let snapshot = try await manager.db.collection("users")
            .document(userId)
            .collection("paymentMethods")
            .order(by: "createdAt", descending: false)
            .getDocuments()
        
        return try snapshot.documents.compactMap { doc in
            try doc.data(as: PaymentMethod.self)
        }
    }
}