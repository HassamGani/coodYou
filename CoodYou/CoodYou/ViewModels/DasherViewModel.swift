import Foundation

@MainActor
final class DasherViewModel: ObservableObject {
    @Published var assignments: [Run] = []
    @Published var errorMessage: String?
    @Published var hallLookup: [String: DiningHall] = [:]
    @Published var isOnline = true

    private let matchingService = MatchingService.shared
    private let manager = FirebaseManager.shared

    init() {
        Task { await loadHalls() }
    }

    func bindAssignments(for uid: String) {
        Task {
            do {
                for try await runs in matchingService.observeAssignments(for: uid) {
                    let sorted = runs.sorted { lhs, rhs in
                        lhs.status.sortIndex < rhs.status.sortIndex
                    }
                    await MainActor.run {
                        self.assignments = sorted
                    }
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func hall(for run: Run) -> DiningHall? {
        hallLookup[run.hallId]
    }

    func claim(runId: String) async {
        do {
            try await matchingService.claimRun(runId: runId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markPickedUp(runId: String) async {
        do {
            try await matchingService.markPickedUp(runId: runId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markDelivered(runId: String, pin: String) async {
        do {
            try await matchingService.markDelivered(runId: runId, pin: pin)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadHalls() async {
        do {
            let snapshot = try await manager.db.collection("dining_halls").getDocuments()
            var lookup: [String: DiningHall] = [:]
            for document in snapshot.documents {
                let data = document.data()
                let hall = DiningHall(
                    id: document.documentID,
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
                lookup[hall.id] = hall
            }
            hallLookup = lookup
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

extension RunStatus {
    var sortIndex: Int {
        switch self {
        case .readyToAssign: return 0
        case .claimed: return 1
        case .inProgress: return 2
        case .delivered: return 3
        case .paid: return 4
        case .closed: return 5
        case .cancelled: return 6
        }
    }

    var displayLabel: String {
        switch self {
        case .readyToAssign: return "Available"
        case .claimed: return "Claimed"
        case .inProgress: return "In progress"
        case .delivered: return "Delivered"
        case .paid: return "Paid"
        case .closed: return "Closed"
        case .cancelled: return "Cancelled"
        }
    }

    var progressValue: Double {
        switch self {
        case .readyToAssign: return 0.1
        case .claimed: return 0.35
        case .inProgress: return 0.7
        case .delivered: return 0.9
        case .paid, .closed: return 1
        case .cancelled: return 0
        }
    }
}
