import Foundation

@MainActor
final class DasherViewModel: ObservableObject {
    @Published var assignments: [Run] = []
    @Published var errorMessage: String?

    private let matchingService = MatchingService.shared

    func bindAssignments(for uid: String) {
        Task {
            do {
                for try await runs in matchingService.observeAssignments(for: uid) {
                    await MainActor.run {
                        self.assignments = runs
                    }
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
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
}
