import Foundation
import FirebaseFirestore
import FirebaseFunctions

enum DeliveryRequestServiceError: LocalizedError {
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The delivery request response was missing required data."
        }
    }
}

enum DeliveryRequestAction: String {
    case accept
    case decline
}

final class DeliveryRequestService: ObservableObject {
    static let shared = DeliveryRequestService()

    private let manager = FirebaseManager.shared
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
    }

    func createDeliveryRequest(for order: Order,
                               lineItems: [OrderLineItem],
                               instructions: String?,
                               buyer: UserProfile) async throws -> DeliveryRequest {
        var payload: [String: Any] = [
            "orderId": order.id,
            "buyerId": buyer.id,
            "hallId": order.hallId,
            "windowType": order.windowType.rawValue,
            "lineItems": lineItems.map { [
                "id": $0.id,
                "name": $0.name,
                "quantity": $0.quantity
            ] },
            "requestedAtMillis": Int(order.createdAt.timeIntervalSince1970 * 1000)
        ]

        if let instructions = instructions?.trimmingCharacters(in: .whitespacesAndNewlines), !instructions.isEmpty {
            payload["instructions"] = instructions
        }

        if let meetPoint = order.meetPoint {
            payload["meetPoint"] = [
                "title": meetPoint.title,
                "description": meetPoint.description,
                "latitude": meetPoint.latitude,
                "longitude": meetPoint.longitude
            ]
        }

        payload["buyerDisplayName"] = "\(buyer.firstName) \(buyer.lastName)"
        payload["buyerPushToken"] = buyer.pushToken ?? ""

        let callable = manager.functions.httpsCallable("createDeliveryRequest")
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<DeliveryRequest, Error>) in
            callable.call(payload) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard
                    let data = result?.data as?[String: Any],
                    let requestData = data["request"] as?[String: Any]
                else {
                    continuation.resume(throwing: DeliveryRequestServiceError.invalidResponse)
                    return
                }

                do {
                    let request = try self.decodeDeliveryRequest(from: requestData)
                    continuation.resume(returning: request)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func observeOpenRequests(for dasherId: String) -> AsyncThrowingStream<[DeliveryRequest], Error> {
        let query = manager.db.collection("deliveryRequests")
            .whereField("candidateDasherIds", arrayContains: dasherId)

        return AsyncThrowingStream { continuation in
            let listener = query.addSnapshotListener { snapshot, error in
                if let error {
                    continuation.finish(throwing: error)
                    return
                }

                guard let snapshot else { return }

                do {
                    let requests: [DeliveryRequest] = try snapshot.documents.compactMap { document in
                        var request = try document.data(as: DeliveryRequest.self)
                        if request.id.isEmpty {
                            request.id = document.documentID
                        }
                        return request.isActionable ? request : nil
                    }
                    continuation.yield(requests)
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }

    func updateDasherAvailability(dasherId: String, isOnline: Bool) async throws {
        try await callFunction(named: "updateDasherAvailability", payload: [
            "dasherId": dasherId,
            "isOnline": isOnline
        ])
    }

    func fetchAvailability(for dasherId: String) async throws -> Bool {
        let document = manager.db.collection("dasherAvailability").document(dasherId)
        if let record = try? await document.getDocument(as: DasherAvailability.self) {
            return record.isOnline
        }
        let snapshot = try await document.getDocument()
        return (snapshot.data()?["isOnline"] as? Bool) ?? false
    }

    func respond(to requestId: String, action: DeliveryRequestAction, dasherId: String) async throws {
        try await callFunction(named: "respondToDeliveryRequest", payload: [
            "requestId": requestId,
            "action": action.rawValue,
            "dasherId": dasherId
        ])
    }

    func markRequestCompleted(_ requestId: String, dasherId: String, runId: String) async throws {
        try await callFunction(named: "completeDeliveryRequest", payload: [
            "requestId": requestId,
            "dasherId": dasherId,
            "runId": runId
        ])
    }
}

private extension DeliveryRequestService {
    func decodeDeliveryRequest(from dictionary: [String: Any]) throws -> DeliveryRequest {
        let data = try JSONSerialization.data(withJSONObject: dictionary, options: [])
        return try decoder.decode(DeliveryRequest.self, from: data)
    }

    func callFunction(named name: String, payload: [String: Any]) async throws {
        let callable = manager.functions.httpsCallable(name)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            callable.call(payload) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: ())
            }
        }
    }
}
