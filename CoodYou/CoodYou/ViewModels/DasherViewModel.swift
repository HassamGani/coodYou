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
                    geofenceRadius: data["geofenceRadius"] as? Double ?? 75,
                    address: data["address"] as? String ?? "",
                    dineOnCampusSiteId: data["dineOnCampusSiteId"] as? String,
                    dineOnCampusLocationId: data["dineOnCampusLocationId"] as? String,
                    affiliation: DiningHallAffiliation(rawValue: data["affiliation"] as? String ?? DiningHallAffiliation.columbia.rawValue) ?? .columbia,
                    defaultOpenState: data["defaultOpenState"] as? Bool ?? true
                )
                lookup[hall.id] = hall
            }
            hallLookup = lookup
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private extension RunStatus {
    var sortIndex: Int {
        switch self {
        case .requested: return 0
        case .pooled: return 1
        case .readyToAssign: return 2
        case .claimed: return 3
        case .inProgress: return 4
        case .delivered: return 5
        case .paid: return 6
        case .closed: return 7
        case .expired: return 8
        case .cancelledBuyer: return 9
        case .cancelledDasher: return 10
        case .disputed: return 11
        case .cancelled: return 12
        }
    }

    var displayLabel: String {
        switch self {
        case .requested: return "Requested"
        case .pooled: return "Pooled"
        case .readyToAssign: return "Available"
        case .claimed: return "Claimed"
        case .inProgress: return "In progress"
        case .delivered: return "Delivered"
        case .paid: return "Paid"
        case .closed: return "Closed"
        case .expired: return "Expired"
        case .cancelledBuyer: return "Cancelled by buyer"
        case .cancelledDasher: return "Cancelled by dasher"
        case .disputed: return "Disputed"
        case .cancelled: return "Cancelled"
        }
    }

    var progressValue: Double {
        switch self {
        case .requested: return 0.05
        case .pooled: return 0.08
        case .readyToAssign: return 0.1
        case .claimed: return 0.35
        case .inProgress: return 0.7
        case .delivered: return 0.9
        case .paid, .closed: return 1
        case .expired, .cancelledBuyer, .cancelledDasher, .disputed, .cancelled: return 0
        }
    }
}
