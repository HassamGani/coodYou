import Foundation

@MainActor
final class DasherViewModel: ObservableObject {
    @Published var assignments: [Run] = []
    @Published var errorMessage: String?
    @Published var hallLookup: [String: DiningHall] = [:]
    @Published var pendingRequests: [DeliveryRequest] = []
    @Published var isOnline = false {
        didSet {
            guard oldValue != isOnline,
                  !suppressAvailabilityUpdate,
                  let dasherId = cachedDasherId else { return }
            Task {
                do {
                    try await deliveryService.updateDasherAvailability(dasherId: dasherId, isOnline: isOnline)
                } catch {
                    await MainActor.run {
                        self.errorMessage = error.localizedDescription
                        self.suppressAvailabilityUpdate = true
                        self.isOnline = oldValue
                        self.suppressAvailabilityUpdate = false
                    }
                }
            }
        }
    }

    private let matchingService = MatchingService.shared
    private let manager = FirebaseManager.shared
    private let deliveryService = DeliveryRequestService.shared

    private var assignmentsTask: Task<Void, Never>?
    private var requestsTask: Task<Void, Never>?
    private var availabilityTask: Task<Void, Never>?
    private var cachedDasherId: String?
    private var suppressAvailabilityUpdate = false

    init() {
        Task { await loadHalls() }
    }

    func bindAssignments(for uid: String) {
        cachedDasherId = uid
        assignmentsTask?.cancel()
        assignmentsTask = Task {
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
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }

        bindRequests(for: uid)
        refreshAvailability(for: uid)
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
            try await DiningHallService.shared.ensureHallsLoaded()
            hallLookup = Dictionary(uniqueKeysWithValues: DiningHallService.shared.halls.map { ($0.id, $0) })
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func bindRequests(for uid: String) {
        requestsTask?.cancel()
        requestsTask = Task {
            do {
                for try await requests in deliveryService.observeOpenRequests(for: uid) {
                    let sorted = requests.sorted { lhs, rhs in
                        lhs.requestedAt > rhs.requestedAt
                    }
                    await MainActor.run {
                        self.pendingRequests = sorted
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func refreshAvailability(for uid: String) {
        availabilityTask?.cancel()
        availabilityTask = Task {
            do {
                let isOnline = try await deliveryService.fetchAvailability(for: uid)
                await MainActor.run {
                    self.suppressAvailabilityUpdate = true
                    self.isOnline = isOnline
                    self.suppressAvailabilityUpdate = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.suppressAvailabilityUpdate = true
                    self.isOnline = false
                    self.suppressAvailabilityUpdate = false
                }
            }
        }
    }

    func accept(request: DeliveryRequest) async {
        guard let dasherId = cachedDasherId else { return }
        do {
            try await deliveryService.respond(to: request.id, action: .accept, dasherId: dasherId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func decline(request: DeliveryRequest) async {
        guard let dasherId = cachedDasherId else { return }
        do {
            try await deliveryService.respond(to: request.id, action: .decline, dasherId: dasherId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    deinit {
        assignmentsTask?.cancel()
        requestsTask?.cancel()
        availabilityTask?.cancel()
    }
}
