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
            try await DiningHallService.shared.ensureHallsLoaded()
            hallLookup = Dictionary(uniqueKeysWithValues: DiningHallService.shared.halls.map { ($0.id, $0) })
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
