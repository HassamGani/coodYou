import Foundation
import FirebaseFirestore

final class MatchingService: ObservableObject {
    static let shared = MatchingService()
    private let manager = FirebaseManager.shared

    private init() {}

    func claimRun(runId: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let callable = manager.functions.httpsCallable("claimRun")
            callable.call(["runId": runId]) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: ())
            }
        }
    }

    func markPickedUp(runId: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let callable = manager.functions.httpsCallable("markPickedUp")
            callable.call(["runId": runId]) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: ())
            }
        }
    }

    func markDelivered(runId: String, pin: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let callable = manager.functions.httpsCallable("markDelivered")
            callable.call(["runId": runId, "pin": pin]) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: ())
            }
        }
    }

    func observeAssignments(for uid: String) -> AsyncThrowingStream<[Run], Error> {
        let query = manager.db.collection("runs").whereField("dasherId", isEqualTo: uid)
        return AsyncThrowingStream { continuation in
            let listener = query.addSnapshotListener { snapshot, error in
                if let error {
                    continuation.finish(throwing: error)
                    return
                }

                guard let snapshot else { return }

                Task {
                    do {
                        let runs: [Run] = try await withThrowingTaskGroup(of: Run.self) { group in
                            for document in snapshot.documents {
                                group.addTask {
                                    var run = try document.data(as: Run.self)
                                    let orders = try await self.fetchOrders(for: document.reference)
                                    run.orders = orders
                                    return run
                                }
                            }

                            var aggregated: [Run] = []
                            for try await run in group {
                                aggregated.append(run)
                            }
                            return aggregated
                        }
                        continuation.yield(runs)
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

    private func fetchOrders(for runRef: DocumentReference) async throws -> [Order] {
        let snapshot = try await runRef.collection("orders").getDocuments()
        return try snapshot.documents.map { try $0.data(as: Order.self) }
    }
}
